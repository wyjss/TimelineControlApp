#include <Blueprint/BasicNodes.h>
#include <Blueprint/GraphDocument.h>
#include <Blueprint/GraphRuntime.h>
#include <Blueprint/ObjectNodes.h>
#include <Blueprint/WaitNodes.h>

#include <QEvent>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTimer>
#include <QtTest>

#include <utility>

using namespace Blueprint;

namespace {

const QString inputKey = QStringLiteral("input");
const QString valueKey = QStringLiteral("value");
const QString enterKey = QStringLiteral("enter");
const QString nextKey = QStringLiteral("next");
const QString alternateKey = QStringLiteral("alternate");
const QString numberType = QStringLiteral("number");
const QString triggerType = QStringLiteral("trigger");
const QString actionType = QStringLiteral("action");
const QString missingType = QStringLiteral("missing");
const QString evaluatorType = QStringLiteral("evaluate");
const PortDefinition numberInput{inputKey, PortDirection::Input, numberType};
const PortDefinition numberOutput{valueKey, PortDirection::Output, numberType};
const PortDefinition executionInput{enterKey, PortDirection::Input, {}, {}, PortKind::Execution};
const PortDefinition executionOutput{nextKey, PortDirection::Output, {}, {}, PortKind::Execution};

} // namespace

class BlueprintRuntimeTest : public QObject
{
    Q_OBJECT

private slots:
    void loadsAndRunsBasicNodes();
    void rejectsBasicNodeConflicts();
    void rejectsDeferredDataExecutor();
    void cancelsWaitExecutorAndRestarts();
    void runsObjectNodesWithHostAdapter();
    void deepChain();
    void sharesUpstreamWithinOneEvaluation();
    void stopsDuringEvaluation();
    void identifiesCycle_data();
    void identifiesCycle();
    void rejectsIncompleteExecution_data();
    void rejectsIncompleteExecution();
    void validatesChosenBranch_data();
    void validatesChosenBranch();
    void dispatchesBranches_data();
    void dispatchesBranches();
    void validatesBeforeDispatchingBranches();
    void queuesMultipleExecutionArrivals_data();
    void queuesMultipleExecutionArrivals();
    void preservesOutputWhenCompletionReentersDispatch();
    void snapshotsEntryOutputs();
};

void BlueprintRuntimeTest::loadsAndRunsBasicNodes()
{
    NodeRegistry registry;
    RuntimeImplementations implementations;
    QCOMPARE(registerBasicNodes(registry, implementations).code, QString());
    for (const auto &definition : registry.definitions())
        QVERIFY(implementations.executors.value(definition.typeId));
    const auto constantType = QStringLiteral("demo.constant");
    const auto *constant = registry.find(constantType);
    QVERIFY(constant);
    QCOMPARE(constant->properties.size(), 1);
    QCOMPARE(constant->properties.first().value.key, valueKey);
    QVERIFY(!constant->properties.first().writable);
    QVERIFY(registry.add({triggerType, triggerType, {executionOutput}}).code.isEmpty());
    QVERIFY(registry.add({actionType, actionType, {executionInput}}).code.isEmpty());
    const QUuid first = QUuid::createUuid();
    const QUuid second = QUuid::createUuid();
    const QUuid add = QUuid::createUuid();
    const QUuid compare = QUuid::createUuid();
    const QUuid branch = QUuid::createUuid();
    const QUuid entry = QUuid::createUuid();
    const QUuid sink = QUuid::createUuid();
    const auto portA = QStringLiteral("A");
    const auto portB = QStringLiteral("B");
    // 使用示例图原有的类型、参数和端口键，覆盖保存后的重新加载。
    GraphDocument document(registry);
    QCOMPARE(document.replaceData({document.data().id,
        {{first, constantType, {}, {{valueKey, 12.0}}},
         {second, constantType, {}, {{valueKey, 30.0}}},
         {add, QStringLiteral("demo.add"), {}, {}},
         {compare, QStringLiteral("demo.compare"), {}, {{QStringLiteral("operator"), QStringLiteral("gt")}}},
         {branch, QStringLiteral("demo.branch"), {}, {}},
         {entry, triggerType, {}, {}},
         {sink, actionType, {}, {}}},
        {{QUuid::createUuid(), {first, valueKey}, {add, portA}},
         {QUuid::createUuid(), {second, valueKey}, {add, portB}},
         {QUuid::createUuid(), {add, valueKey}, {compare, portA}},
         {QUuid::createUuid(), {second, valueKey}, {compare, portB}},
         {QUuid::createUuid(), {compare, valueKey}, {branch, QStringLiteral("condition")}},
         {QUuid::createUuid(), {entry, nextKey}, {branch, QStringLiteral("execIn")}},
         {QUuid::createUuid(), {branch, QStringLiteral("true")}, {sink, enterKey}}}}).code, QString());
    QTemporaryDir temporary;
    QVERIFY(temporary.isValid());
    const auto path = temporary.filePath(QStringLiteral("basic.json"));
    QCOMPARE(document.saveFile(path).code, QString());
    GraphDocument loaded(registry);
    QCOMPARE(loaded.loadFile(path).code, QString());

    int calls = 0;
    implementations.actions.insert(actionType, [&](const ExecutionContext &, RuntimeImplementations::Completion complete) {
        ++calls;
        complete({});
    });
    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    QCOMPARE(runtime.start(loaded.snapshot(), implementations).code, QString());
    const auto sum = runtime.evaluate({add, valueKey});
    QCOMPARE(sum.error.code, QString());
    QCOMPARE(sum.value.toDouble(), 42.0);
    const auto comparison = runtime.evaluate({compare, valueKey});
    QCOMPARE(comparison.error.code, QString());
    QCOMPARE(comparison.value, QVariant(true));
    QCOMPARE(runtime.execute({entry, nextKey}).error.code, QString());
    QTRY_COMPARE(finished.count(), 1);
    QCOMPARE(finished.first().at(1).value<Diagnostic>().code, QString());
    QCOMPARE(calls, 1);
}

