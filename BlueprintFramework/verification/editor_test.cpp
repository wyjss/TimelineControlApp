#include <Blueprint/GraphEditSession.h>

#include <QQmlApplicationEngine>
#include <QQmlContext>
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
    source.parameters = {value};
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
}

} // namespace

QTEST_MAIN(EditorTest)
#include "editor_test.moc"
