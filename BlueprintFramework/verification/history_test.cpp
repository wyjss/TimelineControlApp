#include <Blueprint/GraphEditSession.h>

#include "DemoGraph.h"

#include <QElapsedTimer>
#include <QPersistentModelIndex>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

using namespace Blueprint;

class BlueprintHistoryTest final : public QObject
{
    Q_OBJECT

private slots:
    void undoUpdatesOnlyChangedRoles();
    void undoKeepsConnectionIdsAndNodeOrder();
    void historyBudgetKeepsSavePointSemantics();
    void undoAndOpenDuringPlayback();
    void comparisonControlsInterfaceCall();
    void callUsesDeclaredInputsAndOutputs();
    void executionResultsFlowThroughCalculations();
    void dispatchesPlaybackToBothSpeakers();
    void queuesPlaybackFromMultipleExecutionInputs();
    void waitsFromArrivalAndStops();
    void waitsFromAutomaticEntry();
    void recordsDeviceCommandsOnArrival();
    void propertyEventsRunAlongsideManualWait();
    void tracksOverlappingPropertyEventStates();
};

void BlueprintHistoryTest::undoUpdatesOnlyChangedRoles()
{
    NodeRegistry registry;
    NodeTypeDefinition type;
    type.typeId = QStringLiteral("number");
    type.parameters = {{QStringLiteral("value"), QStringLiteral("number"), 2.0}};
    type.resolvePorts = [](const NodeData &node) {
        const bool configured = node.parameterOverrides.contains(QStringLiteral("value"));
        return QVector<PortDefinition>{{QStringLiteral("out"), PortDirection::Output,
            configured ? QStringLiteral("number") : QString()}};
    };
    QVERIFY(registry.add(type).code.isEmpty());
    GraphDocument document(registry);
    const auto node = document.addNode(type.typeId, {}).id;
    QVERIFY(!node.isNull());
    GraphEditSession session(document);
    const QPersistentModelIndex originalIndex(session.index(0));
    QSignalSpy reset(&session, &GraphEditSession::modelReset);
    QSignalSpy changes(&session, &GraphEditSession::dataChanged);
    QSignalSpy commits(&document, &GraphDocument::changed);
    const int positionRole = session.roleNames().key("nodePosition");
    const int parametersRole = session.roleNames().key("nodeParameters");
    const int inputRole = session.roleNames().key("inputPorts");
    const int outputRole = session.roleNames().key("outputPorts");

    session.moveNode(node.toString(), {40, 20});
    QVERIFY(session.setParameter(node.toString(), QStringLiteral("value"), 4.0));
    const auto revision = document.revision();
    changes.clear();
    commits.clear();

    session.undo();
    QCOMPARE(document.parameterValue(node, QStringLiteral("value")).toDouble(), 2.0);
    QVERIFY(document.nodePorts(node).first().valueTypeId.isEmpty());
    QCOMPARE(document.findNode(node)->position, QPointF(40, 20));
    QVERIFY(session.modified());
    session.undo();
    QCOMPARE(document.findNode(node)->position, QPointF());
    QVERIFY(!session.modified());
    QCOMPARE(document.revision(), revision + 2);
    QCOMPARE(reset.size(), 0);
    QCOMPARE(changes.size(), 2);
    QCOMPARE(changes.at(0).at(2).value<QVector<int>>(), (QVector<int>{parametersRole, inputRole, outputRole}));
    QCOMPARE(changes.at(1).at(2).value<QVector<int>>(), QVector<int>{positionRole});
    QCOMPARE(commits.size(), 2);
    QVERIFY(!commits.at(0).at(0).value<GraphChangeSet>().reset);
    QVERIFY(!commits.at(1).at(0).value<GraphChangeSet>().reset);
    QCOMPARE(originalIndex, session.index(0));
}

void BlueprintHistoryTest::undoKeepsConnectionIdsAndNodeOrder()
{
    NodeRegistry registry;
    NodeTypeDefinition type;
    type.typeId = QStringLiteral("number");
    type.ports = {{QStringLiteral("out"), PortDirection::Output, QStringLiteral("number")},
                  {QStringLiteral("in"), PortDirection::Input, QStringLiteral("number")}};
    QVERIFY(registry.add(type).code.isEmpty());
    GraphDocument document(registry);
    const auto first = document.addNode(type.typeId, {}).id;
    const auto second = document.addNode(type.typeId, {}).id;
    const auto third = document.addNode(type.typeId, {}).id;
    const Endpoint source{first, QStringLiteral("out")};
    const Endpoint target{second, QStringLiteral("in")};
    const auto link = document.connectPorts(source, target).id;
    QVERIFY(!link.isNull());
    GraphEditSession session(document);
    const int idRole = session.roleNames().key("nodeId");
    const QPersistentModelIndex thirdIndex(session.index(2));
    QSignalSpy reset(&session, &GraphEditSession::modelReset);
    QSignalSpy commits(&document, &GraphDocument::changed);

    QVERIFY(document.reconnectConnection(link, source, {third, target.portKey}).error.code.isEmpty());
    session.undo();
    QCOMPARE(document.data().connections.size(), 1);
    QCOMPARE(document.data().connections.first().id, link);
    QCOMPARE(document.data().connections.first().target.nodeId, second);
    const auto restored = commits.last().at(0).value<GraphChangeSet>();
    QCOMPARE(restored.removedConnectionIds, QVector<QUuid>{link});
    QCOMPARE(restored.addedConnectionIds, QVector<QUuid>{link});
    session.redo();
    QCOMPARE(document.data().connections.first().id, link);
    QCOMPARE(document.data().connections.first().target.nodeId, third);
    session.undo();

    session.removeNode(second.toString());
    QVERIFY(document.data().connections.isEmpty());
    QCOMPARE(thirdIndex.row(), 1);
    commits.clear();
    session.undo();
    QCOMPARE(commits.size(), 1);
    const auto insertion = commits.first().at(0).value<GraphChangeSet>();
    QCOMPARE(insertion.addedNodeIds, QVector<QUuid>{second});
    QCOMPARE(insertion.addedConnectionIds, QVector<QUuid>{link});
    QCOMPARE(document.data().connections.first().id, link);
    QCOMPARE(session.rowCount(), 3);
    QCOMPARE(session.index(1).data(idRole).toString(), second.toString(QUuid::WithoutBraces));
    QCOMPARE(thirdIndex.row(), 2);
    QCOMPARE(reset.size(), 0);
}

