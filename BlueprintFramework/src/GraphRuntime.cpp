#include <Blueprint/GraphRuntime.h>

#include <Blueprint/NodeRegistry.h>

#include <QMetaObject>
#include <QScopedValueRollback>
#include <QSet>
#include <QThread>

#include <algorithm>
#include <mutex>
#include <optional>
#include <utility>

namespace Blueprint {

namespace {

Diagnostic validateDataInput(const QUuid &nodeId, const PortDefinition &port, bool connected)
{
    if (port.valueTypeId.isEmpty())
        return {"runtime.unconfigured_port",
                "The data port has no configured value type.", nodeId, port.key};
    if (!connected && !port.defaultValue.isValid())
        return {"runtime.unconnected_input",
                "The data input has no source or default value.", nodeId, port.key};
    return {};
}

} // namespace

// 异步完成持有此门闩，不持有运行对象；投递与析构互斥，避免销毁期间访问 QObject。
struct GraphRuntime::CompletionGate
{
    std::mutex mutex;
    GraphRuntime *runtime = nullptr;
};

GraphRuntime::GraphRuntime(QObject *parent)
    : QObject(parent)
    , m_completionGate(std::make_shared<CompletionGate>())
{
    m_completionGate->runtime = this;
    qRegisterMetaType<Diagnostic>();
}

GraphRuntime::~GraphRuntime()
{
    {
        std::lock_guard<std::mutex> lock(m_completionGate->mutex);
        m_completionGate->runtime = nullptr;
    }
    stop();
}

Diagnostic GraphRuntime::start(const GraphSnapshot &snapshot,
                               const RuntimeImplementations &implementations)
{
    if (!m_runtimeId.isNull())
        return {"runtime.already_started",
                "Stop the current graph before starting it again."};
    if (snapshot.graphId.isNull())
        return {"runtime.invalid_graph", "The graph ID is empty."};

    QHash<QUuid, int> nodeIndexes;
    for (int i = 0; i < snapshot.nodes.size(); ++i) {
        const SnapshotNode &node = snapshot.nodes.at(i);
        if (node.id.isNull() || nodeIndexes.contains(node.id) || node.typeId.isEmpty())
            return {"runtime.invalid_node",
                    "Node IDs must be nonempty and unique, and types must be specified.",
                    node.id};
        Diagnostic error = NodeRegistry::validatePorts(node.ports, true);
        if (!error.code.isEmpty()) {
            error.nodeId = node.id;
            return error;
        }
        if (implementations.evaluators.contains(node.typeId)
            && implementations.actions.contains(node.typeId))
            return {"runtime.ambiguous_implementation",
                    "A node type must use either computed outputs or action outputs.",
                    node.id};
        const auto executor = implementations.executors.constFind(node.typeId);
        if (executor != implementations.executors.cend()) {
            if (!executor.value())
                return {"runtime.missing_executor", "The registered executor is null.", node.id};
            if (implementations.evaluators.contains(node.typeId) || implementations.actions.contains(node.typeId)
                || implementations.cancellations.contains(node.typeId))
                return {"runtime.ambiguous_implementation",
                        "A node type cannot register both an executor and runtime callbacks.", node.id};
        }
        nodeIndexes.insert(node.id, i);
    }

    QSet<QUuid> connectionIds;
    QHash<QUuid, QHash<QString, QSet<QPair<QUuid, QString>>>> connectedExecutionSources;
    QHash<QUuid, QHash<QString, Endpoint>> dataSources;
    QHash<QUuid, QHash<QString, QVector<Endpoint>>> executionTargets;
    QHash<QUuid, QVector<Endpoint>> dataEdges;
    QHash<QUuid, QVector<Endpoint>> executionEdges;
    for (const ConnectionData &connection : snapshot.connections) {
        if (connection.id.isNull() || connectionIds.contains(connection.id))
            return {"runtime.invalid_connection",
                    "Connection IDs must be nonempty and unique."};
        connectionIds.insert(connection.id);
        if (!nodeIndexes.contains(connection.source.nodeId)
            || !nodeIndexes.contains(connection.target.nodeId))
            return {"runtime.missing_node",
                    "A connection refers to a missing node."};

        const SnapshotNode &sourceNode = snapshot.nodes.at(nodeIndexes.value(connection.source.nodeId));
        const SnapshotNode &targetNode = snapshot.nodes.at(nodeIndexes.value(connection.target.nodeId));
        const PortDefinition *sourcePort = nullptr;
        const PortDefinition *targetPort = nullptr;
        for (const PortDefinition &port : sourceNode.ports) {
            if (port.key == connection.source.portKey)
                sourcePort = &port;
        }
        for (const PortDefinition &port : targetNode.ports) {
            if (port.key == connection.target.portKey)
                targetPort = &port;
        }
        if (!sourcePort || sourcePort->direction != PortDirection::Output)
            return {"runtime.invalid_source",
                    "A connection source must be an output port.",
                    sourceNode.id, connection.source.portKey};
        if (!targetPort || targetPort->direction != PortDirection::Input)
            return {"runtime.invalid_target",
                    "A connection target must be an input port.",
                    targetNode.id, connection.target.portKey};
        if (sourcePort->kind != targetPort->kind
            || (sourcePort->kind == PortKind::Data
                && (sourcePort->valueTypeId.isEmpty()
                    || (sourcePort->valueTypeId != targetPort->valueTypeId
                        && targetPort->valueTypeId != anyValueType))))
            return {"runtime.incompatible_ports",
                    "Connected ports must have the same kind and compatible configured value types.",
                    targetNode.id, targetPort->key};

        if (sourcePort->kind == PortKind::Data) {
            auto &sources = dataSources[targetNode.id];
            if (sources.contains(targetPort->key))
                return {"runtime.input_occupied",
                        "A data input can have only one source.",
                        targetNode.id, targetPort->key};
            sources.insert(targetPort->key, connection.source);
            dataEdges[sourceNode.id].append(connection.target);
        } else {
            auto &sources = connectedExecutionSources[targetNode.id][targetPort->key];
            const auto source = qMakePair(sourceNode.id, sourcePort->key);
            if (sources.contains(source))
                return {"runtime.duplicate_connection",
                        "The execution connection already exists.",
                        targetNode.id, targetPort->key};
            sources.insert(source);
            executionTargets[sourceNode.id][sourcePort->key].append(connection.target);
            executionEdges[sourceNode.id].append(connection.target);
        }
    }

    // 两类连线分别检查。用回边定位实际参与循环的端口，而非环下游的节点。
    struct Visit
    {
        QUuid nodeId;
        int nextEdge = 0;
    };
    for (const auto *edges : {&dataEdges, &executionEdges}) {
        QSet<QUuid> visiting;
        QSet<QUuid> finished;
        QVector<Visit> stack;
        for (const SnapshotNode &node : snapshot.nodes) {
            if (finished.contains(node.id))
                continue;
            stack.append({node.id});
            visiting.insert(node.id);
            while (!stack.isEmpty()) {
                Visit &visit = stack.last();
                const auto targets = edges->constFind(visit.nodeId);
                if (targets == edges->cend() || visit.nextEdge == targets->size()) {
                    visiting.remove(visit.nodeId);
                    finished.insert(visit.nodeId);
                    stack.removeLast();
                    continue;
                }
                const Endpoint &target = targets->at(visit.nextEdge++);
                if (visiting.contains(target.nodeId)) {
                    return {"runtime.cycle",
                            edges == &dataEdges ? "Data dependencies must be acyclic."
                                                : "Execution connections must be acyclic.",
                            target.nodeId, target.portKey};
                }
                if (!finished.contains(target.nodeId)) {
                    stack.append({target.nodeId});
                    visiting.insert(target.nodeId);
                }
            }
        }
    }

    m_snapshot = snapshot;
    m_implementations = implementations;
    m_nodeIndexes = std::move(nodeIndexes);
    m_dataSources = std::move(dataSources);
    m_executionTargets = std::move(executionTargets);
    m_runtimeId = QUuid::createUuid();
    return {};
}

void GraphRuntime::stop()
{
    if (m_runtimeId.isNull())
        return;

    const QUuid executionId = m_executionId;
    const auto cancellations = takeCancellations();
    // 取消可能同步触发宿主完成回调，先清除身份和全部执行状态。
    m_runtimeId = {};
    m_executionId = {};
    m_snapshot = {};
    m_implementations = {};
    m_nodeIndexes.clear();
    m_dataSources.clear();
    m_executionTargets.clear();
    m_executionOutputs.clear();
    m_pendingInputs.clear();
    m_deferredInputs.clear();
    m_readyNodes.clear();
    for (auto it = cancellations.cbegin(); it != cancellations.cend(); ++it)
        it.value()(it.key());
    if (!executionId.isNull())
        emit executionFinished(executionId, {"runtime.cancelled",
                                            "Execution was stopped."});
}

ValueResult GraphRuntime::evaluate(const Endpoint &endpoint)
{
    if (m_runtimeId.isNull())
        return {{}, {"runtime.not_started",
                     "Start the graph before evaluating it."}};
    QHash<QUuid, QVariantMap> values;
    return evaluateValue(endpoint, values);
}

ValueResult GraphRuntime::evaluateValue(const Endpoint &endpoint,
                                        QHash<QUuid, QVariantMap> &values)
{
    const int nodeIndex = m_nodeIndexes.value(endpoint.nodeId, -1);
    if (nodeIndex < 0)
        return {{}, {"runtime.missing_node",
                     "The endpoint refers to a missing node.", endpoint.nodeId,
                     endpoint.portKey}};

    Endpoint output = endpoint;
    const SnapshotNode &node = m_snapshot.nodes.at(nodeIndex);
    const auto port = std::find_if(node.ports.cbegin(), node.ports.cend(), [&](const PortDefinition &port) {
        return port.key == endpoint.portKey;
    });
    if (port == node.ports.cend())
        return {{}, {"runtime.missing_port",
                     "The endpoint refers to a missing port.", node.id, endpoint.portKey}};
    if (port->kind != PortKind::Data)
        return {{}, {"runtime.not_data_port",
                     "Only data ports can be evaluated.", node.id, port->key}};
    if (port->direction == PortDirection::Input) {
        const auto sources = m_dataSources.value(node.id);
        const auto source = sources.constFind(port->key);
        const auto error = validateDataInput(node.id, *port, source != sources.cend());
        if (!error.code.isEmpty())
            return {{}, error};
        if (source == sources.cend())
            return {port->defaultValue, {}};
        output = source.value();
    } else if (port->valueTypeId.isEmpty()) {
        return {{}, {"runtime.unconfigured_port",
                     "The data port has no configured value type.", node.id, port->key}};
    }

    const EvaluationResult result = evaluateNode(output.nodeId, values);
    if (!result.error.code.isEmpty())
        return {{}, result.error};
    return {result.outputs.value(output.portKey), {}};
}

EvaluationResult GraphRuntime::evaluateNode(const QUuid &nodeId,
                                            QHash<QUuid, QVariantMap> &values)
{
    const auto findOutputs = [this, &values](const QUuid &id) -> const QVariantMap * {
        const auto computed = values.constFind(id);
        if (computed != values.cend())
            return &computed.value();
        const auto execution = m_executionOutputs.constFind(id);
        return execution == m_executionOutputs.cend() ? nullptr : &execution.value();
    };
    if (const auto *outputs = findOutputs(nodeId))
        return {*outputs, {}};

    struct EvaluationFrame
    {
        QUuid nodeId;
        int nextPort = 0;
        QVariantMap inputs;
    };
    const QUuid runtimeId = m_runtimeId;
    const QUuid executionId = m_executionId;
    QVector<EvaluationFrame> stack{{nodeId}};
    while (!stack.isEmpty()) {
        EvaluationFrame &frame = stack.last();
        const SnapshotNode &node = m_snapshot.nodes.at(m_nodeIndexes.value(frame.nodeId));
        const auto executor = m_implementations.executors.value(node.typeId);
        if (m_implementations.actions.contains(node.typeId)
            || (executor && executor->trigger == Executor::Trigger::Execution))
            return {{}, {"runtime.output_unavailable",
                         "Action outputs are available only after this execution completes the action.",
                         node.id}};
        const auto implementation = m_implementations.evaluators.constFind(node.typeId);
        if (!executor && (implementation == m_implementations.evaluators.cend() || !implementation.value()))
            return {{}, {"runtime.missing_evaluator",
                         "The node type has no evaluator.", node.id}};

        const auto sources = m_dataSources.value(node.id);
        const int depth = stack.size();
        for (; frame.nextPort < node.ports.size(); ++frame.nextPort) {
            const auto &port = node.ports.at(frame.nextPort);
            if (port.kind != PortKind::Data || port.direction != PortDirection::Input)
                continue;
            const auto source = sources.constFind(port.key);
            const auto error = validateDataInput(node.id, port, source != sources.cend());
            if (!error.code.isEmpty())
                return {{}, error};
            if (source == sources.cend()) {
                frame.inputs.insert(port.key, port.defaultValue);
            } else if (const auto *outputs = findOutputs(source->nodeId)) {
                frame.inputs.insert(port.key, outputs->value(source->portKey));
            } else {
                // 上游求值后回到同一端口，从本次缓存取结果。
                stack.append({source->nodeId});
                break;
            }
        }
        if (stack.size() != depth)
            continue;

        // 宿主回调可以同步停止运行，调用期间保留快照节点和实现的副本。
        const SnapshotNode evaluatedNode = node;
        EvaluationResult result;
        if (executor) {
            const QUuid callId = QUuid::createUuid();
            const ExecutionContext context{runtimeId, executionId, callId, evaluatedNode.id,
                                           evaluatedNode.parameters, frame.inputs, {}};
            auto completed = std::make_shared<std::optional<ActionResult>>();
            executor->start(context, [thread = QThread::currentThread(), weak = std::weak_ptr{completed}](ActionResult value) {
                if (QThread::currentThread() != thread)
                    return;
                if (const auto result = weak.lock(); result && !result->has_value())
                    result->emplace(std::move(value));
            });
            if (!completed->has_value()) {
                // 先让回调失效，取消本身也可能同步回调。
                completed.reset();
                executor->cancel(callId);
                result.error = {"runtime.async_data_executor",
                                "An on-demand executor must complete on the runtime thread before returning."};
            } else {
                auto &value = completed->value();
                result = {std::move(value.outputs), std::move(value.error)};
                if (result.error.code.isEmpty() && (!value.exitPort.isEmpty() || !value.branches.isEmpty()))
                    result.error = {"runtime.invalid_data_exit", "An on-demand executor cannot select an execution exit."};
            }
        } else {
            const auto evaluator = implementation.value();
            result = evaluator(evaluatedNode.parameters, frame.inputs);
        }
        if (m_runtimeId != runtimeId || (!executionId.isNull() && m_executionId != executionId))
            return {{}, {"runtime.stopped",
                         "The runtime stopped during evaluation.", evaluatedNode.id}};
        if (!result.error.code.isEmpty()) {
            if (result.error.nodeId.isNull())
                result.error.nodeId = evaluatedNode.id;
            return result;
        }
        result.error = validateOutputs(evaluatedNode, result.outputs);
        if (!result.error.code.isEmpty())
            return result;
        values.insert(evaluatedNode.id, std::move(result.outputs));
        stack.removeLast();
    }
    return {values.value(nodeId), {}};
}

Diagnostic GraphRuntime::validateOutputs(const SnapshotNode &node, const QVariantMap &outputs) const
{
    QSet<QString> expected;
    for (const PortDefinition &port : node.ports) {
        if (port.kind != PortKind::Data || port.direction != PortDirection::Output)
            continue;
        expected.insert(port.key);
        if (!outputs.contains(port.key))
            return {"runtime.missing_output",
                    "The node did not return a declared data output.", node.id, port.key};
        if (!NodeRegistry::acceptsValue(port.valueTypeId, outputs.value(port.key)))
            return {"runtime.invalid_output",
                    "The output value does not match its declared type.", node.id, port.key};
    }
    for (auto it = outputs.cbegin(); it != outputs.cend(); ++it) {
        if (!expected.contains(it.key()))
            return {"runtime.unknown_output",
                    "The node returned an undeclared data output.", node.id, it.key()};
    }
    return {};
}

ExecutionResult GraphRuntime::execute(const Endpoint &executionOutput, const QVariantMap &entryOutputs)
{
    if (m_runtimeId.isNull())
        return {{}, {"runtime.not_started",
                     "Start the graph before executing it."}};
    if (!m_executionId.isNull())
        return {{}, {"runtime.busy",
                     "This runtime already has an active execution."}};
    if (!m_nodeIndexes.contains(executionOutput.nodeId))
        return {{}, {"runtime.missing_node",
                     "The execution source refers to a missing node.",
                     executionOutput.nodeId, executionOutput.portKey}};
    const SnapshotNode &node = m_snapshot.nodes.at(m_nodeIndexes.value(executionOutput.nodeId));
    bool executionPort = false;
    for (const PortDefinition &port : node.ports) {
        if (port.key == executionOutput.portKey && port.direction == PortDirection::Output
            && port.kind == PortKind::Execution)
            executionPort = true;
    }
    if (!executionPort)
        return {{}, {"runtime.invalid_execution_source",
                     "Execution must start at an execution output port.",
                     node.id, executionOutput.portKey}};

    QHash<QUuid, QVariantMap> initialOutputs;
    if (!entryOutputs.isEmpty()) {
        const auto error = validateOutputs(node, entryOutputs);
        if (!error.code.isEmpty())
            return {{}, error};
        initialOutputs.insert(node.id, entryOutputs);
    }

    const auto targets = m_executionTargets.value(node.id).value(executionOutput.portKey);
    const auto error = validateExecution(targets, initialOutputs);
    if (!error.code.isEmpty())
        return {{}, error};
    for (const Endpoint &input : targets)
        m_pendingInputs.enqueue(input);
    m_executionId = QUuid::createUuid();
    m_executionOutputs = std::move(initialOutputs);
    const QUuid runtimeId = m_runtimeId;
    const QUuid executionId = m_executionId;
    QMetaObject::invokeMethod(this, [this, runtimeId, executionId] {
        if (m_runtimeId == runtimeId && m_executionId == executionId)
            advance();
    }, Qt::QueuedConnection);
    return {executionId, {}};
}

Diagnostic GraphRuntime::validateExecution(const QVector<Endpoint> &inputs,
                                           const QHash<QUuid, QVariantMap> &availableOutputs) const
{
    QSet<QUuid> checkedActions;
    QSet<QUuid> checkedDataNodes;
    QVector<Endpoint> pendingActions;
    for (auto input = inputs.crbegin(); input != inputs.crend(); ++input)
        pendingActions.append(*input);
    while (!pendingActions.isEmpty()) {
        const Endpoint input = pendingActions.takeLast();
        if (checkedActions.contains(input.nodeId))
            continue;
        checkedActions.insert(input.nodeId);
        const SnapshotNode &action = m_snapshot.nodes.at(m_nodeIndexes.value(input.nodeId));
        const auto executor = m_implementations.executors.value(action.typeId);
        const auto implementation = m_implementations.actions.constFind(action.typeId);
        if (executor ? executor->trigger != Executor::Trigger::Execution
                     : implementation == m_implementations.actions.cend() || !implementation.value())
            return {"runtime.missing_action",
                    "The node type has no action implementation.", action.id, input.portKey};

        QVector<QUuid> pending{action.id};
        for (int i = 0; i < pending.size(); ++i) {
            const SnapshotNode &node = m_snapshot.nodes.at(m_nodeIndexes.value(pending.at(i)));
            const auto sources = m_dataSources.value(node.id);
            for (const auto &port : node.ports) {
                if (port.kind != PortKind::Data || port.direction != PortDirection::Input)
                    continue;
                const auto source = sources.constFind(port.key);
                const auto error = validateDataInput(node.id, port, source != sources.cend());
                if (!error.code.isEmpty())
                    return error;
                if (source == sources.cend() || availableOutputs.contains(source->nodeId)
                    || checkedDataNodes.contains(source->nodeId))
                    continue;
                checkedDataNodes.insert(source->nodeId);
                const SnapshotNode &dependency = m_snapshot.nodes.at(m_nodeIndexes.value(source->nodeId));
                // 动作输出是否已产生取决于实际执行路径，留到取值时检查。
                const auto dependencyExecutor = m_implementations.executors.value(dependency.typeId);
                if (m_implementations.actions.contains(dependency.typeId)
                    || (dependencyExecutor && dependencyExecutor->trigger == Executor::Trigger::Execution))
                    continue;
                const auto evaluator = m_implementations.evaluators.constFind(dependency.typeId);
                if (!dependencyExecutor && (evaluator == m_implementations.evaluators.cend() || !evaluator.value()))
                    return {"runtime.missing_evaluator",
                            "The node type has no evaluator.", dependency.id, source->portKey};
                pending.append(dependency.id);
            }
        }

        const PortDefinition *exit = nullptr;
        for (const auto &port : action.ports) {
            if (port.kind != PortKind::Execution || port.direction != PortDirection::Output)
                continue;
            // 多个出口由动作结果选择，未选中的分支不参与本次预检。
            if (exit) {
                exit = nullptr;
                break;
            }
            exit = &port;
        }
        if (exit) {
            const auto targets = m_executionTargets.value(action.id).value(exit->key);
            for (auto target = targets.crbegin(); target != targets.crend(); ++target)
                pendingActions.append(*target);
        }
    }
    return {};
}

void GraphRuntime::advance()
{
    const QUuid runtimeId = m_runtimeId;
    const QUuid executionId = m_executionId;
    if (executionId.isNull() || m_dispatchingExecution == executionId)
        return;

    // 宿主可能在回调中处理事件，同一次执行只由当前分发循环推进。
    QScopedValueRollback<QUuid> dispatching(m_dispatchingExecution, executionId);
    while (!m_pendingInputs.isEmpty() || !m_readyNodes.isEmpty()) {
        // 先处理本轮送达的信号，保留各信号读取直接前驱结果的机会。
        const bool resuming = m_pendingInputs.isEmpty();
        const Endpoint input = resuming ? Endpoint{m_readyNodes.dequeue(), {}} : m_pendingInputs.dequeue();
        const SnapshotNode node = m_snapshot.nodes.at(m_nodeIndexes.value(input.nodeId));
        const auto executor = m_implementations.executors.value(node.typeId);
        const auto action = m_implementations.actions.value(node.typeId);
        if (executor ? executor->trigger != Executor::Trigger::Execution : !action) {
            finish({"runtime.missing_action",
                    "The node type has no action implementation.", node.id, input.portKey});
            return;
        }

        DeferredInput received{input.portKey, {}};
        if (resuming) {
            auto waiting = m_deferredInputs.find(node.id);
            if (waiting->isEmpty()) {
                m_deferredInputs.erase(waiting);
                continue;
            }
            received = waiting->dequeue();
            if (waiting->isEmpty())
                m_deferredInputs.erase(waiting);
        } else {
            const bool defer = m_activeCalls.contains(node.id) || m_deferredInputs.contains(node.id);
            QHash<QUuid, QVariantMap> values;
            for (const PortDefinition &port : node.ports) {
                if (port.kind != PortKind::Data || port.direction != PortDirection::Input)
                    continue;
                ValueResult value = evaluateValue({node.id, port.key}, values);
                if (m_runtimeId != runtimeId || m_executionId != executionId)
                    return;
                if (!value.error.code.isEmpty()) {
                    finish(value.error);
                    return;
                }
                received.values.insert(port.key, value.value);
            }
            if (defer) {
                // 保存信号到达时的数据，等待期间上游可能再次产出结果。
                // 输入求值时宿主可能处理完成回调，此时应将信号加入就绪队列。
                if (!m_activeCalls.contains(node.id) && !m_deferredInputs.contains(node.id))
                    m_readyNodes.enqueue(node.id);
                m_deferredInputs[node.id].enqueue(std::move(received));
                continue;
            }
        }

        m_executionOutputs.remove(node.id);
        const QUuid callId = QUuid::createUuid();
        m_activeCalls.insert(node.id, callId);
        ExecutionContext context{runtimeId, executionId, callId, node.id, node.parameters,
                                 std::move(received.values), std::move(received.portKey)};
        const auto gate = m_completionGate;
        auto done = [gate, runtimeId, executionId, nodeId = node.id, callId](ActionResult result) {
            std::lock_guard<std::mutex> lock(gate->mutex);
            GraphRuntime *runtime = gate->runtime;
            if (!runtime)
                return;
            QMetaObject::invokeMethod(runtime,
                                     [runtime, runtimeId, executionId, nodeId, callId, result = std::move(result)]() mutable {
                runtime->complete(runtimeId, executionId, nodeId, callId, std::move(result));
            }, Qt::QueuedConnection);
        };
        if (executor)
            executor->start(context, std::move(done));
        else
            action(context, std::move(done));
        if (m_runtimeId != runtimeId || m_executionId != executionId)
            return;
    }
    if (m_activeCalls.isEmpty())
        finish({});
}

void GraphRuntime::complete(const QUuid &runtimeId, const QUuid &executionId, const QUuid &nodeId,
                            const QUuid &callId, ActionResult result)
{
    if (m_runtimeId != runtimeId || m_executionId != executionId)
        return;
    const auto call = m_activeCalls.find(nodeId);
    if (call == m_activeCalls.end() || call.value() != callId)
        return;

    const SnapshotNode node = m_snapshot.nodes.at(m_nodeIndexes.value(nodeId));
    m_activeCalls.erase(call);
    if (!result.error.code.isEmpty()) {
        if (result.error.nodeId.isNull())
            result.error.nodeId = node.id;
        finish(result.error);
        return;
    }
    Diagnostic error = validateOutputs(node, result.outputs);
    if (!error.code.isEmpty()) {
        finish(error);
        return;
    }

    const bool hasBranches = !result.branches.isEmpty();
    if (hasBranches && !result.exitPort.isEmpty()) {
        finish({"runtime.ambiguous_execution_exit",
                "The action cannot select both a single execution output and multiple branches.",
                node.id, result.exitPort});
        return;
    }

    QStringList exits = std::move(result.branches);
    if (!result.exitPort.isEmpty())
        exits.append(result.exitPort);
    QVector<Endpoint> nextInputs;
    bool needsPreflight = hasBranches;
    if (!exits.isEmpty()) {
        QSet<QString> declared;
        for (const PortDefinition &port : node.ports) {
            if (port.direction == PortDirection::Output && port.kind == PortKind::Execution)
                declared.insert(port.key);
        }
        needsPreflight = needsPreflight || declared.size() > 1;
        const auto targets = m_executionTargets.value(node.id);
        QSet<QString> selected;
        for (const QString &exit : exits) {
            if (!declared.contains(exit)) {
                finish({"runtime.invalid_execution_exit",
                        "The action returned an undeclared execution output.", node.id, exit});
                return;
            }
            if (selected.contains(exit)) {
                finish({"runtime.duplicate_execution_exit",
                        "The action selected the same execution output more than once.", node.id, exit});
                return;
            }
            selected.insert(exit);
            const auto target = targets.constFind(exit);
            if (target != targets.cend())
                nextInputs += target.value();
        }
    }
    m_executionOutputs.insert(node.id, std::move(result.outputs));
    if (needsPreflight) {
        const auto branchError = validateExecution(nextInputs, m_executionOutputs);
        if (!branchError.code.isEmpty()) {
            finish(branchError);
            return;
        }
    }
    for (const Endpoint &input : nextInputs)
        m_pendingInputs.enqueue(input);
    // 下一次调用先等本次的直接后继取值，包括宿主重入时已排队的信号。
    if (m_deferredInputs.contains(nodeId)
        || (m_dispatchingExecution == executionId && !nextInputs.isEmpty())) {
        if (!m_deferredInputs.contains(nodeId))
            m_deferredInputs.insert(nodeId, {});
        m_readyNodes.enqueue(nodeId);
    }
    advance();
}

QHash<QUuid, RuntimeImplementations::Cancel> GraphRuntime::takeCancellations()
{
    QHash<QUuid, RuntimeImplementations::Cancel> cancellations;
    for (auto it = m_activeCalls.cbegin(); it != m_activeCalls.cend(); ++it) {
        const SnapshotNode &node = m_snapshot.nodes.at(m_nodeIndexes.value(it.key()));
        if (const auto executor = m_implementations.executors.value(node.typeId)) {
            cancellations.insert(it.value(), [executor](const QUuid &callId) { executor->cancel(callId); });
        } else if (const auto cancel = m_implementations.cancellations.value(node.typeId)) {
            cancellations.insert(it.value(), cancel);
        }
    }
    m_activeCalls.clear();
    return cancellations;
}

void GraphRuntime::finish(const Diagnostic &error)
{
    const QUuid executionId = m_executionId;
    const auto cancellations = takeCancellations();
    m_executionId = {};
    m_pendingInputs.clear();
    m_deferredInputs.clear();
    m_readyNodes.clear();
    for (auto it = cancellations.cbegin(); it != cancellations.cend(); ++it)
        it.value()(it.key());
    emit executionFinished(executionId, error);
}

} // namespace Blueprint
