#include <QApplication>
#include <QFileInfo>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStringList>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <qqml.h>
#include <QUrl>

#include <iostream>
#include "runtime/app/AppSettings.h"
#include "runtime/TimelineRuntime.h"
#include "runtime/TimelineShellController.h"
#include "runtime/video/FfmpegVideoFrameItem.h"

//template<typename TDds, typename TProto>
//static inline void copyFieldValueToDds(const TProto& p, TDds& d, int maxCharXSize)
//{
//	if constexpr (
//		std::is_array_v<std::remove_reference_t<TDds>> &&
//		std::is_same_v<std::remove_extent_t<std::remove_reference_t<TDds>>, char>) {
//
//		using Arr = std::remove_reference_t<TDds>;
//		constexpr size_t N = std::extent_v<Arr>;
//
//		//memcpy(d, p.c_str(), std::min<int>(N - 1, p.size()));
//		d[N - 1] = '\0';
//
//        std::cout << N << "\n";
//		std::cout << typeid(p).name() << ", " << typeid(d).name() << "\n";
//		std::cout << sizeof(TProto) << ", " << sizeof(p) << "\n";
//	}
//
//   
//}
int main(int argc, char *argv[])
{
    //char ddd[10];
    //copyFieldValueToDds(ddd, ddd, 0);
    //exit(0);
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QApplication application(argc, argv);
    application.setOrganizationName(QStringLiteral("TimelineControlApp"));
    application.setOrganizationDomain(QStringLiteral("timeline-control.local"));
    application.setApplicationName(QStringLiteral("时间线控制应用"));

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

    TimelineRuntime runtime;
    TimelineShellController shellController(&runtime);
    runtime.setShell(&shellController);
    runtime.settings()->setApplicationName(QStringLiteral("时间线控制应用"));
    runtime.settings()->setLocale(QStringLiteral("zh_CN"));
    runtime.settings()->setThemeMode(QStringLiteral("dark"));
    runtime.settings()->setValues(QVariantMap{
        {QStringLiteral("canvasDelegateSource"), QString()},
        {QStringLiteral("projectionVideoSource"), projectionVideoSource}
    });

    qmlRegisterType<FfmpegVideoFrameItem>("TimelineControl.Media", 1, 0, "FfmpegVideoFrameItem");

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
