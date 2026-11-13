#include "DemoGraph.h"

#include <UICore/UICore.h>

#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QCoreApplication::setApplicationName("BlueprintFramework-demo");
    UICore::initialize();

    DemoGraph graph;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("demoGraph", &graph);
    engine.load(QUrl("qrc:/BlueprintDemo/qml/Main.qml"));
    if (engine.rootObjects().isEmpty())
        return 1;
    return app.exec();
}
