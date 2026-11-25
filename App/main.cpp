#include <QApplication>
#include <QDataStream>
#include <QFileInfo>
#include <QImage>
#include <QMetaType>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickStyle>
#include <QSerialPort>
#include <QSerialPortInfo>
#include <QMessageBox>
#include <qqml.h>
#include <QUrl>
#include <QVector>
#include <QTcpSocket>
#include <QLocalSocket>
#include <QLocalServer>
//#include <QScreen>

#include <iostream>
#include <UICore/Shell/AppSettings.h>
#include <UICore/UICore.h>
#include <LocatorViewer.h>
#include "runtime/TimelineRuntime.h"
#include "runtime/TimelineShellController.h"
#include "runtime/video/FfmpegVideoFrameItem.h"
#include "runtime/video/PcTimelinePreviewGenerator.h"
#include "runtime/video/TimelineThumbnailProvider.h"
#include "runtime/utils.h"
#include "server/osc/OscControlServer.h"
#include "server/web/WebControlServer.h"

#include "LogMacros.h"

namespace {

	bool instanceTest()
	{
		QString localHostName = "TimelineApp";
		QLocalSocket* sock = new QLocalSocket(qApp);
		sock->connectToServer(localHostName);
		if (sock->waitForConnected(500)) {
			return false;
		}

		sock->deleteLater();

		auto svr = new QLocalServer(qApp);
		QObject::connect(qApp, &QCoreApplication::aboutToQuit, svr, &QLocalServer::deleteLater);

		// @todo linux 下有bug，qApp推出，svr关不掉
		svr->listen(localHostName);
		return true;
	}

class DeviceIconProvider final : public QQuickImageProvider
{
public:
    DeviceIconProvider()
        : QQuickImageProvider(QQuickImageProvider::Image)
    {
    }

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override
    {
        const QString name = QFileInfo(QUrl::fromPercentEncoding(id.toUtf8())).fileName();
        QImage image(QStringLiteral(":/TimelineControlApp/App/assets/icons/%1.png").arg(name));
        if (image.isNull())
            image.load(QCoreApplication::applicationDirPath()
                       + QStringLiteral("/assets/icons/%1.png").arg(name));
        if (image.isNull())
            image.load(QStringLiteral(":/TimelineControlApp/App/assets/icons/missing.png"));
        if (size)
            *size = image.size();
        return requestedSize.isValid()
            ? image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation)
            : image;
    }
};

}
#pragma comment(lib, "D:\\Program\\RA\\TimelineControlApp\\liblicense\\RA_License.lib")
#include "D:\\Program\\RA\\TimelineControlApp\\liblicense\\ra_license.h"
#include <Windows.h>
int main(int argc, char *argv[])
{
#ifdef WIN32
    if (qgetenv("showControl") == "1" || qgetenv("showControl") == "true") {
		if (GetConsoleWindow() == nullptr) {
			if (!AttachConsole(ATTACH_PARENT_PROCESS) && !AllocConsole()) {
				MessageBoxW(nullptr, L"连接或创建控制台失败", L"错误", MB_OK);
				return -1;
			}

			FILE* stream = nullptr;
			if (freopen_s(&stream, "CONOUT$", "w", stdout) != 0
				|| freopen_s(&stream, "CONOUT$", "w", stderr) != 0) {
				MessageBoxW(nullptr, L"绑定控制台输出失败", L"错误", MB_OK);
				return 1;
			}

			std::cout.clear();
			std::cerr.clear();
		}
    }
#endif

    //qputenv("QT_QUICK_BACKEND", "software");
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
	QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
		Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    LOG_INFO("enable AA_EnableHighDpiScaling");
#endif
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QApplication application(argc, argv);
    if (!instanceTest()) {
		QMessageBox::critical(nullptr, "实例正在运行", "请勿重复开启");
		exit(0);
    }
    //
    //if (RA_License::Instance()->IsEmpower() == false) {
    //    QMessageBox::critical(nullptr, "license已过期", "请联系厂家更新license");
    //    exit(0);
    //}

    if(0)
    {
        QTcpSocket* sock = new QTcpSocket;
        sock->connectToHost("172.16.10.65", 23);
       bool b =  sock->waitForConnected(99999);
       if (!b) {
           LOG_FATAL("cnt failed" << sock->state());
       }
        QObject::connect(sock, &QTcpSocket::readyRead, [sock]() {
            auto d = sock->readAll();
            LOG_INFO("read data: " << d);
                         });
        QByteArray order;
        Utils::toHexData("EF FE 01 01 01 01 00 00 00 00 01 01 00 00 08 11 00 00 20 0B 41 54 2B 53 79 73 74 65 6D 3F 0D 0A",
                         &order);
        sock->write(order);
        return application.exec();
    }
    UICore::initialize();
    LocatorViewer::initialize();
    application.setOrganizationName(QStringLiteral("TimelineControlApp"));
    application.setOrganizationDomain(QStringLiteral("timeline-control.local"));
    application.setApplicationName(QStringLiteral("时间线控制应用"));
    //QRect virtualGeometry = QGuiApplication::primaryScreen()->virtualGeometry();
    //qDebug() << virtualGeometry;
   // exit(0);
    qRegisterMetaTypeStreamOperators<QVector<int>>("QVector<int>");

    TimelineRuntime runtime;
    WebControlServer webControlServer(
        &runtime,
        QCoreApplication::applicationDirPath() + QStringLiteral("/web"));
    if (!webControlServer.start())
        qWarning("Failed to start web control server on http://127.0.0.1:8080");
    OscControlServer oscControlServer(*runtime.timelineManager());
    oscControlServer.start(QHostAddress::AnyIPv4, 9000);
    TimelineShellController shellController(&runtime);
    runtime.setShell(&shellController);
    PcTimelinePreviewGenerator pcTimelinePreviewGenerator(runtime.timelineManager(),
                                                           runtime.deviceModel(),
                                                           &shellController);
    runtime.settings()->setApplicationName(QStringLiteral("时间线控制应用"));
    runtime.settings()->setLocale(QStringLiteral("zh_CN"));
    runtime.settings()->setThemeMode(QStringLiteral("dark"));
    runtime.settings()->setValues(QVariantMap{
        {QStringLiteral("canvasDelegateSource"), QString()}
    });

    qmlRegisterType<FfmpegVideoFrameItem>("TimelineControl.Media", 1, 0, "FfmpegVideoFrameItem");

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("deviceicon"), new DeviceIconProvider);
    engine.addImageProvider(QStringLiteral("timeline-thumbnails"),
                            new TimelineThumbnailProvider(runtime.mediaCache()));
    engine.rootContext()->setContextProperty(QStringLiteral("app"), &runtime);
    engine.rootContext()->setContextProperty(QStringLiteral("pcTimelinePreviewGenerator"),
                                             &pcTimelinePreviewGenerator);

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

   
    auto r = application.exec();
    LocatorViewer::quit();
    LOG_INFO("viewer quit");
    return r;
}
