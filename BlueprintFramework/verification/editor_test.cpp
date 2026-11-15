#include <Blueprint/GraphEditSession.h>

#include <QJSValue>
#include <QLineF>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlExpression>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtTest>

#include <algorithm>

using namespace Blueprint;

namespace {

QQuickItem *findItem(QQuickItem *root, const char *name, bool matchType = false)
{
    if (matchType ? root->isVisible() && root->inherits(name) : root->objectName() == QLatin1String(name))
        return root;
    for (QQuickItem *child : root->childItems()) {
        if (auto *found = findItem(child, name, matchType))
            return found;
    }
    return nullptr;
}

class EditorTest : public QObject
{
    Q_OBJECT

private slots:
    void sharedEditorInteractions();
    void compoundPortsAndDisplay();
    void longLabelsStayInsideCards();
    void graphChangesRefitViewport();
};

void EditorTest::sharedEditorInteractions()
{
    NodeRegistry registry;
    NodeTypeDefinition source;
    source.typeId = QStringLiteral("source");
    source.displayName = QStringLiteral("Source");
    source.ports = {{QStringLiteral("out"), PortDirection::Output, QStringLiteral("number")},
                    {QStringLiteral("next"), PortDirection::Output, {}, {}, PortKind::Execution}};
    ParameterDefinition value;
    value.key = QStringLiteral("value");
    value.valueTypeId = QStringLiteral("number");
    value.defaultValue = 2.0;
    value.minimum = 0.0;
    value.maximum = 10.0;
    source.parameters = {value,
        {QStringLiteral("portMode"), QStringLiteral("string"), QStringLiteral("output"),
         {QStringLiteral("output"), QStringLiteral("input"), QStringLiteral("hidden")}}};
    source.resolvePorts = [ports = source.ports](const NodeData &node) {
        auto resolved = ports;
        const auto mode = node.parameterOverrides.value(QStringLiteral("portMode"), QStringLiteral("output")).toString();
        if (mode == QStringLiteral("hidden"))
            resolved.removeFirst();
        else if (mode == QStringLiteral("input"))
            resolved.first().direction = PortDirection::Input;
        return resolved;
    };
    auto otherSourceType = source;
    otherSourceType.typeId = QStringLiteral("other-source");
    NodeTypeDefinition target;
    target.typeId = QStringLiteral("target");
    target.displayName = QStringLiteral("Target");
    target.ports = {{QStringLiteral("in"), PortDirection::Input, QStringLiteral("number")},
                    {QStringLiteral("run"), PortDirection::Input, {}, {}, PortKind::Execution}};
    auto alternate = target;
    alternate.typeId = QStringLiteral("alternate");
    auto spare = target;
    spare.typeId = QStringLiteral("spare");
    NodeTypeDefinition cover;
    cover.typeId = QStringLiteral("cover");
    cover.displayName = QStringLiteral("Cover");
    for (const auto &definition : {source, otherSourceType, target, alternate, spare, cover})
        QVERIFY(registry.add(definition).code.isEmpty());

    GraphDocument document(registry);
    GraphEditSession session(document);
    const auto sourceId = document.addNode(source.typeId, {120, 60}).id;
    const auto targetId = document.addNode(target.typeId, {360, 120}).id;
    const Endpoint output{sourceId, QStringLiteral("out")};
    const Endpoint input{targetId, QStringLiteral("in")};
    const auto line = document.connectPorts(output, input);
    QVERIFY(line.error.code.isEmpty());

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("testSession"), &session);
    engine.loadData(R"QML(
        import QtQuick 2.14
        import QtQuick.Window 2.14
        import "qrc:/BlueprintQuick" as Blueprint
        Window {
            id: testWindow
            property bool customHeaders: false
            Component {
                id: customHeader
                Item {
                    objectName: "customNodeHeader"
                    property var node
                    readonly property string boundNodeId: node ? node.id : ""
                    readonly property real boundValue: node ? node.parameters.value : 0
                    implicitHeight: 40 + boundValue * 4
                    Text {
                        anchors.centerIn: parent
                        text: parent.boundNodeId
                    }
                }
            }
            width: 1100
            height: 700
            visible: true
            QtObject {
                id: theme
                property color backgroundCanvas: "#141516"
                property color backgroundSurface: "#303234"
                property color borderPane: "#353638"
                property color border: "#a9b4bd"
                property color text: "#e1e2e3"
                property color subtleText: "#a9b4bd"
                property color highlightSoft: "#334455"
                property color highlightText: "#7aaddf"
                property color successText: "#75a76f"
                property color infoText: "#608ac5"
                property color dangerText: "#f17575"
            }
            Blueprint.GraphEditor {
                objectName: "firstEditor"
                session: testSession
                nodeHeaders: testWindow.customHeaders ? ({"other-source": customHeader}) : ({})
                colors: theme
                width: parent.width
                height: parent.height / 2
            }
            Blueprint.GraphEditor {
                objectName: "secondEditor"
                colors: theme
                palettePanel: null
                inspectorPanel: null
                y: parent.height / 2
                width: parent.width
                height: 0
            }
        }
    )QML", QUrl(QStringLiteral("qrc:/BlueprintEditorTest.qml")));
    QCOMPARE(engine.rootObjects().size(), 1);
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    QVERIFY(window);
    QVERIFY(QTest::qWaitForWindowExposed(window));
    auto *first = findItem(window->contentItem(), "firstEditor");
    auto *second = findItem(window->contentItem(), "secondEditor");
    QVERIFY(first && second);
    auto *canvas = findItem(first, "graphCanvas");
    auto *lateCanvas = findItem(second, "graphCanvas");
    auto *sourceCard = findItem(first, "node-source");
    auto *targetCard = findItem(first, "node-target");
    QVERIFY(canvas && lateCanvas && sourceCard && targetCard);

