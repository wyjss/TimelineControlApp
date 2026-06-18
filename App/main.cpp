#include <QApplication>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStringList>
#include <qqml.h>
#include <QUrl>

#include "runtime/app/AppSettings.h"
#include "runtime/TimelineRuntime.h"
#include "runtime/TimelineShellController.h"
#include "runtime/video/FfmpegVideoFrameItem.h"


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

    QString projectionVideoSource;
    const QStringList arguments = application.arguments();
    for (int index = 1; index < arguments.size(); ++index) {
        const QString argument = arguments.at(index);
        if (argument == QStringLiteral("--projection-video") && index + 1 < arguments.size()) {
            projectionVideoSource = arguments.at(++index);
        } else if (argument.startsWith(QStringLiteral("--projection-video="))) {
            projectionVideoSource = argument.mid(QStringLiteral("--projection-video=").size());
        }
    }

    if (!projectionVideoSource.isEmpty()) {
        const QUrl sourceUrl(projectionVideoSource);
        const QFileInfo sourceFileInfo(projectionVideoSource);
        if (sourceFileInfo.isAbsolute() || !sourceUrl.isValid() || sourceUrl.scheme().isEmpty())
            projectionVideoSource = QUrl::fromLocalFile(QFileInfo(projectionVideoSource).absoluteFilePath()).toString();
    }

    TimelineControl::TimelineRuntime runtime;
    TimelineControl::TimelineShellController shellController(&runtime);
    runtime.setShell(&shellController);
    runtime.settings()->setApplicationName(QStringLiteral("Timeline Control App"));
    runtime.settings()->setLocale(QStringLiteral("zh_CN"));
    runtime.settings()->setThemeMode(QStringLiteral("dark"));
    runtime.settings()->setValues(QVariantMap{
        {QStringLiteral("canvasDelegateSource"), QString()},
        {QStringLiteral("projectionVideoSource"), projectionVideoSource}
    });

    qmlRegisterType<TimelineControl::FfmpegVideoFrameItem>("TimelineControl.Media", 1, 0, "FfmpegVideoFrameItem");

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
