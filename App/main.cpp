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
#include <qqml.h>
#include <QUrl>
#include <QVector>
#include <QUdpSocket>
//#include <QScreen>

#include <iostream>
#include <UICore/Shell/AppSettings.h>
#include <UICore/UICore.h>
#include <LocatorViewer.h>
#include "runtime/TimelineRuntime.h"
#include "runtime/TimelineShellController.h"
#include "runtime/video/FfmpegVideoFrameItem.h"
#include "runtime/video/PcTimelinePreviewGenerator.h"
#include "runtime/utils.h"
#include "server/web/WebControlServer.h"

#include "LogMacros.h"
namespace {

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

int main(int argc, char *argv[])
{
    //qputenv("QT_QUICK_BACKEND", "software");
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    LOG_INFO("enable AA_EnableHighDpiScaling");
#endif
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QApplication application(argc, argv);
    if(0)
	{// debug
		QByteArray pkt(6, 0xff);
		// 30-56-0F-4E-CA-5B
		QString sMac = "30560F4ECA5B";
		QByteArray bMac;
		Utils::toHexData(sMac, &bMac);
		for (int i = 0; i < 16; ++i) {
			pkt.push_back(bMac);
		}
		QUdpSocket* sock = new QUdpSocket;
        //sock->setSocketOption(QUdpSocket::MulticastLoopbackOption, 1);
		auto ip = QHostAddress("255.255.255.255");
		ip = QHostAddress("192.168.100.255");

		bool r = false;


        r = sock->bind(QHostAddress::AnyIPv4);
        LOG_INFO("bind " << r);

		//r = sock->joinMulticastGroup(QHostAddress("255.255.255.255"));
        //LOG_INFO("join " << r);

		auto size = sock->writeDatagram(pkt, ip, 7);
		LOG_INFO("send " << size);

		size = sock->writeDatagram(pkt, ip, 9);
		LOG_INFO("send " << size);

		size = sock->writeDatagram(pkt, ip, 5);
		LOG_INFO("send " << size);

        r = sock->flush();
        LOG_INFO("flush " << r);
		int a = 0;
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