void BlueprintHistoryTest::historyBudgetKeepsSavePointSemantics()
{
    NodeRegistry registry;
    NodeTypeDefinition type;
    type.typeId = QStringLiteral("card");
    QVERIFY(registry.add(type).code.isEmpty());
    GraphDocument document(registry);
    const auto node = document.addNode(type.typeId, {}).id;
    GraphEditSession session(document);
    for (int step = 1; step <= 101; ++step)
        session.moveNode(node.toString(), {qreal(step), 0});

    for (int step = 0; step < 100; ++step) {
        QVERIFY(session.canUndo());
        session.undo();
    }
    QVERIFY(!session.canUndo());
    QVERIFY(session.modified());
    QCOMPARE(document.findNode(node)->position, QPointF(1, 0));

    session.markSaved();
    QVERIFY(!session.modified());
    session.redo();
    QVERIFY(session.modified());
    session.undo();
    QVERIFY(!session.modified());
    session.redo();
    session.markSaved();
    session.undo();
    session.moveNode(node.toString(), {20, 0});
    QVERIFY(!session.canRedo());
    QVERIFY(session.modified());
}

void BlueprintHistoryTest::undoAndOpenDuringPlayback()
{
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);
    const auto roles = session->roleNames();
    QString speaker;
    QString trigger;
    QStringList speakerNames;
    QPointF speakerPosition;
    for (int row = 0; row < session->rowCount(); ++row) {
        const auto index = session->index(row);
        const auto type = index.data(roles.key("nodeType")).toString();
        if (type == QStringLiteral("demo.speaker")) {
            speakerNames.append(index.data(roles.key("nodeParameters")).toMap().value(QStringLiteral("name")).toString());
            if (speaker.isEmpty()) {
                speaker = index.data(roles.key("nodeId")).toString();
                speakerPosition = index.data(roles.key("nodePosition")).toPointF();
            }
        } else if (type == QStringLiteral("demo.trigger")) {
            trigger = index.data(roles.key("nodeId")).toString();
        }
    }
    QVERIFY(!speaker.isEmpty());
    QVERIFY(!trigger.isEmpty());
    QCOMPARE(speakerNames, (QStringList{QStringLiteral("模拟音箱 1"), QStringLiteral("模拟音箱 2")}));
    const auto speakerTarget = QStringLiteral("node:demo.speaker:") + speaker;
    const QVariantMap initialSpeaker{{QStringLiteral("value"), speakerTarget},
                                     {QStringLiteral("label"), QStringLiteral("模拟音箱 1")}};
    const QVariantMap renamedSpeaker{{QStringLiteral("value"), speakerTarget},
                                     {QStringLiteral("label"), QStringLiteral("主音箱")}};
    const QVariantMap initialReadTarget{{QStringLiteral("value"), speakerTarget},
                                        {QStringLiteral("name"), QStringLiteral("模拟音箱 1")},
                                        {QStringLiteral("label"), QStringLiteral("模拟音箱 1")}};
    const QVariantMap renamedReadTarget{{QStringLiteral("value"), speakerTarget},
                                        {QStringLiteral("name"), QStringLiteral("主音箱")},
                                        {QStringLiteral("label"), QStringLiteral("主音箱")}};
    QVERIFY(demo.speakerOptions().contains(initialSpeaker));
    QVERIFY(demo.readTargetOptions().contains(initialReadTarget));
    QVERIFY(session->setParameter(speaker, QStringLiteral("name"), QStringLiteral("主音箱")));
    QVERIFY(demo.speakerOptions().contains(renamedSpeaker));
    QVERIFY(demo.readTargetOptions().contains(renamedReadTarget));
    session->undo();
    QVERIFY(demo.speakerOptions().contains(initialSpeaker));
    QVERIFY(demo.readTargetOptions().contains(initialReadTarget));
    session->redo();
    QVERIFY(demo.speakerOptions().contains(renamedSpeaker));
    QVERIFY(demo.readTargetOptions().contains(renamedReadTarget));
    const auto playing = QStringLiteral("playing");
    const auto duration = QStringLiteral("testDurationMs");
    QTemporaryDir files;
    QVERIFY(files.isValid());
    const auto graphFile = QUrl::fromLocalFile(files.filePath(QStringLiteral("graph.json")));
    QVERIFY(demo.save(graphFile));

    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(demo.speakerState(speakerTarget).value(playing).toBool());
    QCOMPARE(demo.speakerState(speakerTarget).value(duration).toInt(), 3000);
    session->moveNode(speaker, speakerPosition + QPointF(5, 10));
    session->undo();
    QVERIFY(demo.speakerState(speakerTarget).value(playing).toBool());
    QCOMPARE(demo.speakerState(speakerTarget).value(duration).toInt(), 3000);
    QVERIFY(session->canRedo());

    const auto missing = QUrl::fromLocalFile(files.filePath(QStringLiteral("missing.json")));
    QVERIFY(!demo.open(missing));
    QVERIFY(demo.speakerState(speakerTarget).value(playing).toBool());
    QVERIFY(session->canRedo());
    QVERIFY(demo.open(graphFile));
    QVERIFY(demo.speakerOptions().contains(renamedSpeaker));
    QVERIFY(demo.readTargetOptions().contains(renamedReadTarget));
    QCoreApplication::processEvents();
    QVERIFY(demo.error().isEmpty());
    QVERIFY(!demo.speakerState(speakerTarget).value(playing).toBool());
    QCOMPARE(demo.speakerState(speakerTarget).value(duration).toInt(), 2000);
    QVERIFY(!session->canUndo());
    QVERIFY(!session->canRedo());
    QVERIFY(!session->modified());

    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(demo.speakerState(speakerTarget).value(playing).toBool());
    session->removeNode(speaker);
    QVERIFY(demo.speakerState(speakerTarget).isEmpty());
    session->undo();
    QVERIFY(session->containsNode(speaker));
    QVERIFY(!demo.speakerState(speakerTarget).value(playing).toBool());
}