    QTRY_COMPARE(canvas->size(), QSizeF(680, 350));
    QTRY_COMPARE(canvas->property("pan").toPointF(), QPointF(6, 33));
    second->setProperty("session", QVariant::fromValue(static_cast<QObject *>(&session)));
    QTRY_COMPARE(lateCanvas->property("nodeCount").toInt(), 2);
    QCOMPARE(lateCanvas->height(), 0.0);
    second->setHeight(350);
    QTRY_COMPARE(lateCanvas->property("pan").toPointF(), QPointF(216, 33));
    window->setWidth(1120);
    QTRY_COMPARE(canvas->width(), 700.0);
    QCOMPARE(canvas->property("pan").toPointF(), QPointF(6, 33));
    QCOMPARE(lateCanvas->property("pan").toPointF(), QPointF(216, 33));

    first->setProperty("selectedNodeId", sourceId.toString(QUuid::WithoutBraces));
    QQuickItem *field = nullptr;
    QTRY_VERIFY((field = findItem(first, "QQuickTextField", true)));
    field->forceActiveFocus();
    QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
    QTest::keyClick(window, Qt::Key_9);
    QTest::keyClick(window, Qt::Key_9);
    QTest::keyClick(window, Qt::Key_Return);
    QTRY_VERIFY(!session.error().isEmpty());
    QCOMPARE(document.parameterValue(sourceId, value.key).toDouble(), 2.0);
    QCOMPARE(field->property("text").toString(), QStringLiteral("2"));
    const auto fieldItems = field->parentItem()->parentItem()->childItems();
    QVERIFY(std::any_of(fieldItems.cbegin(), fieldItems.cend(), [&](const QQuickItem *item) {
        return item->isVisible() && item->property("text").toString() == session.error();
    }));
    QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
    QTest::keyClick(window, Qt::Key_3);
    QTest::keyClick(window, Qt::Key_Return);
    QTRY_COMPARE(document.parameterValue(sourceId, value.key).toDouble(), 3.0);
    QCOMPARE(field->property("text").toString(), QStringLiteral("3"));
    QVERIFY(session.error().isEmpty());