void BlueprintRuntimeTest::rejectsBasicNodeConflicts()
{
    const auto branchType = QStringLiteral("demo.branch");
    NodeRegistry occupiedRegistry;
    RuntimeImplementations implementations;
    QVERIFY(occupiedRegistry.add({branchType, branchType}).code.isEmpty());
    QVERIFY(!registerBasicNodes(occupiedRegistry, implementations).code.isEmpty());
    QCOMPARE(occupiedRegistry.definitions().size(), 1);
    QVERIFY(implementations.evaluators.isEmpty());
    QVERIFY(implementations.actions.isEmpty());
    QVERIFY(implementations.executors.isEmpty());

    NodeRegistry emptyRegistry;
    implementations.evaluators.insert(branchType, [](const QVariantMap &, const QVariantMap &) {
        return EvaluationResult{};
    });
    QVERIFY(!registerBasicNodes(emptyRegistry, implementations).code.isEmpty());
    QVERIFY(emptyRegistry.definitions().isEmpty());
    QCOMPARE(implementations.evaluators.size(), 1);
    QVERIFY(implementations.evaluators.contains(branchType));
    QVERIFY(implementations.actions.isEmpty());
}

void BlueprintRuntimeTest::rejectsDeferredDataExecutor()
{
    class DeferredExecutor final : public Executor
    {
    public:
        DeferredExecutor() : Executor(Trigger::OnDemand) {}

        void start(const ExecutionContext &context, Completion done) override
        {
            started = context.callId;
            complete = std::move(done);
        }

        void cancel(const QUuid &callId) override
        {
            cancelled = callId;
        }

        QUuid started;
        QUuid cancelled;
        Completion complete;
    };

    const auto executor = std::make_shared<DeferredExecutor>();
    const auto node = QUuid::createUuid();
    const GraphSnapshot graph{QUuid::createUuid(), 0, {{node, evaluatorType, {}, {numberOutput}}}};
    RuntimeImplementations implementations;
    implementations.executors.insert(evaluatorType, executor);
    implementations.evaluators.insert(evaluatorType, [](const QVariantMap &, const QVariantMap &) {
        return EvaluationResult{};
    });
    GraphRuntime runtime;
    QCOMPARE(runtime.start(graph, implementations).code, "runtime.ambiguous_implementation");
    implementations.evaluators.clear();
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto result = runtime.evaluate({node, valueKey});
    QCOMPARE(result.error.code, "runtime.async_data_executor");
    QCOMPARE(result.error.nodeId, node);
    QVERIFY(!executor->started.isNull());
    QCOMPARE(executor->cancelled, executor->started);
    executor->complete({{}, {{valueKey, 1}}, {}});
    QCOMPARE(runtime.evaluate({node, valueKey}).error.code, "runtime.async_data_executor");
}

void BlueprintRuntimeTest::cancelsWaitExecutorAndRestarts()
{
    const QString waitType = "demo.wait";
    const QString duration = "durationMs";
    NodeRegistry registry;
    QCOMPARE(registerWaitNodes(registry).code, QString());
    QCOMPARE(registry.add({triggerType, triggerType, {executionOutput}}).code, QString());
    QCOMPARE(registry.add({actionType, actionType, {executionInput}}).code, QString());
    GraphDocument graph(registry);
    const auto entry = graph.addNode(triggerType, {});
    const auto wait = graph.addNode(waitType, {}, {{duration, 10000}});
    const auto sink = graph.addNode(actionType, {});
    QCOMPARE(entry.error.code, QString());
    QCOMPARE(wait.error.code, QString());
    QCOMPARE(sink.error.code, QString());
    QCOMPARE(graph.connectPorts({entry.id, nextKey}, {wait.id, "execIn"}).error.code, QString());
    QCOMPARE(graph.connectPorts({wait.id, "execOut"}, {sink.id, enterKey}).error.code, QString());

    QObject timerOwner;
    int calls = 0;
    RuntimeImplementations implementations;
    implementations.actions.insert(actionType, [&](const ExecutionContext &, RuntimeImplementations::Completion done) {
        ++calls;
        done({});
    });

    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    addWaitImplementations(implementations, timerOwner);
    QCOMPARE(runtime.start(graph.snapshot(), implementations).code, QString());
    implementations.executors.clear();
    QCOMPARE(runtime.execute({entry.id, nextKey}).error.code, QString());
    QCoreApplication::sendPostedEvents(&runtime, QEvent::MetaCall);
    const auto *timer = timerOwner.findChild<QTimer *>();
    QVERIFY(timer && timer->isActive());
    QCOMPARE(calls, 0);
    runtime.stop();
    QCOMPARE(finished.count(), 1);
    QCOMPARE(finished.first().at(1).value<Diagnostic>().code, "runtime.cancelled");
    QVERIFY(!timer->isActive());

    QCOMPARE(graph.setParameter(wait.id, duration, 0).error.code, QString());
    addWaitImplementations(implementations, timerOwner);
    QCOMPARE(runtime.start(graph.snapshot(), implementations).code, QString());
    QCOMPARE(runtime.execute({entry.id, nextKey}).error.code, QString());
    QTRY_COMPARE(finished.count(), 2);
    QCOMPARE(finished.last().at(1).value<Diagnostic>().code, QString());
    QCOMPARE(calls, 1);
}

void BlueprintRuntimeTest::deepChain()
{
    constexpr int count = 2500;
    GraphSnapshot graph{QUuid::createUuid()};
    PortDefinition initialInput = numberInput;
    initialInput.defaultValue = 0.0;
    for (int i = 0; i < count; ++i) {
        const QUuid id = QUuid::createUuid();
        if (i > 0)
            graph.connections.append({QUuid::createUuid(), {graph.nodes.last().id, valueKey}, {id, inputKey}});
        graph.nodes.append({id, evaluatorType, {}, {initialInput, numberOutput}});
    }
    RuntimeImplementations implementations;
    implementations.evaluators.insert(evaluatorType, [](const QVariantMap &, const QVariantMap &inputs) {
        return EvaluationResult{{{valueKey, inputs.value(inputKey).toDouble() + 1.0}}, {}};
    });
    GraphRuntime runtime;
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto result = runtime.evaluate({graph.nodes.last().id, valueKey});
    QCOMPARE(result.error.code, QString());
    QCOMPARE(result.value.toDouble(), double(count));
}

