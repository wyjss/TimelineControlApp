#include <Blueprint/GraphRuntime.h>

#include <Blueprint/NodeRegistry.h>

#include <QMetaObject>
#include <QSet>

#include <mutex>
#include <utility>

namespace Blueprint {

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
        return {QStringLiteral("runtime.already_started"),
                QStringLiteral("Stop the current graph before starting it again.")};
    if (snapshot.graphId.isNull())
        return {QStringLiteral("runtime.invalid_graph"), QStringLiteral("The graph ID is empty.")};

    QHash<QUuid, int> nodeIndexes;
    for (int i = 0; i < snapshot.nodes.size(); ++i) {
        const SnapshotNode &node = snapshot.nodes.at(i);
        if (node.id.isNull() || nodeIndexes.contains(node.id) || node.typeId.isEmpty())
            return {QStringLiteral("runtime.invalid_node"),
                    QStringLiteral("Node IDs must be nonempty and unique, and types must be specified."),
                    node.id};
        Diagnostic error = NodeRegistry::validatePorts(node.ports, true);
        if (!error.code.isEmpty()) {
            error.nodeId = node.id;
            return error;
        }
        if (implementations.evaluators.contains(node.typeId)
            && implementations.actions.contains(node.typeId))
            return {QStringLiteral("runtime.ambiguous_implementation"),
                    QStringLiteral("A node type must use either computed outputs or action outputs."),
                    node.id};
        nodeIndexes.insert(node.id, i);
    }

    QSet<QUuid> connectionIds;
    QHash<QUuid, QSet<QString>> connectedInputs;
    QHash<QUuid, QHash<QString, Endpoint>> dataSources;
    QHash<QUuid, QHash<QString, Endpoint>> executionTargets;
    QHash<QUuid, QVector<QUuid>> dataEdges;
    QHash<QUuid, QVector<QUuid>> executionEdges;
    for (const ConnectionData &connection : snapshot.connections) {
        if (connection.id.isNull() || connectionIds.contains(connection.id))
            return {QStringLiteral("runtime.invalid_connection"),
                    QStringLiteral("Connection IDs must be nonempty and unique.")};
        connectionIds.insert(connection.id);
        if (!nodeIndexes.contains(connection.source.nodeId)
            || !nodeIndexes.contains(connection.target.nodeId))
            return {QStringLiteral("runtime.missing_node"),
                    QStringLiteral("A connection refers to a missing node.")};

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
            return {QStringLiteral("runtime.invalid_source"),
                    QStringLiteral("A connection source must be an output port."),
                    sourceNode.id, connection.source.portKey};
        if (!targetPort || targetPort->direction != PortDirection::Input)
            return {QStringLiteral("runtime.invalid_target"),
                    QStringLiteral("A connection target must be an input port."),
                    targetNode.id, connection.target.portKey};
        if (sourcePort->kind != targetPort->kind
            || (sourcePort->kind == PortKind::Data
                && (sourcePort->valueTypeId.isEmpty()
                    || (sourcePort->valueTypeId != targetPort->valueTypeId
                        && targetPort->valueTypeId != anyValueType))))
            return {QStringLiteral("runtime.incompatible_ports"),
                    QStringLiteral("Connected ports must have the same kind and compatible configured value types."),
                    targetNode.id, targetPort->key};

        if (connectedInputs[targetNode.id].contains(targetPort->key))
            return {QStringLiteral("runtime.input_occupied"),
                    QStringLiteral("An input can have only one source."),
                    targetNode.id, targetPort->key};
        connectedInputs[targetNode.id].insert(targetPort->key);
        if (sourcePort->kind == PortKind::Data) {
            dataSources[targetNode.id].insert(targetPort->key, connection.source);
            dataEdges[sourceNode.id].append(targetNode.id);
        } else {
            if (executionTargets[sourceNode.id].contains(sourcePort->key))
                return {QStringLiteral("runtime.output_occupied"),
                        QStringLiteral("An execution output can have only one target."),
                        sourceNode.id, sourcePort->key};
            executionTargets[sourceNode.id].insert(sourcePort->key, connection.target);
            executionEdges[sourceNode.id].append(targetNode.id);
        }
    }