    canvas->setProperty("pan", QPointF(50, 40));
    const auto alternateId = document.addNode(alternate.typeId, {canvas->width() - 42, 160}).id;
    auto *alternateCard = findItem(first, "node-alternate");
    QVERIFY(alternateCard);
    const auto *inputHit = findItem(targetCard, "input-in");
    const auto *alternateHit = findItem(alternateCard, "input-in");
    QVERIFY(inputHit && alternateHit);
    const auto centerInScene = [](const QQuickItem *item) {
        return item->mapToScene({item->width() / 2, item->height() / 2}).toPoint();
    };
    const QPoint start = centerInScene(inputHit);
    const QPoint outside = centerInScene(alternateHit);
    QVERIFY(!canvas->contains(canvas->mapFromScene(outside)));
    const auto drag = [&](const QPoint &end) {
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, start);
        QTest::mouseMove(window, end);
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, end);
    };

    auto revision = document.revision();
    drag(outside);
    QTRY_VERIFY(!first->property("connecting").toBool());
    QCOMPARE(document.revision(), revision);
    QCOMPARE(document.data().connections.first().id, line.id);
    QCOMPARE(document.data().connections.first().target.nodeId, targetId);
    drag(outside - QPoint(10, 0));
    QCOMPARE(document.revision(), revision);

    QVERIFY(document.moveNode(alternateId, {500, 160}).error.code.isEmpty());
    const auto coverId = document.addNode(cover.typeId, {485, 192}).id;
    QVERIFY(!coverId.isNull());
    const QPoint visible = centerInScene(alternateHit);
    revision = document.revision();
    drag(visible);
    QCOMPARE(document.revision(), revision);
    QVERIFY(document.removeNode(coverId).error.code.isEmpty());
    drag(visible);
    QTRY_COMPARE(document.data().connections.size(), 1);
    QCOMPARE(document.data().connections.first().id, line.id);
    QCOMPARE(document.data().connections.first().target.nodeId, alternateId);

    QVERIFY(document.moveNode(targetId, {340, 5}).error.code.isEmpty());
    QVERIFY(document.moveNode(alternateId, {340, 110}).error.code.isEmpty());
    const auto spareId = document.addNode(spare.typeId, {340, 215}).id;
    auto *spareCard = findItem(first, "node-spare");
    QVERIFY(spareCard);
    const auto *executionOut = findItem(sourceCard, "output-next");
    const auto *firstExecutionIn = findItem(targetCard, "input-run");
    const auto *secondExecutionIn = findItem(alternateCard, "input-run");
    const auto *spareExecutionIn = findItem(spareCard, "input-run");
    QVERIFY(executionOut && firstExecutionIn && secondExecutionIn && spareExecutionIn);

    const QPoint origin = centerInScene(executionOut);
    const QPoint firstBranch = centerInScene(firstExecutionIn);
    const QPoint secondBranch = centerInScene(secondExecutionIn);
    const QPoint spareBranch = centerInScene(spareExecutionIn);
    const auto *outputLabel = findItem(executionOut->parentItem(), "QQuickText", true);
    const auto *inputLabel = findItem(firstExecutionIn->parentItem(), "QQuickText", true);
    QVERIFY(outputLabel && inputLabel);
    const QPoint outputText = centerInScene(outputLabel);
    const QPoint inputText = centerInScene(inputLabel);
    const QPoint inputTextEdge = inputLabel->mapToScene({1, inputLabel->height() / 2}).toPoint();

    revision = document.revision();
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, outputText);
    QVERIFY(!first->property("connecting").toBool());
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, origin);
    QVERIFY(first->property("connecting").toBool());
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, inputText);
    QCOMPARE(document.revision(), revision);
    QTest::keyClick(window, Qt::Key_Escape);

    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, origin);
    QTest::mouseMove(window, inputTextEdge);
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, inputTextEdge);
    QCOMPARE(document.revision(), revision);

    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, origin + QPoint(2, 0));
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, firstBranch - QPoint(2, 0));
    QTRY_COMPARE(document.data().connections.size(), 2);
    const auto firstBranchId = document.data().connections.at(1).id;

    QTest::mouseClick(window, Qt::RightButton, Qt::NoModifier, inputText);
    QVERIFY(canvas->property("selectedConnectionId").toString().isEmpty());
    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, inputText);
    QTest::mouseMove(window, spareBranch);
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, spareBranch);
    QCOMPARE(document.data().connections.at(1).target.nodeId, targetId);

    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, origin);
    QTest::mouseMove(window, secondBranch);
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, secondBranch);
    QTRY_COMPARE(document.data().connections.size(), 3);
    const auto secondBranchId = document.data().connections.at(2).id;
    QCOMPARE(document.data().connections.at(1).target.nodeId, targetId);
    QCOMPARE(document.data().connections.at(2).target.nodeId, alternateId);

    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, firstBranch);
    QTest::mouseMove(window, spareBranch);
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, spareBranch);
    QTRY_COMPARE(document.data().connections.at(1).target.nodeId, spareId);
    QCOMPARE(document.data().connections.at(1).id, firstBranchId);
    QCOMPARE(document.data().connections.at(2).id, secondBranchId);
    QCOMPARE(document.data().connections.at(2).target.nodeId, alternateId);
    QCOMPARE(document.data().connections.at(2).source.nodeId, sourceId);

    const auto otherSourceId = document.addNode(otherSourceType.typeId, {120, 170}).id;
    auto *otherSourceCard = findItem(first, "node-other-source");
    QVERIFY(otherSourceCard);
    const auto *otherOutput = findItem(otherSourceCard, "output-next");
    QVERIFY(otherOutput);
    const QPoint otherOrigin = centerInScene(otherOutput);

    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, otherOrigin);
    QTest::mouseMove(window, spareBranch);
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, spareBranch);
    QTRY_COMPARE(document.data().connections.size(), 4);
    const auto incomingId = document.data().connections.at(3).id;
    QCOMPARE(document.data().connections.at(1).id, firstBranchId);
    QCOMPARE(document.data().connections.at(1).target.nodeId, spareId);
    QCOMPARE(document.data().connections.at(3).target.nodeId, spareId);
    QCOMPARE(document.data().connections.at(3).source.nodeId, otherSourceId);

    QTest::mouseClick(window, Qt::RightButton, Qt::NoModifier, spareBranch);
    QVERIFY(canvas->property("selectedConnectionId").toString().isEmpty());
    session.disconnectInput(spareId.toString(QUuid::WithoutBraces), QStringLiteral("run"));
    QCOMPARE(document.data().connections.size(), 4);

    GraphDocument restored(registry);
    QVERIFY(restored.replaceData(document.data()).code.isEmpty());
    QCOMPARE(restored.data().connections.size(), 4);
    QCOMPARE(restored.canConnect({otherSourceId, QStringLiteral("next")}, {spareId, QStringLiteral("run")}).code,
             QStringLiteral("graph.duplicate_connection"));
    QCOMPARE(restored.canConnect({otherSourceId, QStringLiteral("out")}, {alternateId, QStringLiteral("in")}).code,
             QStringLiteral("graph.input_occupied"));

    const QPoint firstWire = (origin + spareBranch) / 2;
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, firstWire);
    QTRY_COMPARE(canvas->property("selectedConnectionId").toString(), firstBranchId.toString(QUuid::WithoutBraces));
    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, spareBranch);
    QTest::mouseMove(window, firstBranch);
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, firstBranch);
    QTRY_COMPARE(document.data().connections.at(1).target.nodeId, targetId);
    QCOMPARE(document.data().connections.at(1).id, firstBranchId);
    QCOMPARE(document.data().connections.at(3).id, incomingId);
    QCOMPARE(document.data().connections.at(3).target.nodeId, spareId);

    const QPoint otherWire = (otherOrigin + spareBranch) / 2;
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, otherWire);
    QTRY_COMPARE(canvas->property("selectedConnectionId").toString(), incomingId.toString(QUuid::WithoutBraces));
    QTest::keyClick(window, Qt::Key_Delete);
    QTRY_COMPARE(document.data().connections.size(), 3);
    QCOMPARE(document.data().connections.at(1).id, firstBranchId);
    QCOMPARE(document.data().connections.at(2).id, secondBranchId);

    canvas->setProperty("zoom", 0.65);
    const QPoint zoomedOutput = centerInScene(otherOutput);
    const QPoint zoomedInput = centerInScene(spareExecutionIn);
    const auto *spareLabel = findItem(spareExecutionIn->parentItem(), "QQuickText", true);
    QVERIFY(spareLabel);
    const QPoint zoomedLabelEdge = spareLabel->mapToScene({1, spareLabel->height() / 2}).toPoint();
    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, zoomedOutput);
    QTest::mouseMove(window, zoomedLabelEdge);
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, zoomedLabelEdge);
    QCOMPARE(document.data().connections.size(), 3);
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, zoomedOutput);
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, zoomedInput);
    QTRY_COMPARE(document.data().connections.size(), 4);
    QCOMPARE(document.data().connections.last().target.nodeId, spareId);

    auto *wireLayer = findItem(first, "connectionLayer");
    QVERIFY(wireLayer);
    const auto otherSourceKey = otherSourceId.toString(QUuid::WithoutBraces);
    const auto connectionCount = document.data().connections.size();
    for (const bool output : {true, false}) {
        for (const bool remove : {true, false}) {
            QVERIFY(session.setParameter(otherSourceKey, QStringLiteral("portMode"),
                                         output ? QStringLiteral("output") : QStringLiteral("input")));
            QQuickItem *port = nullptr;
            QTRY_VERIFY((port = findItem(otherSourceCard, output ? "output-out" : "input-out")));
            QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, centerInScene(port));
            QCOMPARE(canvas->property("pendingNode").toString(), otherSourceKey);
            QVERIFY(first->property("connecting").toBool());
            QVERIFY(session.setParameter(otherSourceKey, value.key, output ? 4.0 : 5.0));
            QVERIFY(first->property("connecting").toBool());

            QVERIFY(session.setParameter(otherSourceKey, QStringLiteral("portMode"),
                remove ? QStringLiteral("hidden") : (output ? QStringLiteral("input") : QStringLiteral("output"))));
            QVERIFY(!first->property("connecting").toBool());
            QVERIFY(canvas->property("pendingNode").toString().isEmpty());
            QTRY_VERIFY(wireLayer->property("draftStart").isNull());
            QVERIFY(session.error().isEmpty());
            QCOMPARE(document.data().connections.size(), connectionCount);
        }
    }
    QQuickItem *retainedOutput = nullptr;
    QTRY_VERIFY((retainedOutput = findItem(otherSourceCard, "output-next")));
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, centerInScene(retainedOutput));
    QVERIFY(session.setParameter(otherSourceKey, QStringLiteral("portMode"), QStringLiteral("hidden")));
    QVERIFY(first->property("connecting").toBool());
    QCOMPARE(canvas->property("pendingPort").toString(), QStringLiteral("next"));
    QTest::keyClick(window, Qt::Key_Escape);
    QVERIFY(!first->property("connecting").toBool());

    QVERIFY(session.setParameter(otherSourceKey, QStringLiteral("portMode"), QStringLiteral("output")));
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, centerInScene(inputHit));
    QCOMPARE(canvas->property("pendingNode").toString(), targetId.toString(QUuid::WithoutBraces));
    QVERIFY(first->property("connecting").toBool());
    QQuickItem *restoredOutput = nullptr;
    QTRY_VERIFY((restoredOutput = findItem(otherSourceCard, "output-out")));
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, centerInScene(restoredOutput));
    QTRY_COMPARE(document.data().connections.size(), connectionCount + 1);
    QCOMPARE(document.data().connections.last().source.nodeId, otherSourceId);
    QCOMPARE(document.data().connections.last().target.nodeId, targetId);
    QVERIFY(session.error().isEmpty());
    QVERIFY(!first->property("connecting").toBool());

    canvas->setProperty("zoom", 1.0);
    QVERIFY(session.setParameter(otherSourceKey, value.key, 4.0));
    QCOMPARE(otherSourceCard->property("headerHeight").toInt(), 38);
    window->setProperty("customHeaders", true);
    QQuickItem *customHeader = nullptr;
    QTRY_VERIFY((customHeader = findItem(otherSourceCard, "customNodeHeader")));
    QTRY_COMPARE(customHeader->property("boundNodeId").toString(), otherSourceKey);
    QCOMPARE(customHeader->property("boundValue").toDouble(), 4.0);
    const auto originalHeight = otherSourceCard->height();
    const auto originalPortY = restoredOutput->mapToItem(otherSourceCard, {0, 0}).y();
    QVERIFY(session.setParameter(otherSourceKey, value.key, 7.0));
    QTRY_COMPARE(customHeader->property("boundValue").toDouble(), 7.0);
    QTRY_COMPARE(otherSourceCard->height(), originalHeight + 12.0);
    QCOMPARE(restoredOutput->mapToItem(otherSourceCard, {0, 0}).y(), originalPortY + 12.0);
    QCOMPARE(sourceCard->property("headerHeight").toInt(), 38);

    first->setProperty("selectedNodeId", sourceId.toString(QUuid::WithoutBraces));
    const QPoint headerCenter = centerInScene(customHeader);
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, headerCenter);
    QCOMPARE(first->property("selectedNodeId").toString(), otherSourceKey);
    const auto originalPosition = otherSourceCard->property("graphPosition").toPointF();
    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, headerCenter);
    QTest::mouseMove(window, headerCenter + QPoint(20, 0));
    QTest::mouseMove(window, headerCenter + QPoint(60, 12));
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, headerCenter + QPoint(60, 12));
    QTRY_COMPARE(otherSourceCard->property("graphPosition").toPointF(), originalPosition + QPointF(40, 12));

    window->setProperty("customHeaders", false);
    QTRY_VERIFY(!findItem(otherSourceCard, "customNodeHeader"));
    QCOMPARE(otherSourceCard->property("headerHeight").toInt(), 38);
}

