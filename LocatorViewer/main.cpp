#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQmlContext>
#include <QQuickWindow>
#include <QDir>
#include <QFile>
#include <QUrl>

#include "ragis/ragis.h"
#include "ragis/quick/RAGisQuick.h"

using namespace ragis;

int main(int argc, char* argv[])
{
    QApplication::addLibraryPath("./plugins");
    QApplication::setAttribute(Qt::AA_X11InitThreads);
    QApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
#ifdef _WIN32
    QString testDir = "D:\\Program\\RA\\RAGis2\\run\\RAGisTest_run";
#else
    QString testDir = "/home/tian/Program/projects/build-RAGis2-Qt_5_14_2_Qt5_14_2_temporary-Release/output";
#endif
    if (QDir(testDir).exists()) {
        QDir::setCurrent(testDir);
    }
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

	QApplication app(argc, argv);

	QQuickStyle::setStyle("Universal");

	//
	ragis::quick::initialize();
	QQmlApplicationEngine engine;
	engine.addImportPath("qrc:/");

	const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
	QObject::connect(
		&engine,
		&QQmlApplicationEngine::objectCreated,
		&app,
		[url](QObject* obj, const QUrl& objUrl) {
			if (!obj && url == objUrl)
				QCoreApplication::exit(-1);
		},
		Qt::QueuedConnection);
	engine.load(url);


	return app.exec();
}