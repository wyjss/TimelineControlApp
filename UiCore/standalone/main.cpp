#include <QApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QUrl>

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QApplication application(argc, argv);
    application.setOrganizationName(QStringLiteral("UiCore"));
    application.setOrganizationDomain(QStringLiteral("uicore.local"));
    application.setApplicationName(QStringLiteral("UiCore Standalone"));

    QQmlApplicationEngine engine;
    const QUrl mainUrl(QStringLiteral("qrc:/UiCore/qml/standalone/UiCoreStandalone.qml"));
    QObject::connect(&engine,
                     &QQmlApplicationEngine::objectCreated,
                     &application,
                     [mainUrl](QObject *object, const QUrl &url) {
                         if (!object && url == mainUrl)
                             QCoreApplication::exit(-1);
                     },
                     Qt::QueuedConnection);
    engine.load(mainUrl);

    return application.exec();
}