void BlueprintRuntimeTest::sharesUpstreamWithinOneEvaluation()
{
    const QUuid shared = QUuid::createUuid();
    const QUuid left = QUuid::createUuid();
    const QUuid right = QUuid::createUuid();
    const QUuid merge = QUuid::createUuid();
    PortDefinition otherInput = numberInput;
    otherInput.key = QStringLiteral("other");
    const GraphSnapshot graph{QUuid::createUuid(), 0,
        {{shared, triggerType, {}, {numberOutput}},
         {left, evaluatorType, {}, {numberInput, numberOutput}},
         {right, evaluatorType, {}, {numberInput, numberOutput}},
         {merge, evaluatorType, {}, {numberInput, otherInput, numberOutput}}},
        {{QUuid::createUuid(), {shared, valueKey}, {left, inputKey}},
         {QUuid::createUuid(), {shared, valueKey}, {right, inputKey}},
         {QUuid::createUuid(), {left, valueKey}, {merge, inputKey}},
         {QUuid::createUuid(), {right, valueKey}, {merge, otherInput.key}}}};
    int sharedCalls = 0;
    RuntimeImplementations implementations;
    implementations.evaluators.insert(triggerType, [&](const QVariantMap &, const QVariantMap &) {
        return EvaluationResult{{{valueKey, ++sharedCalls}}, {}};
    });
    implementations.evaluators.insert(evaluatorType, [](const QVariantMap &, const QVariantMap &inputs) {
        double sum = 0;
        for (const auto &input : inputs)
            sum += input.toDouble();
        return EvaluationResult{{{valueKey, sum}}, {}};
    });
    GraphRuntime runtime;
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    for (int i = 1; i <= 2; ++i) {
        const auto result = runtime.evaluate({merge, valueKey});
        QCOMPARE(result.error.code, QString());
        QCOMPARE(result.value.toDouble(), double(2 * i));
        QCOMPARE(sharedCalls, i);
    }
}

void BlueprintRuntimeTest::stopsDuringEvaluation()
{
    const QUuid upstream = QUuid::createUuid();
    const QUuid downstream = QUuid::createUuid();
    const GraphSnapshot graph{QUuid::createUuid(), 0,
        {{upstream, triggerType, {}, {numberOutput}},
         {downstream, evaluatorType, {}, {numberInput, numberOutput}}},
        {{QUuid::createUuid(), {upstream, valueKey}, {downstream, inputKey}}}};
    GraphRuntime runtime;
    int downstreamCalls = 0;
    RuntimeImplementations implementations;
    implementations.evaluators.insert(triggerType, [&](const QVariantMap &, const QVariantMap &) {
        runtime.stop();
        return EvaluationResult{{{valueKey, 1}}, {}};
    });
    implementations.evaluators.insert(evaluatorType, [&](const QVariantMap &, const QVariantMap &) {
        ++downstreamCalls;
        return EvaluationResult{{{valueKey, 2}}, {}};
    });
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto result = runtime.evaluate({downstream, valueKey});
    QCOMPARE(result.error.code, QStringLiteral("runtime.stopped"));
    QCOMPARE(result.error.nodeId, upstream);
    QCOMPARE(downstreamCalls, 0);
}

void BlueprintRuntimeTest::identifiesCycle_data()
{
    QTest::addColumn<bool>("execution");
    QTest::newRow("data") << false;
    QTest::newRow("execution") << true;
}

void BlueprintRuntimeTest::identifiesCycle()
{
    QFETCH(bool, execution);
    const auto &input = execution ? executionInput : numberInput;
    const auto &output = execution ? executionOutput : numberOutput;
    const QUuid downstream = QUuid::createUuid();
    const QUuid first = QUuid::createUuid();
    const QUuid second = QUuid::createUuid();
    const GraphSnapshot graph{QUuid::createUuid(), 0,
        {{downstream, evaluatorType, {}, {input}},
         {first, evaluatorType, {}, {input, output}},
         {second, evaluatorType, {}, {input, output}}},
        {{QUuid::createUuid(), {first, output.key}, {second, input.key}},
         {QUuid::createUuid(), {second, output.key}, {first, input.key}}}};
    GraphSnapshot withDownstream = graph;
    if (execution) {
        PortDefinition otherOutput = output;
        otherOutput.key = alternateKey;
        withDownstream.nodes[1].ports.append(otherOutput);
        withDownstream.connections.prepend({QUuid::createUuid(), {first, alternateKey}, {downstream, input.key}});
    } else {
        withDownstream.connections.prepend({QUuid::createUuid(), {first, output.key}, {downstream, input.key}});
    }
    GraphRuntime runtime;
    const auto error = runtime.start(withDownstream, {});
    QCOMPARE(error.code, QStringLiteral("runtime.cycle"));
    QCOMPARE(error.nodeId, first);
    QCOMPARE(error.key, input.key);
}

void BlueprintRuntimeTest::rejectsIncompleteExecution_data()
{
    QTest::addColumn<QString>("errorCode");
    QTest::newRow("missing action") << QStringLiteral("runtime.missing_action");
    QTest::newRow("unconnected input") << QStringLiteral("runtime.unconnected_input");
    QTest::newRow("missing evaluator") << QStringLiteral("runtime.missing_evaluator");
}

void BlueprintRuntimeTest::rejectsIncompleteExecution()
{
    QFETCH(QString, errorCode);
    const QUuid trigger = QUuid::createUuid();
    const QUuid first = QUuid::createUuid();
    const QUuid sibling = QUuid::createUuid();
    const QUuid second = QUuid::createUuid();
    const QUuid source = QUuid::createUuid();
    PortDefinition defaultInput = numberInput;
    defaultInput.defaultValue = 1.0;
    GraphSnapshot graph{QUuid::createUuid(), 0,
        {{trigger, triggerType, {}, {executionOutput}},
         {first, actionType, {}, {executionInput, executionOutput, defaultInput}},
         {second, actionType, {}, {executionInput, numberInput}},
         {source, missingType, {}, {numberOutput}},
         {sibling, actionType, {}, {executionInput}}},
        {{QUuid::createUuid(), {trigger, nextKey}, {first, enterKey}},
         {QUuid::createUuid(), {first, nextKey}, {sibling, enterKey}},
         {QUuid::createUuid(), {first, nextKey}, {second, enterKey}}}};
    QUuid problemNode = second;
    QString problemKey = inputKey;
    if (errorCode == QStringLiteral("runtime.missing_action")) {
        graph.nodes[2].typeId = missingType;
        problemKey = enterKey;
    } else if (errorCode == QStringLiteral("runtime.missing_evaluator")) {
        graph.connections.append({QUuid::createUuid(), {source, valueKey}, {second, inputKey}});
        problemNode = source;
        problemKey = valueKey;
    }
    int actionCalls = 0;
    RuntimeImplementations implementations;
    implementations.actions.insert(actionType, [&](const ExecutionContext &, RuntimeImplementations::Completion complete) {
        ++actionCalls;
        complete({nextKey, {}, {}});
    });
    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto result = runtime.execute({trigger, nextKey});
    QVERIFY(result.executionId.isNull());
    QCOMPARE(result.error.code, errorCode);
    QCOMPARE(result.error.nodeId, problemNode);
    QCOMPARE(result.error.key, problemKey);
    QCoreApplication::processEvents();
    QCOMPARE(actionCalls, 0);
    QCOMPARE(finished.count(), 0);
}

