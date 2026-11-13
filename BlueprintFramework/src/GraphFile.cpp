#include <Blueprint/GraphDocument.h>

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>

#include <utility>

namespace Blueprint {

Diagnostic GraphDocument::saveFile(const QString &path) const
{
    QJsonArray nodes;
    for (const NodeData &node : m_data.nodes) {
        nodes.append(QJsonObject{
            {QStringLiteral("id"), node.id.toString(QUuid::WithoutBraces)},
            {QStringLiteral("type"), node.typeId},
            {QStringLiteral("x"), node.position.x()},
            {QStringLiteral("y"), node.position.y()},
            {QStringLiteral("parameters"), QJsonObject::fromVariantMap(node.parameterOverrides)}
        });
    }

    const auto encodeEndpoint = [](const Endpoint &endpoint) {
        return QJsonObject{
            {QStringLiteral("node"), endpoint.nodeId.toString(QUuid::WithoutBraces)},
            {QStringLiteral("port"), endpoint.portKey}
        };
    };
    QJsonArray connections;
    for (const ConnectionData &connection : m_data.connections) {
        connections.append(QJsonObject{
            {QStringLiteral("id"), connection.id.toString(QUuid::WithoutBraces)},
            {QStringLiteral("source"), encodeEndpoint(connection.source)},
            {QStringLiteral("target"), encodeEndpoint(connection.target)}
        });
    }

    const QJsonDocument json(QJsonObject{
        {QStringLiteral("version"), 1},
        {QStringLiteral("id"), m_data.id.toString(QUuid::WithoutBraces)},
        {QStringLiteral("nodes"), nodes},
        {QStringLiteral("connections"), connections}
    });
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return {"file.io", file.errorString()};
    const QByteArray encoded = json.toJson();
    if (file.write(encoded) != encoded.size() || !file.commit())
        return {"file.io", file.errorString()};
    return {};
}

Diagnostic GraphDocument::loadFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return {"file.io", file.errorString()};

    QJsonParseError parseError;
    const QJsonDocument json = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError)
        return {"file.syntax", parseError.errorString()};
    const QJsonObject root = json.object();
    if (root.value(QStringLiteral("version")).toInt() != 1)
        return {"file.version", "Unsupported blueprint file version."};

    const QJsonValue nodes = root.value(QStringLiteral("nodes"));
    const QJsonValue connections = root.value(QStringLiteral("connections"));
    if (!nodes.isArray() || !connections.isArray())
        return {"file.structure", "The blueprint file must contain node and connection arrays."};

    GraphData data{QUuid(root.value(QStringLiteral("id")).toString()), {}, {}};
    for (const QJsonValue &entry : nodes.toArray()) {
        const QJsonObject node = entry.toObject();
        const QJsonValue x = node.value(QStringLiteral("x"));
        const QJsonValue y = node.value(QStringLiteral("y"));
        const QJsonValue parameters = node.value(QStringLiteral("parameters"));
        if (!x.isDouble() || !y.isDouble() || !parameters.isObject())
            return {"file.structure", "Invalid node position or parameters."};
        QVariantMap overrides;
        const QJsonObject fields = parameters.toObject();
        for (auto it = fields.constBegin(); it != fields.constEnd(); ++it) {
            const QJsonValue value = it.value();
            overrides.insert(it.key(), value.isDouble() ? QVariant(value.toDouble()) : value.toVariant());
        }
        data.nodes.append(NodeData{
            QUuid(node.value(QStringLiteral("id")).toString()),
            node.value(QStringLiteral("type")).toString(),
            QPointF(x.toDouble(), y.toDouble()),
            std::move(overrides)
        });
    }

    const auto decodeEndpoint = [](const QJsonObject &object) {
        return Endpoint{
            QUuid(object.value(QStringLiteral("node")).toString()),
            object.value(QStringLiteral("port")).toString()
        };
    };
    for (const QJsonValue &entry : connections.toArray()) {
        const QJsonObject connection = entry.toObject();
        data.connections.append(ConnectionData{
            QUuid(connection.value(QStringLiteral("id")).toString()),
            decodeEndpoint(connection.value(QStringLiteral("source")).toObject()),
            decodeEndpoint(connection.value(QStringLiteral("target")).toObject())
        });
    }

    return replaceData(std::move(data));
}

} // namespace Blueprint
