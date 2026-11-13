#include <Blueprint/GraphDocument.h>

#include <QCoreApplication>
#include <QTextStream>

int main(int argc, char *argv[])
{
    using namespace Blueprint;

    QCoreApplication app(argc, argv);
    QTextStream output(stdout);
    QTextStream errors(stderr);

    const QString valueKey = "value";
    const NodeTypeDefinition constantType{
        "example.constant",
        "Constant",
        {{valueKey, PortDirection::Output, "number"}},
        {{valueKey, "number", 0.0}}
    };
    const NodeTypeDefinition displayType{
        "example.display",
        "Display",
        {
            {"input", PortDirection::Input, "number"},
            {"visible", PortDirection::Input, "bool"}
        },
        {}
    };

    NodeRegistry registry;
    for (const auto &definition : {constantType, displayType}) {
        const Diagnostic error = registry.add(definition);
        if (!error.code.isEmpty()) {
            errors << error.message << '\n';
            return 1;
        }
    }

    GraphDocument graph(registry);
    int notificationCount = 0;
    GraphChangeSet lastChange;
    QObject::connect(&graph, &GraphDocument::changed, &graph, [&](const GraphChangeSet &change) {
        ++notificationCount;
        lastChange = change;
    });

    const EditResult constant = graph.addNode(constantType.typeId, QPointF(40, 80));
    const EditResult display = graph.addNode(displayType.typeId, QPointF(300, 80));
    if (!constant.error.code.isEmpty() || !display.error.code.isEmpty()
        || graph.parameterValue(constant.id, valueKey) != QVariant(0.0)) {
        errors << "Node creation or default value check failed.\n";
        return 1;
    }

    const EditResult parameterEdit = graph.setParameter(constant.id, valueKey, 42.0);
    if (!parameterEdit.error.code.isEmpty() || graph.parameterValue(constant.id, valueKey) != QVariant(42.0)
        || lastChange.changedNodes.size() != 1
        || lastChange.changedNodes.first().parameterKeys != QStringList{valueKey}) {
        errors << "Parameter edit or notification check failed.\n";
        return 1;
    }

    const Endpoint source{constant.id, valueKey};
    const Endpoint target{display.id, "input"};
    const Endpoint incompatibleTarget{display.id, "visible"};
    const quint64 beforeRejectedEdit = graph.revision();
    const int beforeRejectedNotification = notificationCount;
    const EditResult rejected = graph.connectPorts(source, incompatibleTarget);
    if (rejected.error.code.isEmpty() || graph.canConnect(source, incompatibleTarget).code != rejected.error.code
        || graph.revision() != beforeRejectedEdit || notificationCount != beforeRejectedNotification
        || !graph.data().connections.isEmpty()) {
        errors << "An invalid connection changed the graph.\n";
        return 1;
    }
    output << "Rejected connection: " << rejected.error.message << '\n';

    const EditResult connection = graph.connectPorts(source, target);
    if (!connection.error.code.isEmpty() || lastChange.addedConnectionIds != QVector<QUuid>{connection.id}) {
        errors << "Connection or notification check failed.\n";
        return 1;
    }
    output << "Connected " << constantType.displayName << '.' << source.portKey
           << " -> " << displayType.displayName << '.' << target.portKey << '\n';

    const int beforeRemoval = notificationCount;
    const EditResult removed = graph.removeNode(constant.id);
    if (!removed.error.code.isEmpty() || notificationCount != beforeRemoval + 1
        || lastChange.removedNodeIds != QVector<QUuid>{constant.id}
        || lastChange.removedConnectionIds != QVector<QUuid>{connection.id}
        || lastChange.revision != graph.revision()
        || graph.findNode(constant.id) || !graph.data().connections.isEmpty()) {
        errors << "Node and connection removal did not commit together.\n";
        return 1;
    }
    output << "Removed node and its connection in one change.\n";
    return 0;
}