void BlueprintHistoryTest::comparisonControlsInterfaceCall()
{
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto left = session->addNode(QStringLiteral("demo.constant"), {});
    const auto right = session->addNode(QStringLiteral("demo.constant"), {});
    const auto compare = session->addNode(QStringLiteral("demo.compare"), {});
    const auto branchType = QStringLiteral("demo.branch");
    bool listedInFlow = false;
    for (const auto &group : demo.palette()) {
        const auto category = group.toMap();
        if (category.value(QStringLiteral("id")).toString() != QStringLiteral("flow"))
            continue;
        for (const auto &node : category.value(QStringLiteral("nodes")).toList())
            listedInFlow |= node.toMap().value(QStringLiteral("type")).toString() == branchType;
    }
    QVERIFY(listedInFlow);
    const auto branch = session->addNode(branchType, {});
    const auto callType = QStringLiteral("demo.call");
    const auto play = QStringLiteral("playTest");
    const auto playing = QStringLiteral("playing");
    const auto trueSpeaker = QStringLiteral("host:demo.speaker:speaker-a");
    const auto falseSpeaker = QStringLiteral("host:demo.speaker:speaker-b");
    const auto trueCall = demo.addOperation(callType, trueSpeaker, play, {});
    const auto falseCall = demo.addOperation(callType, falseSpeaker, play, {});
    const auto value = QStringLiteral("value");
    const auto execute = QStringLiteral("execIn");

    QVERIFY(session->connectPorts(left, value, compare, QStringLiteral("A")));
    QVERIFY(session->connectPorts(right, value, compare, QStringLiteral("B")));
    QVERIFY(session->connectPorts(compare, value, branch, QStringLiteral("condition")));
    QVERIFY(session->connectPorts(trigger, QStringLiteral("execOut"), branch, execute));
    QVERIFY(session->connectPorts(branch, QStringLiteral("true"), trueCall, execute));
    QVERIFY(session->connectPorts(branch, QStringLiteral("false"), falseCall, execute));

    QVERIFY(session->setParameter(right, value, 1.0));
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(demo.speakerState(falseSpeaker).value(playing).toBool());
    QVERIFY(!demo.speakerState(trueSpeaker).value(playing).toBool());

    QVERIFY(session->setParameter(right, value, 0.0));
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(demo.speakerState(trueSpeaker).value(playing).toBool());
    QVERIFY(!demo.speakerState(falseSpeaker).value(playing).toBool());
    QVERIFY(demo.error().isEmpty());
}