void BlueprintRuntimeTest::validatesChosenBranch_data()
{
    QTest::addColumn<bool>("chooseIncompleteBranch");
    QTest::newRow("ignores unchosen branch") << false;
    QTest::newRow("prechecks chosen branch") << true;
}

void BlueprintRuntimeTest::validatesChosenBranch()
{
    QFETCH(bool, chooseIncompleteBranch);
    const QUuid trigger = QUuid::createUuid();
    const QUuid choice = QUuid::createUuid();
    const QUuid firstOnBranch = QUuid::createUuid();
    const QUuid missing = QUuid::createUuid();
    PortDefinition alternateOutput = executionOutput;
    alternateOutput.key = alternateKey;
    const GraphSnapshot graph{QUuid::createUuid(), 0,
        {{trigger, triggerType, {}, {executionOutput}},
         {choice, actionType, {}, {executionInput, executionOutput, alternateOutput}},
         {firstOnBranch, actionType, {}, {executionInput, executionOutput}},
         {missing, missingType, {}, {executionInput}}},
        {{QUuid::createUuid(), {trigger, nextKey}, {choice, enterKey}},
         {QUuid::createUuid(), {choice, alternateKey}, {firstOnBranch, enterKey}},
         {QUuid::createUuid(), {firstOnBranch, nextKey}, {missing, enterKey}}}};
    int actionCalls = 0;
    RuntimeImplementations implementations;
    implementations.actions.insert(actionType, [&](const ExecutionContext &context, RuntimeImplementations::Completion complete) {
        ++actionCalls;
        complete({context.nodeId == choice && chooseIncompleteBranch ? alternateKey : nextKey, {}, {}});
    });
    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto result = runtime.execute({trigger, nextKey});
    QCOMPARE(result.error.code, QString());
    QVERIFY(!result.executionId.isNull());
    QCOMPARE(actionCalls, 0);
    QTRY_COMPARE(finished.count(), 1);
    QCOMPARE(actionCalls, 1);
    QCOMPARE(finished.first().at(0).toUuid(), result.executionId);
    const auto error = finished.first().at(1).value<Diagnostic>();
    if (chooseIncompleteBranch) {
        QCOMPARE(error.code, QStringLiteral("runtime.missing_action"));
        QCOMPARE(error.nodeId, missing);
        QCOMPARE(error.key, enterKey);
    } else {
        QCOMPARE(error.code, QString());
    }
}

void BlueprintRuntimeTest::dispatchesBranches_data()
{
    QTest::addColumn<bool>("distinctOutputs");
    QTest::addColumn<QString>("branchError");
    QTest::addColumn<bool>("stop");
    QTest::newRow("multiple outputs finish") << true << QString() << false;
    QTest::newRow("same output finishes both branches") << false << QString() << false;
    QTest::newRow("failure cancels the other branch") << false << QStringLiteral("test.branch_failure") << false;
    QTest::newRow("stop cancels both branches") << false << QString() << true;
}

