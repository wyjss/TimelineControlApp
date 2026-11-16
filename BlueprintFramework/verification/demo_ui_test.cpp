#include "DemoGraph.h"

#include <UICore/UICore.h>

#include <QDir>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlProperty>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QQuickWindow>
#include <QtTest>

using namespace Blueprint;

class DemoUiTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void inspectorFitsWindow_data();
    void inspectorFitsWindow();
    void editsWaitTime();
};

void DemoUiTest::initTestCase()
{
    UICore::initialize();
}

void DemoUiTest::inspectorFitsWindow_data()
{
    QTest::addColumn<QSize>("size");
    QTest::addColumn<QString>("type");
    QTest::addColumn<bool>("expandedInput");
    for (const auto &size : {QSize(940, 550), QSize(1280, 730)}) {
        for (const auto &type : {QStringLiteral("call"), QStringLiteral("setProperty"), QStringLiteral("wait")}) {
            const auto name = QStringLiteral("%1x%2-%3").arg(size.width()).arg(size.height()).arg(type).toLatin1();
            QTest::newRow(name.constData()) << size << type << false;
        }
    }
    QTest::newRow("940x550-expanded-setProperty") << QSize(940, 550) << QStringLiteral("setProperty") << true;
}

void DemoUiTest::inspectorFitsWindow()
{
    QFETCH(QSize, size);
    QFETCH(QString, type);
    QFETCH(bool, expandedInput);

    DemoGraph graph;
    auto *session = qobject_cast<GraphEditSession *>(graph.session());
    QVERIFY(session);
    const auto target = graph.existingSpeakerOptions().first().toMap().value(QStringLiteral("value")).toString();
    const auto node = type == QStringLiteral("wait")
        ? session->addNode(QStringLiteral("demo.wait"), {})
        : graph.addOperation(QStringLiteral("demo.") + type, target,
            type == QStringLiteral("call") ? QStringLiteral("playFor") : QStringLiteral("testDurationMs"), {});
    QVERIFY2(!node.isEmpty(), qPrintable(graph.error()));

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("demoGraph"), &graph);
    engine.load(QUrl(QStringLiteral("qrc:/BlueprintDemo/qml/Main.qml")));
    QVERIFY(!engine.rootObjects().isEmpty());
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    QVERIFY(window);
    window->resize(size);
    QVERIFY(QTest::qWaitForWindowExposed(window));
    auto *editor = window->findChild<QQuickItem *>(QStringLiteral("graphEditor"));
    QVERIFY(editor);
    QVERIFY(editor->setProperty("selectedNodeId", node));
    auto *input = window->findChild<QQuickItem *>(type == QStringLiteral("wait")
        ? QStringLiteral("waitDuration") : QStringLiteral("operationTarget"));
    QVERIFY(input);
    QTRY_VERIFY(input->isVisible());
    if (expandedInput)
        QVERIFY(input->setProperty("controlHeight", 128));

    QQuickItem *flickable = input;
    while (flickable && !flickable->inherits("QQuickFlickable"))
        flickable = flickable->parentItem();
    QQuickItem *panel = input;
    while (panel->parentItem() && !panel->parentItem()->inherits("QQuickLoader"))
        panel = panel->parentItem();
    QQuickItem *viewport = flickable ? flickable : panel;
    QTRY_VERIFY(viewport->height() > 0);
    if (flickable) {
        QTRY_VERIFY(flickable->property("contentHeight").toReal() > 0);
        QTRY_VERIFY(flickable->property("contentWidth").toReal() <= flickable->width() + 1);
        const auto maximumY = qMax(qreal(0), flickable->property("contentHeight").toReal() - flickable->height());
        if (expandedInput)
            QVERIFY(maximumY > 0);
        QVERIFY(flickable->setProperty("contentY", maximumY));
    }

    QQuickItem *remove = nullptr;
    for (auto *item : panel->findChildren<QQuickItem *>()) {
        if (item->inherits("QQuickAbstractButton")
            && item->property("text").toString() == QStringLiteral("删除节点"))
            remove = item;
    }
    QVERIFY(remove);
    QTRY_VERIFY(remove->mapRectToItem(viewport, remove->boundingRect()).top()
        >= input->mapRectToItem(viewport, input->boundingRect()).bottom());
    if (expandedInput)
        QTRY_VERIFY(input->height() >= input->implicitHeight() - 1);
    QTRY_VERIFY(remove->height() > 0);
    QTRY_VERIFY(remove->mapRectToItem(viewport, remove->boundingRect()).top() >= -1);
    QTRY_VERIFY(remove->mapRectToItem(viewport, remove->boundingRect()).bottom() <= viewport->height() + 1);
    const auto removeBounds = remove->mapRectToItem(viewport, remove->boundingRect());
    QVERIFY(removeBounds.left() >= -1);
    QVERIFY(removeBounds.right() <= viewport->width() + 1);
    QVERIFY(remove->isVisible());

    const auto screenshotDirectory = qEnvironmentVariable("BLUEPRINT_DEMO_SCREENSHOT_DIR");
    if (!screenshotDirectory.isEmpty()) {
        QVERIFY(QDir().mkpath(screenshotDirectory));
        QTest::qWait(100);
        const auto grab = window->contentItem()->grabToImage();
        QVERIFY(grab);
        QTRY_VERIFY(!grab->image().isNull());
        const auto name = QString::fromLatin1(QTest::currentDataTag()) + QStringLiteral(".png");
        QVERIFY(grab->image().save(QDir(screenshotDirectory).filePath(name)));
    }

    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
        remove->mapToScene(remove->boundingRect().center()).toPoint());
    QTRY_VERIFY(!session->containsNode(node));
    session->undo();
    QTRY_VERIFY(session->containsNode(node));
    QVERIFY(editor->setProperty("selectedNodeId", node));

    if (expandedInput) {
        QVERIFY(flickable);
        const auto scrollEnd = flickable->property("contentHeight").toReal() - flickable->height();
        QVERIFY(flickable->setProperty("contentY", scrollEnd));
        QVERIFY(flickable->property("contentY").toReal() > 0);
        const auto nextNode = graph.addOperation(QStringLiteral("demo.setProperty"), target, QStringLiteral("testDurationMs"), {});
        QVERIFY(!nextNode.isEmpty());
        QVERIFY(editor->setProperty("selectedNodeId", nextNode));
        QTRY_COMPARE(flickable->property("contentY").toReal(), qreal(0));
        QTRY_VERIFY(input->mapRectToItem(flickable, input->boundingRect()).top() >= -1);
        QTRY_VERIFY(input->mapRectToItem(flickable, input->boundingRect()).bottom() <= flickable->height() + 1);
    }

    if (type == QStringLiteral("call") && size.width() == 940) {
        const auto diagnosticKey = QStringLiteral("unknownParameter").repeated(30);
        QVERIFY(!session->setParameter(node, diagnosticKey, 0));
        QQuickItem *status = nullptr;
        for (auto *item : window->findChildren<QQuickItem *>()) {
            if (item->inherits("QQuickText") && item->property("text").toString() == session->error())
                status = item;
        }
        QVERIFY(status);
        QTRY_COMPARE(status->property("text").toString(), session->error());
        QVERIFY(status->property("truncated").toBool());
        QCOMPARE(QQmlProperty(status, QStringLiteral("ToolTip.text"), qmlContext(status)).read().toString(), session->error());

        const auto result = session->addNode(QStringLiteral("demo.result"), {});
        QVERIFY(session->connectPorts(node, QStringLiteral("out/demo.speaker/playFor/playedDurationMs"),
            result, QStringLiteral("value")));
        QVERIFY(!graph.bindCall(node, target, QStringLiteral("playTest")));
        QCoreApplication::processEvents();
        QQuickItem *operationError = nullptr;
        QList<QQuickItem *> pending{window->contentItem()};
        while (!pending.isEmpty()) {
            auto *item = pending.takeLast();
            pending.append(item->childItems());
            if (item->inherits("QQuickText") && item->isVisible() && item->property("text").toString() == graph.error()
                && item->parentItem()->property("calling").toBool())
                operationError = item;
        }
        QVERIFY(operationError);
        QTRY_VERIFY(operationError->property("truncated").toBool());
        QCOMPARE(QQmlProperty(operationError, QStringLiteral("ToolTip.text"), qmlContext(operationError)).read().toString(), graph.error());
    }
}