void BlueprintHistoryTest::callUsesDeclaredInputsAndOutputs()
{
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto speakerA = QStringLiteral("host:demo.speaker:speaker-a");
    const auto speakerB = QStringLiteral("host:demo.speaker:speaker-b");
    const auto duration = QStringLiteral("testDurationMs");
    const auto playing = QStringLiteral("playing");
    const auto playFor = QStringLiteral("playFor");
    const auto input = QStringLiteral("in/demo.speaker/playFor/testDurationMs");
    const auto output = QStringLiteral("out/demo.speaker/playFor/playedDurationMs");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto value = QStringLiteral("value");
    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto constant = session->addNode(QStringLiteral("demo.constant"), {});
    const auto consumer = demo.addOperation(QStringLiteral("demo.setProperty"), speakerA, duration, {});
    const auto call = session->addNode(QStringLiteral("demo.call"), {});
    const int callRow = session->rowCount() - 1;
    const auto result = session->addNode(QStringLiteral("demo.result"), {});
    const int parametersRole = session->roleNames().key("nodeParameters");
    QVERIFY(!trigger.isEmpty() && !constant.isEmpty() && !consumer.isEmpty() && !call.isEmpty() && !result.isEmpty());

    QVERIFY(demo.bindCall(call, speakerA, {}));
    QVERIFY(demo.callInputs(call).isEmpty());
    QVERIFY(demo.bindCall(call, speakerA, playFor));
    const auto inputs = demo.callInputs(call);
    QCOMPARE(inputs.size(), 1);
    QCOMPARE(inputs.first().toMap().value(QStringLiteral("key")).toString(), input);
    QCOMPARE(inputs.first().toMap().value(value).toInt(), 2000);
    QVERIFY(!demo.setCallInput(call, input, QStringLiteral("250.5")));
    QCOMPARE(demo.callInputs(call).first().toMap().value(value).toInt(), 2000);
    QVERIFY(demo.setCallInput(call, input, QStringLiteral("250")));
    QVERIFY(demo.callInputs(call).first().toMap().value(QStringLiteral("edited")).toBool());
    QVERIFY(demo.setCallInput(call, input, {}));
    QCOMPARE(demo.callInputs(call).first().toMap().value(value).toInt(), 2000);
    QVERIFY(!demo.callInputs(call).first().toMap().value(QStringLiteral("edited")).toBool());
    QVERIFY(demo.setCallInput(call, input, QStringLiteral("250")));

    QVERIFY(session->setParameter(constant, value, 350.0));
    QVERIFY(session->connectPorts(constant, value, call, input));
    QVERIFY(session->connectPorts(trigger, execOut, call, execIn));
    QVERIFY(session->connectPorts(call, output, consumer, execIn));
    QVERIFY(session->connectPorts(call, output, consumer, value));
    QVERIFY(session->connectPorts(call, output, result, value));
    const auto links = session->connections();
    QVERIFY(demo.bindCall(call, speakerB, playFor));
    QCOMPARE(session->connections(), links);
    QVERIFY(!demo.bindCall(call, speakerA, QStringLiteral("stop")));
    QVERIFY(!session->error().isEmpty());
    QCOMPARE(session->connections(), links);
    const auto parameters = session->index(callRow).data(parametersRole).toMap();
    QCOMPARE(parameters.value(QStringLiteral("target")).toString(), speakerB);
    QCOMPARE(parameters.value(QStringLiteral("member")).toString(), playFor);

    QTemporaryDir files;
    QVERIFY(files.isValid());
    const auto graphFile = QUrl::fromLocalFile(files.filePath(QStringLiteral("call.json")));
    QVERIFY(demo.save(graphFile));
    QVERIFY(demo.open(graphFile));
    QCOMPARE(session->connections(), links);
    QVERIFY(!demo.previewValues().contains(result));
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(demo.speakerState(speakerB).value(playing).toBool());
    QCOMPARE(demo.speakerState(speakerA).value(duration).toInt(), 2000);
    QTRY_COMPARE(demo.speakerState(speakerA).value(duration).toInt(), 350);
    QTRY_COMPARE(demo.previewValues().value(result).toString(), QStringLiteral("350"));
    QVERIFY(!demo.speakerState(speakerB).value(playing).toBool());
    QCOMPARE(demo.speakerState(speakerB).value(duration).toInt(), 4000);
    QVERIFY(demo.error().isEmpty());

    QVERIFY(session->setParameter(constant, value, 350.5));
    QSignalSpy speakerChanges(&demo, &DemoGraph::speakerStateChanged);
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(!demo.error().isEmpty());
    QCOMPARE(demo.errorNodeId(), call);
    QVERIFY(speakerChanges.isEmpty());
    QVERIFY(!demo.speakerState(speakerB).value(playing).toBool());
    QCOMPARE(demo.speakerState(speakerA).value(duration).toInt(), 350);

    session->disconnectInput(call, input);
    QVERIFY(demo.run(trigger));
    QTRY_COMPARE(demo.speakerState(speakerA).value(duration).toInt(), 250);
    QTRY_COMPARE(demo.previewValues().value(result).toString(), QStringLiteral("250"));
    QCOMPARE(demo.speakerState(speakerB).value(duration).toInt(), 4000);
    QVERIFY(demo.error().isEmpty());
    session->disconnectInput(result, value);
    QVERIFY(!demo.previewValues().contains(result));
}

void BlueprintHistoryTest::executionResultsFlowThroughCalculations()
{
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);
    const auto speakerA = QStringLiteral("host:demo.speaker:speaker-a");
    const auto speakerB = QStringLiteral("host:demo.speaker:speaker-b");
    const auto input = QStringLiteral("in/demo.speaker/playFor/testDurationMs");
    const auto output = QStringLiteral("out/demo.speaker/playFor/playedDurationMs");
    const auto value = QStringLiteral("value");
    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto otherTrigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto call = demo.addOperation(QStringLiteral("demo.call"), speakerA, QStringLiteral("playFor"), {});
    const auto otherCall = demo.addOperation(QStringLiteral("demo.call"), speakerB, QStringLiteral("playFor"), {});
    const auto constant = session->addNode(QStringLiteral("demo.constant"), {});
    const auto addition = session->addNode(QStringLiteral("demo.add"), {});
    const auto direct = session->addNode(QStringLiteral("demo.result"), {});
    const auto result = session->addNode(QStringLiteral("demo.result"), {});
    const auto mixed = session->addNode(QStringLiteral("demo.add"), {});
    const auto mixedResult = session->addNode(QStringLiteral("demo.result"), {});
    QVERIFY(demo.setCallInput(call, input, QStringLiteral("200")));
    QVERIFY(demo.setCallInput(otherCall, input, QStringLiteral("300")));
    QVERIFY(session->setParameter(constant, value, 12.0));
    QVERIFY(session->connectPorts(trigger, QStringLiteral("execOut"), call, QStringLiteral("execIn")));
    QVERIFY(session->connectPorts(otherTrigger, QStringLiteral("execOut"), otherCall, QStringLiteral("execIn")));
    QVERIFY(session->connectPorts(call, output, direct, value));
    QVERIFY(session->connectPorts(call, output, addition, QStringLiteral("A")));
    QVERIFY(session->connectPorts(constant, value, addition, QStringLiteral("B")));
    QVERIFY(session->connectPorts(addition, value, result, value));
    QVERIFY(session->connectPorts(call, output, mixed, QStringLiteral("A")));
    QVERIFY(session->connectPorts(otherCall, output, mixed, QStringLiteral("B")));
    QVERIFY(session->connectPorts(mixed, value, mixedResult, value));

    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(!demo.running());
    QCOMPARE(demo.previewValues().value(direct).toString(), QStringLiteral("200"));
    QCOMPARE(demo.previewValues().value(addition).toString(), QStringLiteral("212"));
    QCOMPARE(demo.previewValues().value(result).toString(), QStringLiteral("212"));
    QVERIFY(!demo.previewValues().contains(mixedResult));

    // 后一次执行不能取用前一次的接口结果，但已展示的独立结果仍保留。
    QVERIFY(demo.run(otherTrigger));
    QTRY_VERIFY(!demo.running());
    QCOMPARE(demo.previewValues().value(result).toString(), QStringLiteral("212"));
    QVERIFY(!demo.previewValues().contains(mixed));
    QVERIFY(!demo.previewValues().contains(mixedResult));

    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(demo.speakerState(speakerA).value(QStringLiteral("playing")).toBool());
    QVERIFY(session->setParameter(constant, value, 13.0));
    QVERIFY(!demo.previewValues().contains(result));
    QTRY_VERIFY(!demo.running());
    QVERIFY(!demo.previewValues().contains(direct));
    QVERIFY(!demo.previewValues().contains(addition));
    QVERIFY(!demo.previewValues().contains(result));
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(!demo.running());
    QCOMPARE(demo.previewValues().value(direct).toString(), QStringLiteral("200"));
    QCOMPARE(demo.previewValues().value(result).toString(), QStringLiteral("213"));
    QVERIFY(demo.error().isEmpty());
}

