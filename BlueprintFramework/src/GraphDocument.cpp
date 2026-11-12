#include <Blueprint/GraphDocument.h>

#include <QHash>
#include <QScopedValueRollback>
#include <QSet>
#include <QtMath>

#include <algorithm>
#include <utility>

namespace Blueprint {

GraphDocument::GraphDocument(const NodeRegistry &registry, QObject *parent)
    : QObject(parent),
      m_registry(registry),
      m_data{QUuid::createUuid(), {}, {}}
{
}

const GraphData &GraphDocument::data() const
{
    return m_data;
}

quint64 GraphDocument::revision() const
{
    return m_revision;
}

const NodeData *GraphDocument::findNode(const QUuid &nodeId) const
{
    const int index = nodeIndex(nodeId);
    return index < 0 ? nullptr : &m_data.nodes.at(index);
}

const NodeTypeDefinition *GraphDocument::findNodeType(const QString &typeId) const
{
    return m_registry.find(typeId);
}

QVariant GraphDocument::parameterValue(const QUuid &nodeId, const QString &key) const
{
    const NodeData *node = findNode(nodeId);
    if (!node)
        return {};

    const ParameterDefinition *definition = parameter(*node, key);
    return definition ? node->parameterOverrides.value(key, definition->defaultValue) : QVariant();
}

QVariantMap GraphDocument::parameterValues(const QUuid &nodeId) const
{
    const NodeData *node = findNode(nodeId);
    if (!node)
        return {};

    QVariantMap values;
    const auto &parameters = m_registry.find(node->typeId)->parameters;
    for (const ParameterDefinition &definition : parameters) {
        const QVariant value = node->parameterOverrides.value(definition.key, definition.defaultValue);
        if (value.isValid())
            values.insert(definition.key, value);
    }
    return values;
}

QString GraphDocument::canConnect(const Endpoint &source, const Endpoint &target) const
{
    const PortDefinition *sourcePort = port(source);
    if (!sourcePort)
        return QStringLiteral("The source node or port does not exist.");
    const PortDefinition *targetPort = port(target);
    if (!targetPort)
        return QStringLiteral("The target node or port does not exist.");
    if (sourcePort->direction != PortDirection::Output || targetPort->direction != PortDirection::Input)
        return QStringLiteral("A connection must go from an output to an input.");
    const auto sourceType = sourcePort->typeParameterKey.isEmpty()
        ? sourcePort->valueTypeId : parameterValue(source.nodeId, sourcePort->typeParameterKey).toString();
    const auto targetType = targetPort->typeParameterKey.isEmpty()
        ? targetPort->valueTypeId : parameterValue(target.nodeId, targetPort->typeParameterKey).toString();
    if (sourceType.isEmpty() || targetType.isEmpty())
        return QStringLiteral("Configure the data port before connecting it.");
    if (sourceType != targetType) {
        return QStringLiteral("Cannot connect value type '%1' to '%2'.")
            .arg(sourceType, targetType);
    }

    for (const ConnectionData &connection : m_data.connections) {
        if (sourceType == executionPortType && connection.source.nodeId == source.nodeId
            && connection.source.portKey == source.portKey)
            return QStringLiteral("The execution output already has a connection.");
        if (connection.target.nodeId != target.nodeId || connection.target.portKey != target.portKey)
            continue;
        if (connection.source.nodeId == source.nodeId && connection.source.portKey == source.portKey)
            return QStringLiteral("This connection already exists.");
        return QStringLiteral("The target input already has a connection.");
    }

    return {};
}

EditResult GraphDocument::addNode(const QString &typeId, QPointF position, QVariantMap parameters)
{
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    const auto *type = m_registry.find(typeId);
    if (!type)
        return {{}, QStringLiteral("Node type '%1' is not registered.").arg(typeId)};
    if (!qIsFinite(position.x()) || !qIsFinite(position.y()))
        return {{}, QStringLiteral("The node position must be finite.")};

    NodeData node{QUuid::createUuid(), typeId, position, std::move(parameters)};
    for (auto it = node.parameterOverrides.cbegin(); it != node.parameterOverrides.cend(); ++it) {
        const auto *definition = parameter(node, it.key());
        if (!definition || !NodeRegistry::acceptsParameterValue(*definition, it.value()))
            return {{}, QStringLiteral("Invalid initial parameter '%1'.").arg(it.key())};
    }
    const auto check = checkInstance(node, *type);
    if (!check.error.isEmpty())
        return check;
    const QUuid id = node.id;
    m_data.nodes.append(std::move(node));

    GraphChangeSet change;
    change.addedNodeIds.append(id);
    publishChange(change);
    return {id, {}};
}

EditResult GraphDocument::moveNode(QUuid nodeId, QPointF position)
{
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    const int index = nodeIndex(nodeId);
    if (index < 0)
        return {{}, QStringLiteral("The node does not exist.")};
    if (!qIsFinite(position.x()) || !qIsFinite(position.y()))
        return {{}, QStringLiteral("The node position must be finite.")};
    const QPointF previous = m_data.nodes.at(index).position;
    if (previous.x() == position.x() && previous.y() == position.y())
        return {nodeId, {}};

    m_data.nodes[index].position = position;

    GraphChangeSet change;
    change.changedNodes.append(NodeChange{nodeId, true, {}});
    publishChange(change);
    return {nodeId, {}};
}

EditResult GraphDocument::setParameter(QUuid nodeId, QString key, QVariant value)
{
    return setParameters(nodeId, {{std::move(key), std::move(value)}});
}

EditResult GraphDocument::setParameters(QUuid nodeId, const QVariantMap &values)
{
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    const int index = nodeIndex(nodeId);
    if (index < 0)
        return {{}, QStringLiteral("The node does not exist.")};

    const NodeData &node = m_data.nodes.at(index);
    auto overrides = node.parameterOverrides;
    QStringList changedKeys;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        const ParameterDefinition *definition = parameter(node, it.key());
        if (!definition)
            return {{}, QStringLiteral("Unknown parameter '%1'.").arg(it.key())};
        if (!NodeRegistry::acceptsParameterValue(*definition, it.value()))
            return {{}, QStringLiteral("Invalid value for parameter '%1'.").arg(it.key())};

        // QVariant 对数值使用近似比较，参数编辑需要保留实际变化。
        const bool isNumber = definition->valueTypeId == QStringLiteral("number");
        const auto matchesValue = [&it, isNumber](const QVariant &candidate) {
            if (!candidate.isValid())
                return false;
            return isNumber ? candidate.toDouble() == it.value().toDouble() : candidate == it.value();
        };
        if (matchesValue(node.parameterOverrides.value(it.key(), definition->defaultValue)))
            continue;
        if (matchesValue(definition->defaultValue))
            overrides.remove(it.key());
        else
            overrides.insert(it.key(), it.value());
        changedKeys.append(it.key());
    }
    if (changedKeys.isEmpty())
        return {nodeId, {}};