void EditorTest::compoundPortsAndDisplay()
{
    NodeRegistry registry;
    NodeTypeDefinition source;
    source.typeId = QStringLiteral("compound");
    source.displayName = QStringLiteral("Combined source");
    source.ports = {{QStringLiteral("value"), PortDirection::Output, QStringLiteral("number"),
                     QStringLiteral("Result"), PortKind::DataAndExecution}};
    QVERIFY(registry.add(source).code.isEmpty());
    NodeTypeDefinition target;
    target.typeId = QStringLiteral("consumer");
    target.displayName = QStringLiteral("Consumer");
    target.ports = {{QStringLiteral("local"), PortDirection::Input, QStringLiteral("number"), QStringLiteral("Local")},
                    {QStringLiteral("run"), PortDirection::Input, {}, QStringLiteral("Run"), PortKind::Execution}};
    QVERIFY(registry.add(target).code.isEmpty());
    GraphDocument document(registry);
    GraphEditSession session(document);
    const auto sourceId = document.addNode(source.typeId, {40, 40}).id;
    const auto targetId = document.addNode(target.typeId, {360, 40}).id;
    const auto sourceKey = sourceId.toString(QUuid::WithoutBraces);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("testSession"), &session);
    engine.loadData(R"QML(
        import QtQuick 2.14
        import QtQuick.Window 2.14
        import "qrc:/BlueprintQuick" as Blueprint
        Window {
            width: 800
            height: 450
            visible: true
            QtObject {
                id: theme
                property color backgroundCanvas: "#141516"
                property color backgroundSurface: "#303234"
                property color borderPane: "#353638"
                property color border: "#a9b4bd"
                property color text: "#e1e2e3"
                property color subtleText: "#a9b4bd"
                property color highlightSoft: "#334455"
                property color highlightText: "#7aaddf"
                property color successText: "#75a76f"
                property color infoText: "#608ac5"
                property color dangerText: "#f17575"
            }
            Blueprint.GraphEditor {
                objectName: "editor"
                anchors.fill: parent
                session: testSession
                colors: theme
                palettePanel: null
                inspectorPanel: null
            }
        }
    )QML", QUrl(QStringLiteral("qrc:/BlueprintCompoundEditorTest.qml")));
    QCOMPARE(engine.rootObjects().size(), 1);
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    QVERIFY(window);
    QVERIFY(QTest::qWaitForWindowExposed(window));
    auto *editor = findItem(window->contentItem(), "editor");
    QVERIFY(editor);
    auto *sourceCard = findItem(editor, "node-compound");
    auto *targetCard = findItem(editor, "node-consumer");
    auto *canvas = findItem(editor, "graphCanvas");
    auto *wireLayer = findItem(editor, "connectionLayer");
    QVERIFY(editor && sourceCard && targetCard && canvas && wireLayer);
    auto *output = findItem(sourceCard, "output-value");
    auto *dataInput = findItem(targetCard, "input-local");
    auto *executionInput = findItem(targetCard, "input-run");
    auto *graphic = findItem(sourceCard, "outputGraphic-value");
    QVERIFY(output && dataInput && executionInput && graphic);
    QVERIFY(output->parentItem()->property("compound").toBool());
    QCOMPARE(graphic->rotation(), 45.0);
    const auto projectedOutput = session.data(session.index(0, 0), session.roleNames().key("outputPorts")).toList().first().toMap();
    QVERIFY(projectedOutput.value(QStringLiteral("data")).toBool());
    QVERIFY(projectedOutput.value(QStringLiteral("executionCapable")).toBool());
    QVERIFY(!projectedOutput.value(QStringLiteral("execution")).toBool());

    const auto originalHeight = sourceCard->height();
    const auto originalPortPosition = output->mapToItem(sourceCard, {output->width() / 2, output->height() / 2});
    editor->setProperty("nodeStates", QVariantMap{{sourceKey, QStringLiteral("running")}});
    QTRY_COMPARE(sourceCard->property("statusText").toString(), QStringLiteral("执行中"));
    QCOMPARE(sourceCard->height(), originalHeight + 17.0);
    QCOMPARE(output->mapToItem(sourceCard, {output->width() / 2, output->height() / 2}), originalPortPosition);
    editor->setProperty("nodeStates", QVariantMap{{sourceKey, QStringLiteral("waiting")}});
    QTRY_COMPARE(sourceCard->property("statusText").toString(), QStringLiteral("等待中"));
    QCOMPARE(output->mapToItem(sourceCard, {output->width() / 2, output->height() / 2}), originalPortPosition);
    editor->setProperty("nodeStates", QVariantMap{{sourceKey, QStringLiteral("failed")}});
    QTRY_COMPARE(sourceCard->property("statusText").toString(), QStringLiteral("执行失败"));
    QCOMPARE(output->mapToItem(sourceCard, {output->width() / 2, output->height() / 2}), originalPortPosition);
    editor->setProperty("nodeStates", QVariantMap{});
    QTRY_VERIFY(sourceCard->property("statusText").toString().isEmpty());
    QCOMPARE(sourceCard->height(), originalHeight);

    QTRY_VERIFY(!canvas->property("initialFitPending").toBool());
    const QPoint outputPoint = output->mapToScene({output->width() / 2, output->height() / 2}).toPoint();
    const QPoint dataPoint = dataInput->mapToScene({dataInput->width() / 2, dataInput->height() / 2}).toPoint();
    const QPoint executionPoint = executionInput->mapToScene({executionInput->width() / 2, executionInput->height() / 2}).toPoint();
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, outputPoint);
    QTRY_VERIFY(editor->property("connecting").toBool());
    QTest::mouseMove(window, dataPoint);
    QTRY_VERIFY(!canvas->property("previewExecution").toBool());
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, dataPoint);
    QTRY_COMPARE(document.data().connections.size(), 1);
    QVERIFY(!session.connections().first().toMap().value(QStringLiteral("execution")).toBool());
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, outputPoint);
    QTest::mouseMove(window, executionPoint);
    QTRY_VERIFY(canvas->property("previewExecution").toBool());
    QCOMPARE(wireLayer->property("previewColor").value<QColor>(), QColor(QStringLiteral("#75a76f")));
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, executionPoint);
    QTRY_COMPARE(document.data().connections.size(), 2);
    QVERIFY(session.connections().last().toMap().value(QStringLiteral("execution")).toBool());
    QTRY_COMPARE(wireLayer->property("segments").value<QJSValue>().property("length").toInt(), 2);
    const auto segments = wireLayer->property("segments").value<QJSValue>();
    QVERIFY(!segments.property(0).property("execution").toBool());
    QVERIFY(segments.property(1).property("execution").toBool());
    session.removeConnection(document.data().connections.first().id.toString(QUuid::WithoutBraces));
    QCOMPARE(document.data().connections.size(), 1);
    QVERIFY(session.connections().first().toMap().value(QStringLiteral("execution")).toBool());
}