void BlueprintHistoryTest::dispatchesPlaybackToBothSpeakers()
{
    bool playedTogether = false;
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    for (const auto &group : demo.palette()) {
        for (const auto &node : group.toMap().value(QStringLiteral("nodes")).toList())
            QVERIFY(node.toMap().value(QStringLiteral("type")).toString() != QStringLiteral("demo.fork"));
    }

    const auto speakerA = QStringLiteral("host:demo.speaker:speaker-a");
    const auto speakerB = QStringLiteral("host:demo.speaker:speaker-b");
    const auto playing = QStringLiteral("playing");
    const auto execute = QStringLiteral("execIn");
    const auto callType = QStringLiteral("demo.call");
    const auto playFor = QStringLiteral("playFor");
    const auto duration = QStringLiteral("in/demo.speaker/playFor/testDurationMs");
    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto wait = session->addNode(QStringLiteral("demo.wait"), {});
    const auto first = demo.addOperation(callType, speakerA, playFor, {});
    const auto second = demo.addOperation(callType, speakerB, playFor, {});
    QVERIFY(demo.setCallInput(first, duration, QStringLiteral("350")));
    QVERIFY(demo.setCallInput(second, duration, QStringLiteral("550")));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("0")));
    QVERIFY(session->connectPorts(trigger, QStringLiteral("execOut"), wait, execute));
    QVERIFY(session->connectPorts(wait, QStringLiteral("execOut"), first, execute));
    QVERIFY(session->connectPorts(wait, QStringLiteral("execOut"), second, execute));

    connect(&demo, &DemoGraph::speakerStateChanged, this,
            [&demo, &playedTogether, speakerA, speakerB, playing](const QString &) {
        playedTogether |= demo.speakerState(speakerA).value(playing).toBool()
            && demo.speakerState(speakerB).value(playing).toBool();
    });
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(playedTogether);
    QTRY_VERIFY(!demo.speakerState(speakerA).value(playing).toBool()
                && !demo.speakerState(speakerB).value(playing).toBool());
    QVERIFY(demo.error().isEmpty());
}

void BlueprintHistoryTest::queuesPlaybackFromMultipleExecutionInputs()
{
    QVector<bool> playbackStates;
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto speaker = QStringLiteral("host:demo.speaker:speaker-a");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto secondPath = session->addNode(QStringLiteral("demo.wait"), {});
    const auto playback = demo.addOperation(QStringLiteral("demo.call"), speaker, QStringLiteral("playFor"), {});
    QVERIFY(demo.setWaitDuration(secondPath, QStringLiteral("0")));
    QVERIFY(demo.setCallInput(playback, QStringLiteral("in/demo.speaker/playFor/testDurationMs"), QStringLiteral("150")));
    QVERIFY(session->connectPorts(trigger, execOut, playback, execIn));
    QVERIFY(session->connectPorts(trigger, execOut, secondPath, execIn));
    QVERIFY(session->connectPorts(secondPath, execOut, playback, execIn));

    connect(&demo, &DemoGraph::speakerStateChanged, this, [&](const QString &target) {
        if (target == speaker)
            playbackStates.append(demo.speakerState(speaker).value(QStringLiteral("playing")).toBool());
    });
    QVERIFY(demo.run(trigger));
    const QVector<bool> expected{true, false, true, false};
    QTRY_COMPARE(playbackStates, expected);
    QTRY_VERIFY(!demo.running());
    QVERIFY(demo.error().isEmpty());
}

