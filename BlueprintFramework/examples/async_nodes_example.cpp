#include <Blueprint/BasicNodes.h>
#include <Blueprint/GraphDocument.h>
#include <Blueprint/WaitNodes.h>

#include <QCoreApplication>
#include <QMetaObject>
#include <QTextStream>
#include <QTimer>

int main(int argc, char *argv[])
{
    using namespace Blueprint;

    QCoreApplication app(argc, argv);
    QTextStream output(stdout);
    QTextStream errors(stderr);

    const auto startType = QStringLiteral("example.start");
    const auto addType = QStringLiteral("demo.add");
    const auto waitType = QStringLiteral("demo.wait");
    const auto execIn = QStringLiteral("execIn");
    const auto execOut = QStringLiteral("execOut");
    const auto inputA = QStringLiteral("A");
    const auto inputB = QStringLiteral("B");
    const auto valueKey = QStringLiteral("value");
    const auto durationKey = QStringLiteral("durationMs");
    const auto numberType = QStringLiteral("number");
    constexpr double left = 60.0;
    constexpr double right = 40.0;

    NodeRegistry registry;
    RuntimeImplementations implementations;
    const auto basicError = registerBasicNodes(registry, implementations);
    if (!basicError.code.isEmpty()) {
        errors << basicError.message << Qt::endl;
        return 1;
    }
    const auto waitError = registerWaitNodes(registry);
    if (!waitError.code.isEmpty()) {
        errors << waitError.message << Qt::endl;
        return 1;
    }
    const auto entryError = registry.add({startType, "Start", {
        {execOut, PortDirection::Output, {}, {}, PortKind::Execution},
        {inputA, PortDirection::Output, numberType},
        {inputB, PortDirection::Output, numberType}
    }});
    if (!entryError.code.isEmpty()) {
        errors << entryError.message << Qt::endl;
        return 1;
    }

    GraphDocument graph(registry);
    const auto start = graph.addNode(startType, {});
    const auto add = graph.addNode(addType, {});
    const auto wait = graph.addNode(waitType, {});
    for (const auto &node : {start, add, wait}) {
        if (!node.error.code.isEmpty()) {
            errors << node.error.message << Qt::endl;
            return 1;
        }
    }
    const Endpoint entryPort{start.id, execOut};
    const auto trigger = graph.connectPorts(entryPort, {wait.id, execIn});
    const auto duration = graph.connectPorts({add.id, valueKey}, {wait.id, durationKey});
    const auto first = graph.connectPorts({start.id, inputA}, {add.id, inputA});
    const auto second = graph.connectPorts({start.id, inputB}, {add.id, inputB});
    for (const auto &edge : {trigger, duration, first, second}) {
        if (!edge.error.code.isEmpty()) {
            errors << edge.error.message << Qt::endl;
            return 1;
        }
    }

    QObject timerOwner;
    addWaitImplementations(implementations, timerOwner);
    QElapsedTimer elapsed;
    bool waitPending = false;

    GraphRuntime runtime;
    const auto error = runtime.start(graph.snapshot(), implementations);
    if (!error.code.isEmpty()) {
        errors << error.message << Qt::endl;
        return 1;
    }
    elapsed.start();
    const auto execution = runtime.execute(entryPort, {{inputA, left}, {inputB, right}});
    if (!execution.error.code.isEmpty()) {
        errors << execution.error.message << Qt::endl;
        return 1;
    }
    if (timerOwner.findChild<QTimer *>()) {
        errors << "Execution began before returning to the event loop." << Qt::endl;
        return 1;
    }
    QMetaObject::invokeMethod(&runtime, [&] {
        const auto *timer = timerOwner.findChild<QTimer *>();
        waitPending = timer && timer->isActive() && timer->interval() == left + right;
        if (waitPending) {
            output << "Add: " << left << " + " << right << " = " << timer->interval() << Qt::endl;
            output << "Wait: " << timer->interval() << " ms" << Qt::endl;
        }
    }, Qt::QueuedConnection);
    QObject::connect(&runtime, &GraphRuntime::executionFinished, &app, [&](const QUuid &id, const Diagnostic &error) {
        if (!error.code.isEmpty()) {
            errors << error.message << Qt::endl;
            app.exit(1);
            return;
        }
        if (id != execution.executionId || !waitPending) {
            errors << "Unexpected execution order, duration or result." << Qt::endl;
            app.exit(1);
            return;
        }
        output << "Finished after " << elapsed.elapsed() << " ms." << Qt::endl;
        app.quit();
    });
    QTimer::singleShot(5000, &app, [&] {
        errors << "Execution did not finish." << Qt::endl;
        app.exit(1);
    });
    return app.exec();
}