    // 数据依赖和执行流各自检查，允许两类连线之间存在方向相反的合法关联。
    for (const auto &edges : {dataEdges, executionEdges}) {
        QHash<QUuid, int> incoming;
        for (const SnapshotNode &node : snapshot.nodes)
            incoming.insert(node.id, 0);
        for (auto it = edges.cbegin(); it != edges.cend(); ++it) {
            for (const QUuid &target : it.value())
                ++incoming[target];
        }
        QVector<QUuid> ready;
        for (const SnapshotNode &node : snapshot.nodes) {
            if (incoming.value(node.id) == 0)
                ready.append(node.id);
        }
        for (int i = 0; i < ready.size(); ++i) {
            for (const QUuid &target : edges.value(ready.at(i))) {
                if (--incoming[target] == 0)
                    ready.append(target);
            }
        }
        if (ready.size() != snapshot.nodes.size())
            return {QStringLiteral("runtime.cycle"),
                    QStringLiteral("Data dependencies and execution connections must each be acyclic.")};
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
    const QUuid callId = m_callId;
    RuntimeImplementations::Cancel cancel;
    if (!m_activeNodeId.isNull()) {
        const SnapshotNode &node = m_snapshot.nodes.at(m_nodeIndexes.value(m_activeNodeId));
        cancel = m_implementations.cancellations.value(node.typeId);
    }

    // 取消可能同步触发宿主完成回调，先清除身份和全部执行状态。
    m_runtimeId = {};
    m_executionId = {};
    m_callId = {};
    m_activeNodeId = {};
    m_snapshot = {};
    m_implementations = {};
    m_nodeIndexes.clear();
    m_dataSources.clear();
    m_executionTargets.clear();
    m_actionOutputs.clear();
    m_pendingInput.reset();
    if (cancel && !callId.isNull())
        cancel(callId);
    if (!executionId.isNull())
        emit executionFinished(executionId, {QStringLiteral("runtime.cancelled"),
                                            QStringLiteral("Execution was stopped.")});
}

ValueResult GraphRuntime::evaluate(const Endpoint &endpoint)
{
    if (m_runtimeId.isNull())
        return {{}, {QStringLiteral("runtime.not_started"),
                     QStringLiteral("Start the graph before evaluating it.")}};
    QHash<QUuid, QVariantMap> values;
    return evaluateValue(endpoint, values);
}

ValueResult GraphRuntime::evaluateValue(const Endpoint &endpoint,
                                        QHash<QUuid, QVariantMap> &values)
{
    if (!m_nodeIndexes.contains(endpoint.nodeId))
        return {{}, {QStringLiteral("runtime.missing_node"),
                     QStringLiteral("The endpoint refers to a missing node."), endpoint.nodeId,
                     endpoint.portKey}};
    const SnapshotNode node = m_snapshot.nodes.at(m_nodeIndexes.value(endpoint.nodeId));
    for (const PortDefinition &port : node.ports) {
        if (port.key != endpoint.portKey)
            continue;
        if (port.kind != PortKind::Data)
            return {{}, {QStringLiteral("runtime.not_data_port"),
                         QStringLiteral("Only data ports can be evaluated."), node.id, port.key}};
        if (port.valueTypeId.isEmpty())
            return {{}, {QStringLiteral("runtime.unconfigured_port"),
                         QStringLiteral("The data port has no configured value type."), node.id, port.key}};
        if (port.direction == PortDirection::Input) {
            const auto sources = m_dataSources.value(node.id);
            const auto source = sources.constFind(port.key);
            if (source != sources.cend())
                return evaluateValue(source.value(), values);
            if (port.defaultValue.isValid())
                return {port.defaultValue, {}};
            return {{}, {QStringLiteral("runtime.unconnected_input"),
                         QStringLiteral("The data input has no source or default value."), node.id, port.key}};
        }
        EvaluationResult result = evaluateNode(node.id, values);
        if (!result.error.code.isEmpty())
            return {{}, result.error};
        return {result.outputs.value(port.key), {}};
    }
    return {{}, {QStringLiteral("runtime.missing_port"),
                 QStringLiteral("The endpoint refers to a missing port."), node.id, endpoint.portKey}};
}

EvaluationResult GraphRuntime::evaluateNode(const QUuid &nodeId,
                                            QHash<QUuid, QVariantMap> &values)
{
    if (values.contains(nodeId))
        return {values.value(nodeId), {}};
    if (m_actionOutputs.contains(nodeId))
        return {m_actionOutputs.value(nodeId), {}};

    const QUuid runtimeId = m_runtimeId;
    const SnapshotNode node = m_snapshot.nodes.at(m_nodeIndexes.value(nodeId));
    if (m_implementations.actions.contains(node.typeId))
        return {{}, {QStringLiteral("runtime.output_unavailable"),
                     QStringLiteral("Action outputs are available only after this execution completes the action."),
                     node.id}};
    const auto evaluator = m_implementations.evaluators.value(node.typeId);
    if (!evaluator)
        return {{}, {QStringLiteral("runtime.missing_evaluator"),
                     QStringLiteral("The node type has no evaluator."), node.id}};

    QVariantMap inputs;
    for (const PortDefinition &port : node.ports) {
        if (port.kind != PortKind::Data || port.direction != PortDirection::Input)
            continue;
        ValueResult input = evaluateValue({node.id, port.key}, values);
        if (!input.error.code.isEmpty())
            return {{}, input.error};
        inputs.insert(port.key, input.value);
    }
    EvaluationResult result = evaluator(node.parameters, inputs);
    if (m_runtimeId != runtimeId)
        return {{}, {QStringLiteral("runtime.stopped"),
                     QStringLiteral("The runtime stopped during evaluation."), node.id}};
    if (!result.error.code.isEmpty()) {
        if (result.error.nodeId.isNull())
            result.error.nodeId = node.id;
        return result;
    }
    result.error = validateOutputs(node, result.outputs);
    if (result.error.code.isEmpty())
        values.insert(node.id, result.outputs);
    return result;
}

Diagnostic GraphRuntime::validateOutputs(const SnapshotNode &node, const QVariantMap &outputs) const
{
    QSet<QString> expected;
    for (const PortDefinition &port : node.ports) {
        if (port.kind != PortKind::Data || port.direction != PortDirection::Output)
            continue;
        expected.insert(port.key);
        if (!outputs.contains(port.key))
            return {QStringLiteral("runtime.missing_output"),
                    QStringLiteral("The node did not return a declared data output."), node.id, port.key};
        if (!NodeRegistry::acceptsValue(port.valueTypeId, outputs.value(port.key)))
            return {QStringLiteral("runtime.invalid_output"),
                    QStringLiteral("The output value does not match its declared type."), node.id, port.key};
    }
    for (auto it = outputs.cbegin(); it != outputs.cend(); ++it) {
        if (!expected.contains(it.key()))
            return {QStringLiteral("runtime.unknown_output"),
                    QStringLiteral("The node returned an undeclared data output."), node.id, it.key()};
    }
    return {};
}

ExecutionResult GraphRuntime::execute(const Endpoint &executionOutput)
{
    if (m_runtimeId.isNull())
        return {{}, {QStringLiteral("runtime.not_started"),
                     QStringLiteral("Start the graph before executing it.")}};
    if (!m_executionId.isNull())
        return {{}, {QStringLiteral("runtime.busy"),
                     QStringLiteral("This runtime already has an active execution.")}};
    if (!m_nodeIndexes.contains(executionOutput.nodeId))
        return {{}, {QStringLiteral("runtime.missing_node"),
                     QStringLiteral("The execution source refers to a missing node."),
                     executionOutput.nodeId, executionOutput.portKey}};
    const SnapshotNode &node = m_snapshot.nodes.at(m_nodeIndexes.value(executionOutput.nodeId));
    bool executionPort = false;
    for (const PortDefinition &port : node.ports) {
        if (port.key == executionOutput.portKey && port.direction == PortDirection::Output
            && port.kind == PortKind::Execution)
            executionPort = true;
    }
    if (!executionPort)
        return {{}, {QStringLiteral("runtime.invalid_execution_source"),
                     QStringLiteral("Execution must start at an execution output port."),
                     node.id, executionOutput.portKey}};

    m_executionId = QUuid::createUuid();
    m_actionOutputs.clear();
    const auto targets = m_executionTargets.value(node.id);
    const auto target = targets.constFind(executionOutput.portKey);
    if (target != targets.cend())
        m_pendingInput = target.value();
    const QUuid runtimeId = m_runtimeId;
    const QUuid executionId = m_executionId;
    QMetaObject::invokeMethod(this, [this, runtimeId, executionId] {
        if (m_runtimeId == runtimeId && m_executionId == executionId)
            advance();
    }, Qt::QueuedConnection);
    return {executionId, {}};
}

void GraphRuntime::advance()
{
    if (!m_pendingInput) {
        finish({});
        return;
    }

    const QUuid runtimeId = m_runtimeId;
    const QUuid executionId = m_executionId;
    const Endpoint input = *m_pendingInput;
    m_pendingInput.reset();
    const SnapshotNode node = m_snapshot.nodes.at(m_nodeIndexes.value(input.nodeId));
    const auto action = m_implementations.actions.value(node.typeId);
    if (!action) {
        finish({QStringLiteral("runtime.missing_action"),
                QStringLiteral("The node type has no action implementation."), node.id, input.portKey});
        return;
    }

    QHash<QUuid, QVariantMap> values;
    QVariantMap inputs;
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
        inputs.insert(port.key, value.value);
    }

