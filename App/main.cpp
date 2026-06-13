#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>

#include "runtime/app/AppSettings.h"
#include "runtime/TimelineRuntime.h"
#include "runtime/TimelineShellController.h"

int main(int argc, char *argv[])
{
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QApplication application(argc, argv);
    application.setOrganizationName(QStringLiteral("TimelineControlApp"));
    application.setOrganizationDomain(QStringLiteral("timeline-control.local"));
    application.setApplicationName(QStringLiteral("Timeline Control App"));

    TimelineControl::TimelineRuntime runtime;
    TimelineControl::TimelineShellController shellController(&runtime);
    runtime.setShell(&shellController);
    runtime.settings()->setApplicationName(QStringLiteral("Timeline Control App"));
    runtime.settings()->setLocale(QStringLiteral("zh_CN"));
    runtime.settings()->setThemeMode(QStringLiteral("dark"));
    runtime.settings()->setValues(QVariantMap{
        {QStringLiteral("canvasDelegateSource"), QString()}
    });

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("app"), &runtime);
    engine.rootContext()->setContextProperty(QStringLiteral("timelineShellController"), &shellController);

    const QUrl mainUrl(QStringLiteral("qrc:/TimelineControlApp/App/main.qml"));
    QObject::connect(&engine,
                     &QQmlApplicationEngine::objectCreated,
                     &application,
                     [mainUrl](QObject *object, const QUrl &objectUrl) {
                         if (!object && objectUrl == mainUrl)
                             QCoreApplication::exit(-1);
                     },
                     Qt::QueuedConnection);

    engine.load(mainUrl);
    if (engine.rootObjects().isEmpty())
        return -1;

    return application.exec();
}