void BlueprintRuntimeTest::dispatchesBranches()
{
    QFETCH(bool, distinctOutputs);
    QFETCH(QString, branchError);
    QFETCH(bool, stop);
    const QUuid trigger = QUuid::createUuid();
    const QUuid fork = QUuid::createUuid();
    const QUuid first = QUuid::createUuid();
    const QUuid second = QUuid::createUuid();
    const auto forkType = QStringLiteral("fork");
    const auto unwiredKey = QStringLiteral("unwired");
    PortDefinition alternateOutput = executionOutput;
    alternateOutput.key = alternateKey;
    PortDefinition unwiredOutput = executionOutput;
    unwiredOutput.key = unwiredKey;
    GraphSnapshot graph{QUuid::createUuid(), 0,
        {{trigger, triggerType, {}, {executionOutput, alternateOutput}},
         {fork, forkType, {}, {executionInput, executionOutput, numberOutput}},
         {first, actionType, {}, {executionInput, numberInput}},
         {second, actionType, {}, {executionInput, numberInput}}},
        {{QUuid::createUuid(), {trigger, nextKey}, {fork, enterKey}},
         {QUuid::createUuid(), {fork, nextKey}, {first, enterKey}},
         {QUuid::createUuid(), {fork, nextKey}, {second, enterKey}},
         {QUuid::createUuid(), {fork, valueKey}, {first, inputKey}},
         {QUuid::createUuid(), {fork, valueKey}, {second, inputKey}}}};
    if (distinctOutputs) {
        graph.nodes[1].ports += {alternateOutput, unwiredOutput};
        graph.connections[2].source.portKey = alternateKey;
        graph.connections.swapItemsAt(1, 2);
    }
    QVector<ExecutionContext> calls;
    QVector<RuntimeImplementations::Completion> completions;
    QVector<QUuid> cancelled;
    RuntimeImplementations implementations;
    implementations.actions.insert(forkType, [&](const ExecutionContext &, RuntimeImplementations::Completion complete) {
        if (distinctOutputs)
            complete({{}, {{valueKey, 350}}, {}, {unwiredKey, nextKey, alternateKey}});
        else
            complete({nextKey, {{valueKey, 350}}, {}});
    });
    implementations.actions.insert(actionType, [&](const ExecutionContext &context, RuntimeImplementations::Completion complete) {
        calls.append(context);
        completions.append(std::move(complete));
    });
    implementations.cancellations.insert(actionType, [&](const QUuid &callId) { cancelled.append(callId); });

    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto run = runtime.execute({trigger, nextKey});
    QCOMPARE(run.error.code, QString());
    QTRY_COMPARE(calls.size(), 2);
    QCOMPARE(calls.at(0).nodeId, first);
    QCOMPARE(calls.at(1).nodeId, second);
    QVERIFY(calls.at(0).callId != calls.at(1).callId);
    for (const auto &call : calls) {
        QCOMPARE(call.executionId, run.executionId);
        QCOMPARE(call.inputs.value(inputKey).toInt(), 350);
    }
    QCOMPARE(finished.count(), 0);

    if (stop) {
        runtime.stop();
        QCOMPARE(cancelled.size(), 2);
        QVERIFY(cancelled.contains(calls.at(0).callId));
        QVERIFY(cancelled.contains(calls.at(1).callId));
        QCOMPARE(runtime.start(graph, implementations).code, QString());
    } else if (!branchError.isEmpty()) {
        completions.at(0)({{}, {}, {branchError}});
        QTRY_COMPARE(finished.count(), 1);
        QCOMPARE(cancelled, QVector<QUuid>{calls.at(1).callId});
    } else {
        completions.at(1)({});
        completions.at(1)({{}, {}, {QStringLiteral("test.duplicate_completion")}});
        QCoreApplication::sendPostedEvents(&runtime, QEvent::MetaCall);
        QCOMPARE(finished.count(), 0);
        QCOMPARE(runtime.execute({trigger, alternateKey}).error.code, QStringLiteral("runtime.busy"));
        completions.at(0)({});
    }
    QTRY_COMPARE(finished.count(), 1);
    QCOMPARE(finished.first().at(0).toUuid(), run.executionId);
    QCOMPARE(finished.first().at(1).value<Diagnostic>().code,
             stop ? QStringLiteral("runtime.cancelled") : branchError);

    if (stop || !branchError.isEmpty()) {
        completions.at(0)({});
        completions.at(1)({});
        const auto laterRun = runtime.execute({trigger, alternateKey});
        QCOMPARE(laterRun.error.code, QString());
        QCoreApplication::sendPostedEvents(&runtime, QEvent::MetaCall);
        QCOMPARE(finished.count(), 2);
        QCOMPARE(finished.last().at(0).toUuid(), laterRun.executionId);
        QCOMPARE(finished.last().at(1).value<Diagnostic>().code, QString());
        QCOMPARE(calls.size(), 2);
    } else {
        QVERIFY(cancelled.isEmpty());
    }
}

void BlueprintRuntimeTest::validatesBeforeDispatchingBranches()
{
    const QUuid trigger = QUuid::createUuid();
    const QUuid fork = QUuid::createUuid();
    const QUuid first = QUuid::createUuid();
    const QUuid missing = QUuid::createUuid();
    const auto forkType = QStringLiteral("fork");
    PortDefinition alternateOutput = executionOutput;
    alternateOutput.key = alternateKey;
    const GraphSnapshot graph{QUuid::createUuid(), 0,
        {{trigger, triggerType, {}, {executionOutput}},
         {fork, forkType, {}, {executionInput, executionOutput, alternateOutput}},
         {first, actionType, {}, {executionInput}},
         {missing, missingType, {}, {executionInput}}},
        {{QUuid::createUuid(), {trigger, nextKey}, {fork, enterKey}},
         {QUuid::createUuid(), {fork, nextKey}, {first, enterKey}},
         {QUuid::createUuid(), {fork, alternateKey}, {missing, enterKey}}}};
    int firstCalls = 0;
    RuntimeImplementations implementations;
    implementations.actions.insert(forkType, [](const ExecutionContext &, RuntimeImplementations::Completion complete) {
        complete({{}, {}, {}, {nextKey, alternateKey}});
    });
    implementations.actions.insert(actionType, [&](const ExecutionContext &, RuntimeImplementations::Completion complete) {
        ++firstCalls;
        complete({});
    });

    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto run = runtime.execute({trigger, nextKey});
    QCOMPARE(run.error.code, QString());
    QTRY_COMPARE(finished.count(), 1);
    QCOMPARE(finished.first().at(0).toUuid(), run.executionId);
    const auto error = finished.first().at(1).value<Diagnostic>();
    QCOMPARE(error.code, QStringLiteral("runtime.missing_action"));
    QCOMPARE(error.nodeId, missing);
    QCOMPARE(firstCalls, 0);
}

void BlueprintRuntimeTest::queuesMultipleExecutionArrivals_data()
{
    QTest::addColumn<bool>("stop");
    QTest::addColumn<QString>("error");
    QTest::newRow("all arrivals execute") << false << QString();
    QTest::newRow("stop clears queued arrivals") << true << QStringLiteral("runtime.cancelled");
    QTest::newRow("failure clears queued arrivals") << false << QStringLiteral("test.merge_failed");
}