void EditorTest::longLabelsStayInsideCards()
{
    NodeRegistry registry;
    NodeTypeDefinition type;
    type.typeId = QStringLiteral("long-labels");
    type.displayName = QStringLiteral("这是需要完整查看的很长节点标题 Long blueprint node title");
    type.ports = {{QStringLiteral("in"), PortDirection::Input, QStringLiteral("number"),
                   QStringLiteral("这是需要完整查看的很长输入端口名称")},
                  {QStringLiteral("out"), PortDirection::Output, QStringLiteral("number"),
                   QStringLiteral("A very long English output port name")},
                  {QStringLiteral("extra"), PortDirection::Input, QStringLiteral("number"),
                   QStringLiteral("An unpaired input can use the full node width")}};
    QVERIFY(registry.add(type).code.isEmpty());
    NodeTypeDefinition source;
    source.typeId = QStringLiteral("long-source");
    source.displayName = QStringLiteral("A very long English node title for the source");
    source.ports = {{QStringLiteral("out"), PortDirection::Output, QStringLiteral("number"),
                     QStringLiteral("这是没有同排输入端口的很长输出名称")}};
    QVERIFY(registry.add(source).code.isEmpty());
    GraphDocument document(registry);
    const auto targetId = document.addNode(type.typeId, {320, 60}).id;
    const auto sourceId = document.addNode(source.typeId, {40, 60}).id;
    GraphEditSession session(document);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("testSession"), &session);
    engine.loadData(R"QML(
        import QtQuick 2.14
        import QtQuick.Window 2.14
        import "qrc:/BlueprintQuick" as Blueprint
        Window {
            width: 700
            height: 350
            visible: true
            QtObject {
                id: theme
                property color backgroundCanvas: "#141516"
                property color backgroundSurface: "#303234"
                property color borderPane: "#353638"
                property color border: "#a9b4bd"
                property color text: "#e1e2e3"
                property color subtleText: "#a9b4bd"
                property color highlightSoft: "#334455"
                property color highlightText: "#7aaddf"
                property color successText: "#75a76f"
                property color infoText: "#608ac5"
                property color dangerText: "#f17575"
            }
            Blueprint.GraphEditor {
                anchors.fill: parent
                session: testSession
                palettePanel: null
                inspectorPanel: null
                colors: theme
            }
        }
    )QML", QUrl(QStringLiteral("qrc:/BlueprintLongLabelsTest.qml")));
    QCOMPARE(engine.rootObjects().size(), 1);
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    QVERIFY(window);
    QVERIFY(QTest::qWaitForWindowExposed(window));
    auto *canvas = findItem(window->contentItem(), "graphCanvas");
    QVERIFY(canvas);
    QTRY_VERIFY(!canvas->property("initialFitPending").toBool());
    auto *targetCard = findItem(window->contentItem(), "node-long-labels");
    auto *sourceCard = findItem(window->contentItem(), "node-long-source");
    QVERIFY(targetCard && sourceCard);
    QQuickItem *title = nullptr;
    QQuickItem *sourceTitle = nullptr;
    QList<QQuickItem *> pending{window->contentItem()};
    while (!pending.isEmpty()) {
        auto *item = pending.takeLast();
        pending.append(item->childItems());
        if (item->inherits("QQuickText") && item->property("text").toString() == type.displayName)
            title = item;
        if (item->inherits("QQuickText") && item->property("text").toString() == source.displayName)
            sourceTitle = item;
    }
    auto *input = findItem(targetCard, "input-in");
    auto *output = findItem(targetCard, "output-out");
    auto *extra = findItem(targetCard, "input-extra");
    auto *sourceOutput = findItem(sourceCard, "output-out");
    QVERIFY(title && sourceTitle && input && output && extra && sourceOutput);
    auto *inputText = findItem(input->parentItem(), "QQuickText", true);
    auto *outputText = findItem(output->parentItem(), "QQuickText", true);
    auto *extraText = findItem(extra->parentItem(), "QQuickText", true);
    auto *sourceText = findItem(sourceOutput->parentItem(), "QQuickText", true);
    QVERIFY(inputText && outputText && extraText && sourceText);
    for (const auto *text : {title, sourceTitle, inputText, outputText, extraText, sourceText})
        QTRY_VERIFY(text->property("truncated").toBool());
    for (const auto *text : {title, inputText, outputText, extraText}) {
        QVERIFY(text->mapToItem(targetCard, {0, 0}).x() > 0);
        QVERIFY(text->mapToItem(targetCard, {text->width(), 0}).x() < targetCard->width());
    }
    for (const auto *text : {sourceTitle, sourceText}) {
        QVERIFY(text->mapToItem(sourceCard, {0, 0}).x() > 0);
        QVERIFY(text->mapToItem(sourceCard, {text->width(), 0}).x() < sourceCard->width());
    }
    QVERIFY(inputText->mapToItem(targetCard, {inputText->width(), 0}).x()
            < outputText->mapToItem(targetCard, {0, 0}).x());
    QVERIFY(extraText->width() > inputText->width());
    QCOMPARE(sourceText->width(), extraText->width());

    const QPoint inputPoint = input->mapToScene({input->width() / 2, input->height() / 2}).toPoint();
    QTest::mouseMove(window, inputPoint);
    QQmlExpression tooltipVisible(qmlContext(input), input, QStringLiteral("ToolTip.visible"));
    QTRY_VERIFY(tooltipVisible.evaluate().toBool());
    QQmlExpression tooltipText(qmlContext(input), input, QStringLiteral("ToolTip.text"));
    QCOMPARE(tooltipText.evaluate().toString(), type.ports.first().displayName);
    QVERIFY(!tooltipVisible.hasError() && !tooltipText.hasError());

    const QPoint sourcePoint = sourceOutput->mapToScene({sourceOutput->width() / 2,
                                                        sourceOutput->height() / 2}).toPoint();
    const QPoint header = title->mapToScene({title->width() / 2, title->height() / 2}).toPoint();
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, sourcePoint);
    QTest::mouseMove(window, header);
    QTRY_COMPARE(canvas->property("pointer").toPointF(), canvas->mapFromScene(header));
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, inputPoint);
    QTRY_COMPARE(document.data().connections.size(), 1);
    QCOMPARE(document.data().connections.first().source.nodeId, sourceId);
    QCOMPARE(document.data().connections.first().target.nodeId, targetId);
    const auto originalPosition = document.findNode(targetId)->position;
    QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, header);
    QTest::mouseMove(window, header + QPoint(30, 0));
    QTest::mouseMove(window, header + QPoint(60, 12));
    QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, header + QPoint(60, 12));
    QTRY_COMPARE(document.findNode(targetId)->position, originalPosition + QPointF(30, 12));
}