void DemoUiTest::editsWaitTime()
{
    DemoGraph graph;
    auto *session = qobject_cast<GraphEditSession *>(graph.session());
    QVERIFY(session);
    const auto wait = session->addNode(QStringLiteral("demo.waitUntil"), {});
    QVERIFY(!wait.isEmpty());

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("demoGraph"), &graph);
    engine.load(QUrl(QStringLiteral("qrc:/BlueprintDemo/qml/Main.qml")));
    QVERIFY(!engine.rootObjects().isEmpty());
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    QVERIFY(window);
    QVERIFY(QTest::qWaitForWindowExposed(window));
    auto *editor = window->findChild<QQuickItem *>(QStringLiteral("graphEditor"));
    QVERIFY(editor);
    QVERIFY(editor->setProperty("selectedNodeId", wait));
    auto *input = window->findChild<QQuickItem *>(QStringLiteral("waitDuration"));
    QVERIFY(input);
    const auto timePortText = [window] {
        QList<QQuickItem *> items{window->contentItem()};
        while (!items.isEmpty()) {
            auto *item = items.takeLast();
            if (item->objectName() == QStringLiteral("input-durationMs")) {
                for (auto *rowItem : item->parentItem()->childItems()) {
                    if (rowItem->inherits("QQuickText"))
                        return rowItem->property("text").toString();
                }
            }
            items.append(item->childItems());
        }
        return QString();
    };
    QTRY_COMPARE(timePortText(), QStringLiteral("00:01.000"));
    QTRY_COMPARE(input->property("text").toString(), QStringLiteral("00:01.000"));

    input->forceActiveFocus();
    QTRY_VERIFY(input->hasActiveFocus());
    QTest::keyClick(window, Qt::Key_A, Qt::ControlModifier);
    for (const char key : QByteArrayLiteral("6:27.06"))
        QTest::keyClick(window, key);
    QTest::keyClick(window, Qt::Key_Return);
    QTRY_COMPARE(timePortText(), QStringLiteral("06:27.060"));
    QCOMPARE(input->property("text").toString(), QStringLiteral("06:27.060"));

    QVERIFY(graph.setWaitDuration(wait, QStringLiteral("35791:23.647")));
    QTRY_COMPARE(timePortText(), QStringLiteral("35791:23.647"));
    QVERIFY(graph.setWaitDuration(wait, QStringLiteral("596:31:23.647")));
    QVERIFY(!graph.setWaitDuration(wait, QStringLiteral("35791:23.648")));
    QVERIFY(!graph.setWaitDuration(wait, QStringLiteral("00:60:05.001")));
    QCOMPARE(input->property("text").toString(), QStringLiteral("35791:23.647"));
    session->undo();
    QTRY_COMPARE(timePortText(), QStringLiteral("06:27.060"));

    const auto constant = session->addNode(QStringLiteral("demo.constant"), QPointF(200, 0));
    QVERIFY(!constant.isEmpty());
    QVERIFY(session->connectPorts(constant, QStringLiteral("value"), wait, QStringLiteral("durationMs")));
    QTRY_VERIFY(!input->isEnabled());
    QTRY_COMPARE(timePortText(), QStringLiteral("目标时间（毫秒）"));
    session->undo();
    QTRY_VERIFY(input->isEnabled());
    QTRY_COMPARE(timePortText(), QStringLiteral("06:27.060"));
}

QTEST_MAIN(DemoUiTest)

#include "demo_ui_test.moc"