void BlueprintRuntimeTest::queuesMultipleExecutionArrivals()
{
    QFETCH(bool, stop);
    QFETCH(QString, error);
    const QUuid trigger = QUuid::createUuid();
    const QUuid first = QUuid::createUuid();
    const QUuid second = QUuid::createUuid();
    const QUuid shared = QUuid::createUuid();
    const QUuid consumer = QUuid::createUuid();
    const QUuid independent = QUuid::createUuid();
    PortDefinition alternateOutput = executionOutput;
    alternateOutput.key = alternateKey;
    GraphSnapshot graph{QUuid::createUuid(), 0,
        {{trigger, triggerType, {}, {executionOutput, alternateOutput}},
         {first, actionType, {}, {executionInput, executionOutput}},
         {second, actionType, {}, {executionInput, executionOutput}},
         {shared, actionType, {}, {executionInput, executionOutput, numberOutput}},
         {consumer, actionType, {}, {executionInput, numberInput}},
         {independent, actionType, {}, {executionInput}}},
        {{QUuid::createUuid(), {trigger, nextKey}, {shared, enterKey}},
         {QUuid::createUuid(), {trigger, nextKey}, {first, enterKey}},
         {QUuid::createUuid(), {trigger, nextKey}, {second, enterKey}},
         {QUuid::createUuid(), {first, nextKey}, {shared, enterKey}},
         {QUuid::createUuid(), {first, nextKey}, {independent, enterKey}},
         {QUuid::createUuid(), {second, nextKey}, {shared, enterKey}},
         {QUuid::createUuid(), {shared, nextKey}, {consumer, enterKey}},
         {QUuid::createUuid(), {shared, valueKey}, {consumer, inputKey}}}};
    QVector<ExecutionContext> sharedCalls;
    QVector<RuntimeImplementations::Completion> sharedCompletions;
    QVector<int> received;
    QVector<RuntimeImplementations::Completion> consumerCompletions;
    QVector<QUuid> cancelled;
    bool independentStarted = false;
    RuntimeImplementations implementations;
    implementations.actions.insert(actionType, [&](const ExecutionContext &context, RuntimeImplementations::Completion complete) {
        if (context.nodeId == shared) {
            sharedCalls.append(context);
            sharedCompletions.append(std::move(complete));
        } else if (context.nodeId == consumer) {
            received.append(context.inputs.value(inputKey).toInt());
            consumerCompletions.append(std::move(complete));
        } else if (context.nodeId == independent) {
            independentStarted = true;
            complete({});
        } else {
            complete({nextKey, {}, {}});
        }
    });
    implementations.cancellations.insert(actionType, [&](const QUuid &callId) { cancelled.append(callId); });

    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    auto duplicate = graph.connections.first();
    duplicate.id = QUuid::createUuid();
    graph.connections.append(duplicate);
    QCOMPARE(runtime.start(graph, implementations).code, QStringLiteral("runtime.duplicate_connection"));
    graph.connections.removeLast();
    QCOMPARE(runtime.start(graph, implementations).code, QString());
    const auto execution = runtime.execute({trigger, nextKey});
    QCOMPARE(execution.error.code, QString());
    QTRY_VERIFY(independentStarted);
    QCOMPARE(sharedCalls.size(), 1);
    QCOMPARE(finished.count(), 0);

    if (stop) {
        runtime.stop();
        QCOMPARE(cancelled, QVector<QUuid>{sharedCalls.first().callId});
        QCOMPARE(runtime.start(graph, implementations).code, QString());
    } else if (!error.isEmpty()) {
        sharedCompletions.first()({{}, {}, {error}});
    } else {
        sharedCompletions.first()({nextKey, {{valueKey, 100}}, {}});
        QTRY_COMPARE(sharedCalls.size(), 2);
        QCOMPARE(received, QVector<int>{100});

        sharedCompletions.at(1)({nextKey, {{valueKey, 200}}, {}});
        QTRY_COMPARE(sharedCalls.size(), 3);
        QCOMPARE(received, QVector<int>{100});

        // 共享动作第三次执行时，消费者仍须读取第二次通知携带的结果。
        consumerCompletions.first()({});
        QTRY_COMPARE(received, (QVector<int>{100, 200}));
        sharedCompletions.at(2)({nextKey, {{valueKey, 300}}, {}});
        consumerCompletions.at(1)({});
        QTRY_COMPARE(received, (QVector<int>{100, 200, 300}));
        QCOMPARE(finished.count(), 0);
        consumerCompletions.at(2)({});
    }

    QTRY_COMPARE(finished.count(), 1);
    QCOMPARE(finished.first().at(0).toUuid(), execution.executionId);
    QCOMPARE(finished.first().at(1).value<Diagnostic>().code, error);
    if (!error.isEmpty()) {
        sharedCompletions.first()({nextKey, {{valueKey, 400}}, {}});
        const auto next = runtime.execute({trigger, alternateKey});
        QCOMPARE(next.error.code, QString());
        QTRY_COMPARE(finished.count(), 2);
        QCOMPARE(finished.last().at(1).value<Diagnostic>().code, QString());
        QCOMPARE(sharedCalls.size(), 1);
        QVERIFY(received.isEmpty());
    }
}

void BlueprintRuntimeTest::preservesOutputWhenCompletionReentersDispatch()
{
    const QUuid trigger = QUuid::createUuid();
    const QUuid shared = QUuid::createUuid();
    const QUuid independent = QUuid::createUuid();
    const QUuid consumer = QUuid::createUuid();
    PortDefinition alternateInput = executionInput;
    alternateInput.key = alternateKey;
    const GraphSnapshot graph{QUuid::createUuid(), 0,
        {{trigger, triggerType, {}, {executionOutput}},
         {shared, actionType, {}, {executionInput, alternateInput, executionOutput, numberOutput}},
         {independent, actionType, {}, {executionInput}},
         {consumer, actionType, {}, {executionInput, numberInput}}},
        {{QUuid::createUuid(), {trigger, nextKey}, {shared, enterKey}},
         {QUuid::createUuid(), {trigger, nextKey}, {independent, enterKey}},
         {QUuid::createUuid(), {trigger, nextKey}, {shared, alternateKey}},
         {QUuid::createUuid(), {shared, nextKey}, {consumer, enterKey}},
         {QUuid::createUuid(), {shared, valueKey}, {consumer, inputKey}}}};
    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    RuntimeImplementations::Completion first;
    RuntimeImplementations::Completion second;
    QVector<int> received;
    RuntimeImplementations implementations;
    implementations.actions.insert(actionType, [&](const ExecutionContext &context, RuntimeImplementations::Completion complete) {
        if (context.nodeId == shared) {
            if (context.inputPort == enterKey)
                first = std::move(complete);
            else
                second = std::move(complete);
        } else if (context.nodeId == independent) {
            first({nextKey, {{valueKey, 100}}, {}});
            QCoreApplication::sendPostedEvents(&runtime, QEvent::MetaCall);
            complete({});
        } else {
            received.append(context.inputs.value(inputKey).toInt());
            complete({});
        }
    });

    QCOMPARE(runtime.start(graph, implementations).code, QString());
    QCOMPARE(runtime.execute({trigger, nextKey}).error.code, QString());
    QTRY_VERIFY(static_cast<bool>(second));
    QCOMPARE(received, QVector<int>{100});
    second({nextKey, {{valueKey, 200}}, {}});
    QTRY_COMPARE(finished.count(), 1);
    QCOMPARE(finished.first().at(1).value<Diagnostic>().code, QString());
    QCOMPARE(received, (QVector<int>{100, 200}));
}