void BlueprintHistoryTest::waitsFromArrivalAndStops()
{
    QElapsedTimer clock;
    bool played = false;
    qint64 playbackEndedAt = -1;
    qint64 propertySetAt = -1;
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto speakerA = QStringLiteral("host:demo.speaker:speaker-a");
    const auto speakerB = QStringLiteral("host:demo.speaker:speaker-b");
    const auto playing = QStringLiteral("playing");
    const auto testDuration = QStringLiteral("testDurationMs");
    const auto duration = QStringLiteral("durationMs");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto value = QStringLiteral("value");
    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto playback = demo.addOperation(QStringLiteral("demo.call"), speakerA, QStringLiteral("playFor"), {});
    const auto wait = session->addNode(QStringLiteral("demo.wait"), {});
    const auto constant = session->addNode(QStringLiteral("demo.constant"), {});
    const auto setter = demo.addOperation(QStringLiteral("demo.setProperty"), speakerB, testDuration, {});
    QVERIFY(demo.setCallInput(playback, QStringLiteral("in/demo.speaker/playFor/testDurationMs"), QStringLiteral("200")));
    QVERIFY(!demo.setWaitDuration(wait, QStringLiteral("-1")));
    QVERIFY(!demo.setWaitDuration(wait, QStringLiteral("1.5")));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("00:59.999")));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("01:59:59.999")));
    QVERIFY(!demo.setWaitDuration(wait, QStringLiteral("00:60.000")));
    QVERIFY(!demo.setWaitDuration(wait, QStringLiteral("00:99.000")));
    QVERIFY(!demo.setWaitDuration(wait, QStringLiteral("01:00:60.000")));
    QVERIFY(!demo.setWaitDuration(wait, QStringLiteral("00:9999")));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("0")));
    QVERIFY(session->setParameter(constant, value, 180.0));
    QVERIFY(demo.setDurationInput(setter, QStringLiteral("444")));
    QVERIFY(session->connectPorts(trigger, execOut, playback, execIn));
    QVERIFY(session->connectPorts(playback, QStringLiteral("out/demo.speaker/playFor/playedDurationMs"), wait, execIn));
    QVERIFY(session->connectPorts(constant, value, wait, duration));
    QVERIFY(session->connectPorts(wait, execOut, setter, execIn));

    connect(&demo, &DemoGraph::speakerStateChanged, this,
            [&, speakerA, speakerB, playing](const QString &target) {
        if (target == speakerA) {
            if (demo.speakerState(speakerA).value(playing).toBool())
                played = true;
            else if (played)
                playbackEndedAt = clock.elapsed();
        } else if (target == speakerB) {
            propertySetAt = clock.elapsed();
        }
    });
    clock.start();
    QVERIFY(demo.run(trigger));
    QTRY_COMPARE(demo.nodeStates().value(playback).toString(), QStringLiteral("running"));
    QTRY_COMPARE(demo.nodeStates().value(wait).toString(), QStringLiteral("waiting"));
    QTRY_VERIFY(propertySetAt >= 0);
    QVERIFY(playbackEndedAt >= 0);
    QVERIFY(propertySetAt - playbackEndedAt >= 160);
    QCOMPARE(demo.speakerState(speakerB).value(testDuration).toInt(), 444);
    QTRY_VERIFY(!demo.running());
    QVERIFY(demo.nodeStates().isEmpty());

    QVERIFY(session->setParameter(constant, value, 400.0));
    QVERIFY(demo.setDurationInput(setter, QStringLiteral("888")));
    played = false;
    playbackEndedAt = -1;
    propertySetAt = -1;
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(playbackEndedAt >= 0);
    QCoreApplication::processEvents();
    QVERIFY(demo.running());
    QCOMPARE(demo.nodeStates().value(wait).toString(), QStringLiteral("waiting"));
    demo.stop();
    QVERIFY(!demo.running());
    QVERIFY(demo.nodeStates().isEmpty());
    QTest::qWait(450);
    QCOMPARE(propertySetAt, qint64(-1));
    QCOMPARE(demo.speakerState(speakerB).value(testDuration).toInt(), 444);
}