    m_actionOutputs.remove(node.id);
    m_activeNodeId = node.id;
    m_callId = QUuid::createUuid();
    const QUuid callId = m_callId;
    ExecutionContext context{runtimeId, executionId, callId, node.id, node.parameters, inputs, input.portKey};
    const auto gate = m_completionGate;
    action(context, [gate, runtimeId, executionId, callId](ActionResult result) {
        std::lock_guard<std::mutex> lock(gate->mutex);
        GraphRuntime *runtime = gate->runtime;
        if (!runtime)
            return;
        QMetaObject::invokeMethod(runtime,
                                 [runtime, runtimeId, executionId, callId, result = std::move(result)]() mutable {
            runtime->complete(runtimeId, executionId, callId, std::move(result));
        }, Qt::QueuedConnection);
    });
}

void GraphRuntime::complete(const QUuid &runtimeId, const QUuid &executionId, const QUuid &callId,
                            ActionResult result)
{
    if (m_runtimeId != runtimeId || m_executionId != executionId || m_callId != callId)
        return;

    const SnapshotNode node = m_snapshot.nodes.at(m_nodeIndexes.value(m_activeNodeId));
    m_callId = {};
    m_activeNodeId = {};
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

    if (!result.exitPort.isEmpty()) {
        bool executionPort = false;
        for (const PortDefinition &port : node.ports) {
            if (port.key == result.exitPort && port.direction == PortDirection::Output
                && port.kind == PortKind::Execution)
                executionPort = true;
        }
        if (!executionPort) {
            finish({QStringLiteral("runtime.invalid_execution_exit"),
                    QStringLiteral("The action returned an undeclared execution output."),
                    node.id, result.exitPort});
            return;
        }
        const auto targets = m_executionTargets.value(node.id);
        const auto target = targets.constFind(result.exitPort);
        if (target != targets.cend())
            m_pendingInput = target.value();
    }
    m_actionOutputs.insert(node.id, result.outputs);
    advance();
}

void GraphRuntime::finish(const Diagnostic &error)
{
    const QUuid executionId = m_executionId;
    m_executionId = {};
    m_callId = {};
    m_activeNodeId = {};
    m_pendingInput.reset();
    emit executionFinished(executionId, error);
}

} // namespace Blueprint
