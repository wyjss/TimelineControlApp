#include <Blueprint/GraphDocument.h>

#include <QScopedValueRollback>
#include <QtMath>

#include <algorithm>

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

QVariant GraphDocument::parameterValue(const QUuid &nodeId, const QString &key) const
{
    const NodeData *node = findNode(nodeId);
    if (!node)
        return {};

    const ParameterDefinition *definition = parameter(*node, key);
    return definition ? node->parameterOverrides.value(key, definition->defaultValue) : QVariant();
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
    if (sourcePort->valueTypeId != targetPort->valueTypeId) {
        return QStringLiteral("Cannot connect value type '%1' to '%2'.")
            .arg(sourcePort->valueTypeId, targetPort->valueTypeId);
    }

    for (const ConnectionData &connection : m_data.connections) {
        if (connection.target.nodeId != target.nodeId || connection.target.portKey != target.portKey)
            continue;
        if (connection.source.nodeId == source.nodeId && connection.source.portKey == source.portKey)
            return QStringLiteral("This connection already exists.");
        return QStringLiteral("The target input already has a connection.");
    }

    return {};
}

EditResult GraphDocument::addNode(const QString &typeId, QPointF position)
{
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    if (!m_registry.find(typeId))
        return {{}, QStringLiteral("Node type '%1' is not registered.").arg(typeId)};
    if (!qIsFinite(position.x()) || !qIsFinite(position.y()))
        return {{}, QStringLiteral("The node position must be finite.")};

    const QUuid id = QUuid::createUuid();
    m_data.nodes.append(NodeData{id, typeId, position, {}});

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
    if (m_notifying)
        return {{}, QStringLiteral("Cannot edit during a change notification.")};
    const int index = nodeIndex(nodeId);
    if (index < 0)
        return {{}, QStringLiteral("The node does not exist.")};

    const NodeData &node = m_data.nodes.at(index);
    const ParameterDefinition *definition = parameter(node, key);
    if (!definition)
        return {{}, QStringLiteral("Unknown parameter '%1'.").arg(key)};
    if (!NodeRegistry::acceptsValue(definition->valueTypeId, value))
        return {{}, QStringLiteral("Invalid value for parameter '%1'.").arg(key)};

    // QVariant 对数值使用近似比较，参数编辑需要保留实际变化。
    const bool isNumber = definition->valueTypeId == QStringLiteral("number");
    const auto matchesValue = [&value, isNumber](const QVariant &candidate) {
        if (!candidate.isValid())
            return false;
        return isNumber ? candidate.toDouble() == value.toDouble() : candidate == value;
    };
    if (matchesValue(node.parameterOverrides.value(key, definition->defaultValue)))
        return {nodeId, {}};

    auto &overrides = m_data.nodes[index].parameterOverrides;
    if (matchesValue(definition->defaultValue))
        overrides.remove(key);
    else
        overrides.insert(key, value);

    GraphChangeSet change;
    change.changedNodes.append(NodeChange{nodeId, false, {key}});
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

void GraphDocument::publishChange(GraphChangeSet changeSet)
{
    changeSet.revision = ++m_revision;
    // 阻止信号重入导致后续观察者先收到较新的版本。
    QScopedValueRollback<bool> notifying(m_notifying, true);
    emit changed(changeSet);
}

} // namespace Blueprint