void BlueprintRuntimeTest::snapshotsEntryOutputs()
{
    const QUuid trigger = QUuid::createUuid();
    const QUuid choice = QUuid::createUuid();
    const QUuid directConsumer = QUuid::createUuid();
    const QUuid firstConsumer = QUuid::createUuid();
    const QUuid secondConsumer = QUuid::createUuid();
    const auto choiceType = QStringLiteral("choice");
    PortDefinition alternateOutput = executionOutput;
    alternateOutput.key = alternateKey;
    const GraphSnapshot graph{QUuid::createUuid(), 0,
        {{trigger, triggerType, {}, {executionOutput, numberOutput}},
         {choice, choiceType, {}, {executionInput, numberInput, executionOutput, alternateOutput}},
         {directConsumer, actionType, {}, {executionInput, numberInput}},
         {firstConsumer, actionType, {}, {executionInput, numberInput}},
         {secondConsumer, actionType, {}, {executionInput, numberInput}}},
        {{QUuid::createUuid(), {trigger, nextKey}, {choice, enterKey}},
         {QUuid::createUuid(), {trigger, nextKey}, {directConsumer, enterKey}},
         {QUuid::createUuid(), {trigger, valueKey}, {choice, inputKey}},
         {QUuid::createUuid(), {trigger, valueKey}, {directConsumer, inputKey}},
         {QUuid::createUuid(), {choice, alternateKey}, {firstConsumer, enterKey}},
         {QUuid::createUuid(), {choice, alternateKey}, {secondConsumer, enterKey}},
         {QUuid::createUuid(), {trigger, valueKey}, {firstConsumer, inputKey}},
         {QUuid::createUuid(), {trigger, valueKey}, {secondConsumer, inputKey}}}};
    QHash<QUuid, QVector<ExecutionContext>> received;
    RuntimeImplementations implementations;
    implementations.actions.insert(choiceType, [&](const ExecutionContext &context, RuntimeImplementations::Completion complete) {
        received[context.executionId].append(context);
        complete({alternateKey, {}, {}});
    });
    implementations.actions.insert(actionType, [&](const ExecutionContext &context, RuntimeImplementations::Completion complete) {
        received[context.executionId].append(context);
        complete({});
    });

    GraphRuntime first;
    GraphRuntime second;
    QSignalSpy firstFinished(&first, &GraphRuntime::executionFinished);
    QSignalSpy secondFinished(&second, &GraphRuntime::executionFinished);
    QCOMPARE(first.start(graph, implementations).code, QString());
    QCOMPARE(second.start(graph, implementations).code, QString());
    const Endpoint entry{trigger, nextKey};
    const auto invalid = first.execute(entry, {{valueKey, true}});
    QCOMPARE(invalid.error.code, QStringLiteral("runtime.invalid_output"));
    QCOMPARE(invalid.error.nodeId, trigger);
    QCOMPARE(invalid.error.key, valueKey);
    QVERIFY(invalid.executionId.isNull());

    QVariantMap values{{valueKey, 123}};
    const auto firstRun = first.execute(entry, values);
    QCOMPARE(firstRun.error.code, QString());
    values[valueKey] = 456;
    const auto secondRun = second.execute(entry, values);
    QCOMPARE(secondRun.error.code, QString());
    QVERIFY(received.isEmpty());
    QTRY_COMPARE(firstFinished.count(), 1);
    QTRY_COMPARE(secondFinished.count(), 1);
    QCOMPARE(firstFinished.first().at(1).value<Diagnostic>().code, QString());
    QCOMPARE(secondFinished.first().at(1).value<Diagnostic>().code, QString());
    const QVector<QUuid> expectedOrder{choice, directConsumer, firstConsumer, secondConsumer};
    for (const auto &run : {firstRun, secondRun}) {
        const auto calls = received.value(run.executionId);
        QCOMPARE(calls.size(), expectedOrder.size());
        const int expectedValue = run.executionId == firstRun.executionId ? 123 : 456;
        for (int i = 0; i < calls.size(); ++i) {
            QCOMPARE(calls.at(i).nodeId, expectedOrder.at(i));
            QCOMPARE(calls.at(i).inputs.value(inputKey).toInt(), expectedValue);
        }
    }

    const auto missing = first.execute(entry);
    QCOMPARE(missing.error.code, QStringLiteral("runtime.missing_evaluator"));
    QVERIFY(missing.executionId.isNull());
}