    const auto *type = m_registry.find(node.typeId);
    if (type->instancePolicy == InstancePolicy::UniqueByParameter
        && changedKeys.contains(type->instanceKeyParameter)) {
        const auto check = checkInstance({node.id, node.typeId, node.position, overrides}, *type);
        if (!check.error.isEmpty())
            return check;
    }

    for (const PortDefinition &definition : type->ports) {
        if (definition.typeParameterKey.isEmpty() || !changedKeys.contains(definition.typeParameterKey))
            continue;
        for (const auto &link : m_data.connections) {
            if ((link.source.nodeId == nodeId && link.source.portKey == definition.key)
                || (link.target.nodeId == nodeId && link.target.portKey == definition.key))
                return {{}, tr("请先断开端口「%1」的连线，再切换属性类型。").arg(definition.key)};
        }
    }
    m_data.nodes[index].parameterOverrides = std::move(overrides);

    GraphChangeSet change;
    change.changedNodes.append(NodeChange{nodeId, false, changedKeys});
    publishChange(change);
    return {nodeId, {}};
}

EditResult GraphDocument::connectPorts(const Endpoint &source, const Endpoint &target)
{
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    const QString error = canConnect(source, target);
    if (!error.isEmpty())
        return {{}, error};

    const QUuid id = QUuid::createUuid();
    m_data.connections.append(ConnectionData{id, source, target});

    GraphChangeSet change;
    change.addedConnectionIds.append(id);
    publishChange(change);
    return {id, {}};
}

EditResult GraphDocument::removeConnection(QUuid connectionId)
{
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    const auto first = m_data.connections.cbegin();
    const auto last = m_data.connections.cend();
    const auto it = std::find_if(first, last, [&connectionId](const ConnectionData &connection) {
        return connection.id == connectionId;
    });
    if (it == last)
        return {{}, QStringLiteral("The connection does not exist.")};

    m_data.connections.removeAt(static_cast<int>(it - first));

    GraphChangeSet change;
    change.removedConnectionIds.append(connectionId);
    publishChange(change);
    return {connectionId, {}};
}

EditResult GraphDocument::removeNode(QUuid nodeId)
{
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    const int index = nodeIndex(nodeId);
    if (index < 0)
        return {{}, QStringLiteral("The node does not exist.")};

    GraphChangeSet change;
    change.removedNodeIds.append(nodeId);
    auto &connections = m_data.connections;
    const auto last = std::remove_if(connections.begin(), connections.end(),
                                     [&change, &nodeId](const ConnectionData &connection) {
        if (connection.source.nodeId != nodeId && connection.target.nodeId != nodeId)
            return false;
        change.removedConnectionIds.append(connection.id);
        return true;
    });
    connections.erase(last, connections.end());
    m_data.nodes.removeAt(index);

    publishChange(change);
    return {nodeId, {}};
}