void EditorTest::graphChangesRefitViewport()
{
    NodeRegistry registry;
    NodeTypeDefinition type;
    type.typeId = QStringLiteral("viewport-node");
    type.displayName = QStringLiteral("Viewport node");
    QVERIFY(registry.add(type).code.isEmpty());
    GraphDocument document(registry);
    const auto nodeId = document.addNode(type.typeId, {40, 60}).id;
    GraphEditSession session(document);
    GraphDocument farDocument(registry);
    QVERIFY(farDocument.addNode(type.typeId, {10000, 10000}).error.code.isEmpty());
    auto farData = farDocument.data();
    farData.id = document.data().id;
    QVERIFY(farDocument.replaceData(farData).code.isEmpty());
    GraphEditSession farSession(farDocument);
    GraphDocument emptyDocument(registry);
    GraphEditSession emptySession(emptyDocument);
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("testSession"), &session);
    engine.loadData(R"QML(
        import QtQuick 2.14
        import QtQuick.Window 2.14
        import "qrc:/BlueprintQuick" as Blueprint
        Window {
            id: viewportWindow
            property bool colorsReady: false
            width: 700
            height: 350
            visible: true
            QtObject {
                id: theme
                property color backgroundCanvas: "#141516"
                property color backgroundSurface: "#303234"
                property color borderPane: "#353638"
                property color border: "#a9b4bd"
                property color text: "#e1e2e3"
                property color subtleText: "#a9b4bd"
                property color highlightSoft: "#334455"
                property color highlightText: "#7aaddf"
                property color successText: "#75a76f"
                property color infoText: "#608ac5"
                property color dangerText: "#f17575"
            }
            Blueprint.GraphEditor {
                objectName: "editor"
                anchors.fill: parent
                session: testSession
                palettePanel: null
                inspectorPanel: null
                colors: viewportWindow.colorsReady ? theme : null
            }
        }
    )QML", QUrl(QStringLiteral("qrc:/BlueprintViewportTest.qml")));
    QCOMPARE(engine.rootObjects().size(), 1);
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    QVERIFY(window);
    QVERIFY(QTest::qWaitForWindowExposed(window));
    auto *editor = findItem(window->contentItem(), "editor");
    QVERIFY(editor);
    auto *canvas = findItem(editor, "graphCanvas");
    QVERIFY(canvas);
    QCOMPARE(canvas->property("nodeCount").toInt(), 0);
    QVERIFY(canvas->property("initialFitPending").toBool());
    window->setProperty("colorsReady", true);
    QTRY_COMPARE(canvas->property("nodeCount").toInt(), 1);
    QTRY_VERIFY(!canvas->property("initialFitPending").toBool());
    auto *initialCard = findItem(editor, "node-viewport-node");
    QVERIFY(initialCard);
    QTRY_VERIFY(QLineF(initialCard->mapToItem(canvas, {initialCard->width() / 2, initialCard->height() / 2}),
                      QPointF(canvas->width() / 2, canvas->height() / 2)).length() < 1);
    const QPointF userPan(120, 90);
    const qreal userZoom = 0.8;
    canvas->setProperty("pan", userPan);
    canvas->setProperty("zoom", userZoom);
    session.moveNode(nodeId.toString(QUuid::WithoutBraces), {90, 70});
    session.undo();
    QCoreApplication::processEvents();
    QCOMPARE(document.findNode(nodeId)->position, QPointF(40, 60));
    QCOMPARE(canvas->property("pan").toPointF(), userPan);
    QCOMPARE(canvas->property("zoom").toReal(), userZoom);
    auto sameGraph = document.data();
    sameGraph.nodes.first().position = {100, 80};
    QVERIFY(document.replaceData(sameGraph).code.isEmpty());
    QCoreApplication::processEvents();
    QCOMPARE(canvas->property("pan").toPointF(), userPan);
    QCOMPARE(canvas->property("zoom").toReal(), userZoom);

    editor->setProperty("session", QVariant::fromValue(static_cast<QObject *>(&farSession)));
    QTRY_VERIFY(!canvas->property("initialFitPending").toBool());
    auto *farCard = findItem(editor, "node-viewport-node");
    QVERIFY(farCard);
    QTRY_VERIFY(QLineF(farCard->mapToItem(canvas, {farCard->width() / 2, farCard->height() / 2}),
                      QPointF(canvas->width() / 2, canvas->height() / 2)).length() < 1);
    QVERIFY(canvas->contains(farCard->mapToItem(canvas, {0, 0})));
    QVERIFY(canvas->contains(farCard->mapToItem(canvas, {farCard->width(), farCard->height()})));
    farData = farDocument.data();
    farData.id = QUuid::createUuid();
    farData.nodes.first().position = {-12000, -9000};
    QVERIFY(farDocument.replaceData(farData).code.isEmpty());
    QTRY_VERIFY(!canvas->property("initialFitPending").toBool());
    farCard = findItem(editor, "node-viewport-node");
    QVERIFY(farCard);
    QTRY_VERIFY(QLineF(farCard->mapToItem(canvas, {farCard->width() / 2, farCard->height() / 2}),
                      QPointF(canvas->width() / 2, canvas->height() / 2)).length() < 1);
    QVERIFY(canvas->contains(farCard->mapToItem(canvas, {0, 0})));
    QVERIFY(canvas->contains(farCard->mapToItem(canvas, {farCard->width(), farCard->height()})));
    canvas->setProperty("pan", userPan);
    canvas->setProperty("zoom", 0.12);
    farData = farDocument.data();
    farData.id = QUuid::createUuid();
    farData.nodes.clear();
    QVERIFY(farDocument.replaceData(farData).code.isEmpty());
    QTRY_VERIFY(!canvas->property("initialFitPending").toBool());
    QCOMPARE(canvas->property("nodeCount").toInt(), 0);
    QCOMPARE(canvas->property("zoom").toReal(), 1.0);
    QCOMPARE(canvas->property("pan").toPointF(), QPointF());

    window->setProperty("colorsReady", false);
    canvas->setProperty("pan", userPan);
    canvas->setProperty("zoom", 0.12);
    editor->setProperty("session", QVariant::fromValue(static_cast<QObject *>(&emptySession)));
    QCoreApplication::processEvents();
    QVERIFY(canvas->property("initialFitPending").toBool());
    window->setProperty("colorsReady", true);
    QTRY_VERIFY(!canvas->property("initialFitPending").toBool());
    QCOMPARE(canvas->property("zoom").toReal(), 1.0);
    QCOMPARE(canvas->property("pan").toPointF(), QPointF());
    QQmlExpression addFirstNode(qmlContext(editor), editor, QStringLiteral("addNode('viewport-node')"));
    addFirstNode.evaluate();
    QVERIFY(!addFirstNode.hasError());
    QTRY_COMPARE(emptyDocument.data().nodes.size(), 1);
    auto *firstCard = findItem(editor, "node-viewport-node");
    QVERIFY(firstCard);
    QCOMPARE(canvas->property("zoom").toReal(), 1.0);
    QVERIFY(canvas->contains(firstCard->mapToItem(canvas, {0, 0})));
    QVERIFY(canvas->contains(firstCard->mapToItem(canvas, {firstCard->width(), firstCard->height()})));
}

} // namespace

QTEST_MAIN(EditorTest)
#include "editor_test.moc"