void BlueprintRuntimeTest::runsObjectNodesWithHostAdapter()
{
    const auto objectType = QStringLiteral("test.named-output");
    const auto objectId = QStringLiteral("output-17");
    const auto enabledKey = QStringLiteral("enabled");
    const auto nameKey = QStringLiteral("name");
    const auto lockedKey = QStringLiteral("locked");
    const auto resultKey = QStringLiteral("renamed");
    const auto rename = QStringLiteral("rename");
    const auto boolType = QStringLiteral("bool");
    const auto stringType = QStringLiteral("string");
    const auto targetKey = QStringLiteral("target");
    const auto memberKey = QStringLiteral("member");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto setType = QStringLiteral("demo.setProperty");

    NodeRegistry registry;
    NodeTypeDefinition object;
    object.typeId = objectType;
    object.displayName = objectType;
    object.properties = {{{enabledKey, boolType}, true}, {{nameKey, stringType}, true}, {{lockedKey, boolType}, false}};
    object.methods = {{rename, rename, {{nameKey, stringType}, {enabledKey, boolType}}, {{resultKey, stringType}}}};
    QCOMPARE(registry.add(object).code, QString());
    QCOMPARE(registry.add({triggerType, triggerType, {executionOutput, {valueKey, PortDirection::Output, boolType}}}).code, QString());

    QVariantMap state{{enabledKey, false}, {nameKey, QStringLiteral("old name")}, {lockedKey, true}};
    int writes = 0;
    QVariantMap received;
    QUuid invokedCall;
    QUuid cancelledCall;
    ObjectNodeBindings::MethodCompletion completeCall;
    ObjectNodeBindings bindings;
    bindings.targetType = [&](const QString &id) { return id == objectId ? objectType : QString(); };
    bindings.read = [&](const QString &id, const QString &member) -> ValueResult {
        if (id != objectId)
            return {{}, {QStringLiteral("test.unexpected_object"), {}}};
        return {state.value(member), {}};
    };
    bindings.write = [&](const QString &id, const QString &member, const QVariant &value) -> Diagnostic {
        if (id != objectId)
            return {QStringLiteral("test.unexpected_object"), {}};
        ++writes;
        state.insert(member, value);
        return {};
    };
    bindings.invoke = [&](const QString &id, const QString &member, const QUuid &callId, const QVariantMap &inputs,
                          ObjectNodeBindings::MethodCompletion completion) -> Diagnostic {
        if (id != objectId || member != rename)
            return {QStringLiteral("test.unexpected_method"), {}};
        received = inputs;
        invokedCall = callId;
        completeCall = std::move(completion);
        return {};
    };
    bindings.cancel = [&](const QUuid &callId) { cancelledCall = callId; };
    QCOMPARE(registerObjectNodes(registry, bindings.targetType).code, QString());
    RuntimeImplementations implementations;
    addObjectImplementations(implementations, registry, bindings);

    GraphDocument document(registry);
    const auto entry = document.addNode(triggerType, {}).id;
    const auto setEnabled = document.addNode(setType, {}, {{targetKey, objectId}, {memberKey, enabledKey}}).id;
    const auto setName = document.addNode(setType, {}, {{targetKey, objectId}, {memberKey, nameKey}}).id;
    const auto readEnabled = document.addNode(QStringLiteral("demo.readProperty"), {}, {{targetKey, objectId}, {memberKey, enabledKey}}).id;
    const auto readName = document.addNode(QStringLiteral("demo.readProperty"), {}, {{targetKey, objectId}, {memberKey, nameKey}}).id;
    const auto call = document.addNode(QStringLiteral("demo.call"), {}, {{targetKey, objectId}, {memberKey, rename}}).id;
    for (const auto &node : {entry, setEnabled, setName, readEnabled, readName, call})
        QVERIFY(!node.isNull());

    const auto callEnabled = objectCallPortKey(PortDirection::Input, objectType, rename, enabledKey);
    const auto callName = objectCallPortKey(PortDirection::Input, objectType, rename, nameKey);
    const auto callOutput = objectCallPortKey(PortDirection::Output, objectType, rename, resultKey);
    QCOMPARE(document.setParameter(call, callName, QStringLiteral("local default")).error.code, QString());
    QCOMPARE(document.connectPorts({entry, nextKey}, {setEnabled, execIn}).error.code, QString());
    QCOMPARE(document.connectPorts({entry, valueKey}, {setEnabled, valueKey}).error.code, QString());
    QCOMPARE(document.connectPorts({setEnabled, execOut}, {call, execIn}).error.code, QString());
    QCOMPARE(document.connectPorts({readEnabled, valueKey}, {call, callEnabled}).error.code, QString());
    QCOMPARE(document.connectPorts({readName, valueKey}, {call, callName}).error.code, QString());
    QCOMPARE(document.connectPorts({call, execOut}, {setName, execIn}).error.code, QString());
    QCOMPARE(document.connectPorts({call, callOutput}, {setName, valueKey}).error.code, QString());

    GraphRuntime runtime;
    QSignalSpy finished(&runtime, &GraphRuntime::executionFinished);
    const auto snapshot = document.snapshot();
    QCOMPARE(runtime.start(snapshot, implementations).code, QString());
    state.insert(nameKey, QStringLiteral("live name"));
    const auto live = runtime.evaluate({readName, valueKey});
    QCOMPARE(live.error.code, QString());
    QCOMPARE(live.value.toString(), QStringLiteral("live name"));
    QCOMPARE(runtime.execute({entry, nextKey}, {{valueKey, true}}).error.code, QString());
    QTRY_VERIFY(static_cast<bool>(completeCall));
    QCOMPARE(received.value(enabledKey), QVariant(true));
    QCOMPARE(received.value(nameKey).toString(), QStringLiteral("live name"));
    QCOMPARE(writes, 1);
    QVERIFY(finished.isEmpty());
    std::exchange(completeCall, {})({{resultKey, QStringLiteral("new name")}}, {});
    QTRY_COMPARE(finished.size(), 1);
    QCOMPARE(finished.first().at(1).value<Diagnostic>().code, QString());
    QCOMPARE(writes, 2);
    QCOMPARE(state.value(nameKey).toString(), QStringLiteral("new name"));

    runtime.stop();
    auto invalid = snapshot;
    for (auto &node : invalid.nodes) {
        if (node.id == setEnabled)
            node.parameters.insert(memberKey, lockedKey);
    }
    QCOMPARE(runtime.start(invalid, implementations).code, QString());
    QCOMPARE(runtime.execute({entry, nextKey}, {{valueKey, false}}).error.code, QString());
    QTRY_COMPARE(finished.size(), 2);
    const auto error = finished.last().at(1).value<Diagnostic>();
    QVERIFY(!error.code.isEmpty());
    QCOMPARE(error.nodeId, setEnabled);
    QCOMPARE(writes, 2);
    QCOMPARE(state.value(lockedKey), QVariant(true));
    QVERIFY(!completeCall);

    runtime.stop();
    QCOMPARE(runtime.start(snapshot, implementations).code, QString());
    QCOMPARE(runtime.execute({entry, nextKey}, {{valueKey, false}}).error.code, QString());
    QTRY_VERIFY(static_cast<bool>(completeCall));
    QVERIFY(!invokedCall.isNull());
    runtime.stop();
    QCOMPARE(cancelledCall, invokedCall);
    QCOMPARE(finished.size(), 3);
    QCOMPARE(finished.last().at(1).value<Diagnostic>().code, "runtime.cancelled");
    std::exchange(completeCall, {})({{resultKey, QStringLiteral("late name")}}, {});
    QCoreApplication::sendPostedEvents(&runtime, QEvent::MetaCall);
    QCOMPARE(finished.size(), 3);
    QCOMPARE(writes, 3);
    QCOMPARE(state.value(nameKey).toString(), QStringLiteral("new name"));
}

QTEST_GUILESS_MAIN(BlueprintRuntimeTest)
#include "runtime_test.moc"