QString GraphDocument::replaceData(GraphData data)
{
    if (m_notifying)
        return QStringLiteral("Cannot edit during a change notification.");
    if (data.id.isNull())
        return QStringLiteral("The graph ID is invalid.");

    QSet<QUuid> nodeIds;
    QHash<QPair<QString, QString>, QUuid> instances;
    for (const NodeData &node : qAsConst(data.nodes)) {
        if (node.id.isNull() || nodeIds.contains(node.id))
            return QStringLiteral("Invalid or duplicate node ID.");
        const auto *type = m_registry.find(node.typeId);
        if (!type)
            return QStringLiteral("Node type '%1' is not registered.").arg(node.typeId);
        if (!qIsFinite(node.position.x()) || !qIsFinite(node.position.y()))
            return QStringLiteral("The node position must be finite.");

        for (auto it = node.parameterOverrides.cbegin(); it != node.parameterOverrides.cend(); ++it) {
            const auto *definition = parameter(node, it.key());
            if (!definition || !NodeRegistry::acceptsParameterValue(*definition, it.value()))
                return QStringLiteral("Invalid parameter '%1' on node %2.").arg(it.key(), node.id.toString());
        }
        nodeIds.insert(node.id);

        if (type->instancePolicy != InstancePolicy::Multiple) {
            const auto key = instanceKey(node, *type);
            if (key.isNull())
                return tr("节点类型「%1」需要有效的实例标识。").arg(node.typeId);
            const auto identity = qMakePair(node.typeId, key);
            const auto previous = instances.constFind(identity);
            if (previous != instances.cend())
                return tr("节点类型「%1」有重复实例（%2 和 %3）。")
                    .arg(node.typeId, previous.value().toString(), node.id.toString());
            instances.insert(identity, node.id);
        }
    }

    // 在临时文档中按保存顺序校验连线，复用正常编辑时的占用规则。
    GraphDocument validated(m_registry);
    validated.m_data.id = data.id;
    validated.m_data.nodes = std::move(data.nodes);
    validated.m_data.connections.reserve(data.connections.size());
    QSet<QUuid> connectionIds;
    for (const ConnectionData &connection : qAsConst(data.connections)) {
        if (connection.id.isNull() || connectionIds.contains(connection.id))
            return QStringLiteral("Invalid or duplicate connection ID.");
        const QString error = validated.canConnect(connection.source, connection.target);
        if (!error.isEmpty())
            return error;
        validated.m_data.connections.append(connection);
        connectionIds.insert(connection.id);
    }

    m_data = std::move(validated.m_data);
    GraphChangeSet change;
    change.reset = true;
    publishChange(change);
    return {};
}

int GraphDocument::nodeIndex(const QUuid &nodeId) const
{
    for (int index = 0; index < m_data.nodes.size(); ++index) {
        if (m_data.nodes.at(index).id == nodeId)
            return index;
    }
    return -1;
}

const PortDefinition *GraphDocument::port(const Endpoint &endpoint) const
{
    const NodeData *node = findNode(endpoint.nodeId);
    if (!node)
        return nullptr;

    // 节点只能从文档快照中已注册的类型创建。
    const auto &ports = m_registry.find(node->typeId)->ports;
    for (const PortDefinition &definition : ports) {
        if (definition.key == endpoint.portKey)
            return &definition;
    }
    return nullptr;
}

const ParameterDefinition *GraphDocument::parameter(const NodeData &node, const QString &key) const
{
    const auto &parameters = m_registry.find(node.typeId)->parameters;
    for (const ParameterDefinition &definition : parameters) {
        if (definition.key == key)
            return &definition;
    }
    return nullptr;
}

QString GraphDocument::instanceKey(const NodeData &node, const NodeTypeDefinition &type) const
{
    if (type.instancePolicy == InstancePolicy::SinglePerDocument)
        return QStringLiteral("");
    const auto &key = type.instanceKeyParameter;
    const auto value = node.parameterOverrides.value(key, parameter(node, key)->defaultValue).toString();
    return value.trimmed().isEmpty() ? QString() : value;
}

EditResult GraphDocument::checkInstance(const NodeData &node, const NodeTypeDefinition &type) const
{
    if (type.instancePolicy == InstancePolicy::Multiple)
        return {};
    const auto key = instanceKey(node, type);
    if (key.isNull())
        return {{}, tr("节点类型「%1」需要有效的实例标识。").arg(node.typeId)};
    for (const NodeData &other : m_data.nodes) {
        if (other.typeId == node.typeId && other.id != node.id && instanceKey(other, type) == key)
            return {{}, tr("节点类型「%1」已有匹配的实例。").arg(node.typeId), other.id};
    }
    return {};
}

void GraphDocument::publishChange(GraphChangeSet changeSet)
{
    changeSet.revision = ++m_revision;
    // 阻止信号重入导致后续观察者先收到较新的版本。
    QScopedValueRollback<bool> notifying(m_notifying, true);
    emit changed(changeSet);
}

} // namespace Blueprint
