#include <QCommandLineParser>
#include <QCoreApplication>
#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QUrl>

#include <UICore/UICore.h>

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);

    QGuiApplication application(argc, argv);
    application.setApplicationName(QStringLiteral("UICore Memory Verification"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    UICore::initialize();

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption componentNameOption(
        QStringLiteral("component-name"), QStringLiteral("Component name."), QStringLiteral("name"));
    QCommandLineOption componentUrlOption(
        QStringLiteral("component-url"), QStringLiteral("Component QML URL."), QStringLiteral("url"));
    QCommandLineOption componentCountOption(
        QStringLiteral("component-count"), QStringLiteral("Number of instances."), QStringLiteral("count"));
    QCommandLineOption componentProfileOption(
        QStringLiteral("component-profile"), QStringLiteral("Component property profile."), QStringLiteral("profile"));
    QCommandLineOption preloadUrlOption(
        QStringLiteral("preload-url"), QStringLiteral("QML URL created before measurement."), QStringLiteral("url"));
    QCommandLineOption harnessOption(
        QStringLiteral("harness"), QStringLiteral("Memory harness QML file."), QStringLiteral("path"));
    parser.addOptions({componentNameOption,
                       componentUrlOption,
                       componentCountOption,
                       componentProfileOption,
                       preloadUrlOption,
                       harnessOption});
    parser.process(application);

    bool countValid = false;
    const int componentCount = parser.value(componentCountOption).toInt(&countValid);
    if (!countValid || componentCount < 0 || parser.value(harnessOption).isEmpty())
        return 2;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(
        QStringLiteral("componentTestName"), parser.value(componentNameOption));
    engine.rootContext()->setContextProperty(
        QStringLiteral("componentTestUrl"), QUrl(parser.value(componentUrlOption)));
    engine.rootContext()->setContextProperty(
        QStringLiteral("componentTestCount"), componentCount);
    engine.rootContext()->setContextProperty(
        QStringLiteral("componentTestProfile"), parser.value(componentProfileOption));
    engine.rootContext()->setContextProperty(
        QStringLiteral("componentPreloadUrl"), QUrl(parser.value(preloadUrlOption)));

    const QUrl harnessUrl = QUrl::fromLocalFile(
        QFileInfo(parser.value(harnessOption)).absoluteFilePath());
    QObject::connect(&engine,
                     &QQmlApplicationEngine::objectCreated,
                     &application,
                     [harnessUrl](QObject *object, const QUrl &url) {
                         if (!object && url == harnessUrl)
                             QCoreApplication::exit(-1);
                     },
                     Qt::QueuedConnection);
    engine.load(harnessUrl);

    return application.exec();
}