void BlueprintHistoryTest::waitsFromAutomaticEntry()
{
    QElapsedTimer clock;
    qint64 playbackEndedAt = -1;
    qint64 propertySetAt = -1;
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto speakerA = QStringLiteral("host:demo.speaker:speaker-a");
    const auto speakerB = QStringLiteral("host:demo.speaker:speaker-b");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto startType = QStringLiteral("demo.start");
    const auto waitUntilType = QStringLiteral("demo.waitUntil");
    QVERIFY(!demo.trigger());
    QVERIFY(!demo.error().isEmpty());
    QVERIFY(!demo.running());
    const auto start = session->placeNode(startType, {}, {});
    QVERIFY(!start.isEmpty());
    QCOMPARE(session->placeNode(startType, QPointF(100, 100), {}), start);
    QVERIFY(session->addNode(startType, {}).isEmpty());

    const auto playback = demo.addOperation(QStringLiteral("demo.call"), speakerA, QStringLiteral("playFor"), {});
    const auto wait = session->addNode(waitUntilType, {});
    const auto setter = demo.addOperation(QStringLiteral("demo.setProperty"), speakerB, QStringLiteral("testDurationMs"), {});
    QVERIFY(demo.setCallInput(playback, QStringLiteral("in/demo.speaker/playFor/testDurationMs"), QStringLiteral("400")));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("750")));
    QVERIFY(demo.setDurationInput(setter, QStringLiteral("444")));
    QVERIFY(session->connectPorts(start, execOut, playback, execIn));
    QVERIFY(session->connectPorts(playback, QStringLiteral("out/demo.speaker/playFor/playedDurationMs"), wait, execIn));
    QVERIFY(session->connectPorts(wait, execOut, setter, execIn));

    connect(&demo, &DemoGraph::speakerStateChanged, this, [&](const QString &target) {
        if (target == speakerA && !demo.speakerState(speakerA).value(QStringLiteral("playing")).toBool())
            playbackEndedAt = clock.elapsed();
        else if (target == speakerB)
            propertySetAt = clock.elapsed();
    });

    clock.start();
    QVERIFY(demo.trigger());
    QTRY_COMPARE(demo.nodeStates().value(wait).toString(), QStringLiteral("waiting"));
    QTRY_VERIFY(propertySetAt >= 0);
    QVERIFY(playbackEndedAt >= 0);
    QVERIFY(propertySetAt >= 730);
    QVERIFY(propertySetAt - playbackEndedAt < 600);
    QTRY_VERIFY(!demo.running());

    // 再次触发时从新的起点计时。
    QVERIFY(demo.setDurationInput(setter, QStringLiteral("555")));
    playbackEndedAt = -1;
    propertySetAt = -1;
    clock.restart();
    QVERIFY(demo.trigger());
    QTRY_VERIFY(propertySetAt >= 0);
    QVERIFY(propertySetAt >= 730);
    QTRY_VERIFY(!demo.running());

    // 到达时已超过目标时间则直接继续。
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("300")));
    QVERIFY(demo.setDurationInput(setter, QStringLiteral("666")));
    playbackEndedAt = -1;
    propertySetAt = -1;
    clock.restart();
    QVERIFY(demo.trigger());
    QTRY_VERIFY(propertySetAt >= 0);
    QVERIFY(playbackEndedAt >= 280);
    QVERIFY(propertySetAt >= playbackEndedAt);
    QVERIFY(propertySetAt - playbackEndedAt < 220);
    QTRY_VERIFY(!demo.running());

    // 手动执行不能使用仍在运行的自动流程的起点。
    const auto manual = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto manualWait = session->addNode(waitUntilType, {});
    QVERIFY(session->connectPorts(manual, execOut, manualWait, execIn));
    QVERIFY(demo.setWaitDuration(manualWait, QStringLiteral("0")));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("10000")));
    QVERIFY(demo.trigger());
    QVERIFY(demo.run(manual));
    QTRY_VERIFY(!demo.error().isEmpty());
    QCOMPARE(demo.errorNodeId(), manualWait);
    QVERIFY(demo.running());
    demo.stop();
    QVERIFY(!demo.running());
}

void BlueprintHistoryTest::recordsDeviceCommandsOnArrival()
{
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto commandType = QStringLiteral("demo.deviceCommand");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto deviceName = QStringLiteral("deviceName");
    const auto cmdName = QStringLiteral("cmdName");
    const auto simName = QStringLiteral("simName");
    const auto params = QStringLiteral("params");
    const auto elapsedMs = QStringLiteral("elapsedMs");
    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto command = session->addNode(commandType, {});
    const auto wait = session->addNode(QStringLiteral("demo.wait"), {});
    const auto delayedCommand = session->addNode(commandType, {});
    const QVariantMap configuration{
        {deviceName, QStringLiteral("音响服务器")},
        {cmdName, QStringLiteral("播放音频")},
        {simName, QStringLiteral("开场音乐")},
        {params, QStringLiteral(R"({"repeat":false})")}
    };
    QVERIFY(session->setParameters(command, configuration));
    QVERIFY(session->setParameters(delayedCommand, configuration));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("10000")));
    QVERIFY(session->connectPorts(trigger, execOut, command, execIn));
    QVERIFY(session->connectPorts(trigger, execOut, wait, execIn));
    QVERIFY(session->connectPorts(wait, execOut, delayedCommand, execIn));

    QVERIFY(demo.deviceCommandResults().isEmpty());
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(demo.deviceCommandResults().contains(command));
    QTRY_COMPARE(demo.nodeStates().value(wait).toString(), QStringLiteral("waiting"));
    const auto record = demo.deviceCommandResults().value(command).toMap();
    QCOMPARE(record.value(deviceName), configuration.value(deviceName));
    QCOMPARE(record.value(cmdName), configuration.value(cmdName));
    QCOMPARE(record.value(simName), configuration.value(simName));
    QCOMPARE(record.value(params).toMap(), (QVariantMap{{QStringLiteral("repeat"), false}}));
    bool hasElapsed = false;
    const auto elapsed = record.value(elapsedMs).toLongLong(&hasElapsed);
    QVERIFY(hasElapsed && elapsed >= 0);
    demo.stop();
    QVERIFY(!demo.running());
    QVERIFY(!demo.deviceCommandResults().contains(delayedCommand));

    session->disconnectInput(wait, execIn);
    QVERIFY(session->setParameter(command, params, QStringLiteral("[]")));
    QVERIFY(demo.run(trigger));
    QTRY_VERIFY(!demo.error().isEmpty());
    QCOMPARE(demo.errorNodeId(), command);
    QVERIFY(!demo.running());
}

void BlueprintHistoryTest::propertyEventsRunAlongsideManualWait()
{
    QVector<int> observedDurations;
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto speakerA = QStringLiteral("host:demo.speaker:speaker-a");
    const auto speakerB = QStringLiteral("host:demo.speaker:speaker-b");
    const auto playing = QStringLiteral("playing");
    const auto duration = QStringLiteral("testDurationMs");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto trigger = session->addNode(QStringLiteral("demo.trigger"), {});
    const auto wait = session->addNode(QStringLiteral("demo.wait"), {});
    const auto event = session->addNode(QStringLiteral("demo.propertyChanged"), {});
    const auto preview = session->addNode(QStringLiteral("demo.boolResult"), {});
    const auto inverse = session->addNode(QStringLiteral("demo.not"), {});
    const auto inversePreview = session->addNode(QStringLiteral("demo.boolResult"), {});
    const auto branch = session->addNode(QStringLiteral("demo.branch"), {});
    const auto first = demo.addOperation(QStringLiteral("demo.setProperty"), speakerB, duration, {});
    const auto second = demo.addOperation(QStringLiteral("demo.setProperty"), speakerB, duration, {});
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("10000")));
    QVERIFY(session->connectPorts(event, QStringLiteral("value"), branch, execIn));
    QVERIFY(!session->connectPorts(event, QStringLiteral("value"), branch, QStringLiteral("condition")));
    QVERIFY(demo.bindPropertyEvent(event, speakerA, playing));
    QVERIFY(demo.setDurationInput(first, QStringLiteral("700")));
    QVERIFY(demo.setDurationInput(second, QStringLiteral("800")));
    QVERIFY(session->connectPorts(trigger, execOut, wait, execIn));
    QVERIFY(session->connectPorts(event, QStringLiteral("value"), branch, QStringLiteral("condition")));
    QVERIFY(session->connectPorts(event, QStringLiteral("value"), preview, QStringLiteral("value")));
    QVERIFY(session->connectPorts(event, QStringLiteral("value"), inverse, QStringLiteral("A")));
    QVERIFY(session->connectPorts(inverse, QStringLiteral("value"), inversePreview, QStringLiteral("value")));
    QVERIFY(!demo.previewValues().contains(preview));
    QVERIFY(!demo.previewValues().contains(inversePreview));
    QVERIFY(session->connectPorts(branch, QStringLiteral("true"), first, execIn));
    QVERIFY(session->connectPorts(branch, QStringLiteral("false"), second, execIn));

    QTemporaryDir files;
    QVERIFY(files.isValid());
    const auto links = session->connections();
    const auto graphFile = QUrl::fromLocalFile(files.filePath(QStringLiteral("property-event.json")));
    QVERIFY(demo.save(graphFile));
    QVERIFY(demo.open(graphFile));
    QCOMPARE(session->connections(), links);

    connect(&demo, &DemoGraph::speakerStateChanged, this,
            [&, speakerB, duration](const QString &target) {
        if (target == speakerB)
            observedDurations.append(demo.speakerState(speakerB).value(duration).toInt());
    });
    QVERIFY(demo.run(trigger));
    QCoreApplication::processEvents();
    QVERIFY(demo.running());

    // 两次变化发生在同一次事件循环内，条件分支分别读取各次通知的值。
    QVERIFY(demo.invokeSpeaker(speakerA, QStringLiteral("playTest")));
    QVERIFY(demo.invokeSpeaker(speakerA, QStringLiteral("stop")));
    QTRY_COMPARE(observedDurations.size(), 2);
    QVERIFY(observedDurations.contains(700));
    QVERIFY(observedDurations.contains(800));
    QVERIFY(demo.running());
    QVERIFY(demo.error().isEmpty());
    QTRY_COMPARE(demo.previewValues().value(preview).toString(), QStringLiteral("否"));
    QCOMPARE(demo.previewValues().value(inverse).toString(), QStringLiteral("是"));
    QCOMPARE(demo.previewValues().value(inversePreview).toString(), QStringLiteral("是"));

    QVERIFY(demo.setDurationInput(second, QStringLiteral("900")));
    QVERIFY(demo.invokeSpeaker(speakerA, QStringLiteral("stop")));
    QTest::qWait(50);
    QCOMPARE(observedDurations.size(), 2);

    QVERIFY(demo.setDurationInput(first, QStringLiteral("1000")));
    QVERIFY(demo.invokeSpeaker(speakerA, QStringLiteral("playTest")));
    demo.stop();
    QTest::qWait(50);
    QVERIFY(!demo.running());
    QCOMPARE(observedDurations.size(), 2);
}

void BlueprintHistoryTest::tracksOverlappingPropertyEventStates()
{
    DemoGraph demo;
    auto *session = qobject_cast<GraphEditSession *>(demo.session());
    QVERIFY(session);

    const auto speaker = QStringLiteral("host:demo.speaker:speaker-a");
    const auto event = session->addNode(QStringLiteral("demo.propertyChanged"), {});
    const auto wait = session->addNode(QStringLiteral("demo.wait"), {});
    QVERIFY(demo.bindPropertyEvent(event, speaker, QStringLiteral("playing")));
    QVERIFY(demo.setWaitDuration(wait, QStringLiteral("500")));
    QVERIFY(session->connectPorts(event, QStringLiteral("value"), wait, QStringLiteral("execIn")));

    QVERIFY(demo.invokeSpeaker(speaker, QStringLiteral("playTest")));
    QTRY_COMPARE(demo.nodeStates().value(wait).toString(), QStringLiteral("waiting"));
    QTest::qWait(200);
    QSignalSpy states(&demo, &DemoGraph::nodeStatesChanged);
    QVERIFY(demo.invokeSpeaker(speaker, QStringLiteral("stop")));
    QTRY_COMPARE(states.count(), 1);
    QTRY_COMPARE(states.count(), 2);
    QCOMPARE(demo.nodeStates().value(wait).toString(), QStringLiteral("waiting"));
    QTRY_VERIFY(demo.nodeStates().isEmpty());
    QTRY_VERIFY(!demo.running());
    QVERIFY(demo.error().isEmpty());

    QVERIFY(demo.invokeSpeaker(speaker, QStringLiteral("playTest")));
    QTRY_COMPARE(demo.nodeStates().value(wait).toString(), QStringLiteral("waiting"));
    demo.stop();
    QVERIFY(demo.nodeStates().isEmpty());
    QVERIFY(!demo.running());
}

QTEST_GUILESS_MAIN(BlueprintHistoryTest)

#include "history_test.moc"
