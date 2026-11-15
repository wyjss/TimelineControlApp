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
    qRegisterMetaType<GraphChangeSet>();
    connect(&m_registry, &NodeRegistry::typeAdded, this, &GraphDocument::typesChanged);
}

const GraphData &GraphDocument::data() const
{
    return m_data;
}

quint64 GraphDocument::revision() const
{
    return m_revision;
}

const NodeRegistry &GraphDocument::registry() const
{
    return m_registry;
}

GraphSnapshot GraphDocument::snapshot() const
{
    GraphSnapshot result{m_data.id, m_revision, {}, m_data.connections};
    for (const NodeData &node : m_data.nodes)
        result.nodes.append({node.id, node.typeId, parameterValues(node.id), nodePorts(node.id)});
    return result;
}

QVector<PortDefinition> GraphDocument::nodePorts(const QUuid &nodeId) const
{
    const NodeData *node = findNode(nodeId);
    if (!node)
        return {};
    const auto *type = m_registry.find(node->typeId);
    return type->resolvePorts ? type->resolvePorts(*node) : type->ports;
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

Diagnostic GraphDocument::canConnect(const Endpoint &source, const Endpoint &target, QUuid connectionToIgnore) const
{
    const auto sourcePort = port(source);
    if (!sourcePort)
        return {"graph.missing_port", "The source node or port does not exist.", source.nodeId, source.portKey};
    const auto targetPort = port(target);
    if (!targetPort)
        return {"graph.missing_port", "The target node or port does not exist.", target.nodeId, target.portKey};
    if (sourcePort->direction != PortDirection::Output || targetPort->direction != PortDirection::Input)
        return {"graph.port_direction", "A connection must go from an output to an input.", target.nodeId, target.portKey};
    if (sourcePort->kind != targetPort->kind && sourcePort->kind != PortKind::DataAndExecution)
        return {"graph.port_kind", "Execution and data ports cannot be connected.", target.nodeId, target.portKey};
    if (targetPort->kind == PortKind::Data) {
        if (sourcePort->valueTypeId.isEmpty() || targetPort->valueTypeId.isEmpty())
            return {"graph.unconfigured_port", "Configure the data port before connecting it.", target.nodeId, target.portKey};
        if (sourcePort->valueTypeId != targetPort->valueTypeId
            && targetPort->valueTypeId != anyValueType)
            return {"graph.port_type", QStringLiteral("Cannot connect value type '%1' to '%2'.")
                .arg(sourcePort->valueTypeId, targetPort->valueTypeId), target.nodeId, target.portKey};
    }

    for (const ConnectionData &connection : m_data.connections) {
        if (connection.id == connectionToIgnore)
            continue;
        if (connection.target.nodeId != target.nodeId || connection.target.portKey != target.portKey)
            continue;
        if (connection.source.nodeId == source.nodeId && connection.source.portKey == source.portKey)
            return {"graph.duplicate_connection", "This connection already exists.", target.nodeId, target.portKey};
        if (targetPort->kind == PortKind::Data)
            return {"graph.input_occupied", "The target input already has a connection.", target.nodeId, target.portKey};
    }
    return {};
}

EditResult GraphDocument::addNode(const QString &typeId, QPointF position, QVariantMap parameters)
{
    if (m_notifying)
        return {{}, {"graph.reentrant_edit", "Cannot edit during a change notification."}};
    const auto *type = m_registry.find(typeId);
    if (!type)
        return {{}, {"graph.unknown_type", QStringLiteral("Node type '%1' is not registered.").arg(typeId)}};
    if (!qIsFinite(position.x()) || !qIsFinite(position.y()))
        return {{}, {"graph.invalid_position", "The node position must be finite."}};

    NodeData node{QUuid::createUuid(), typeId, position, std::move(parameters)};
    auto error = NodeRegistry::validateValues(type->parameters, node.parameterOverrides);
    if (!error.code.isEmpty()) {
        error.nodeId = node.id;
        return {{}, error};
    }
    error = NodeRegistry::validatePorts(type->resolvePorts ? type->resolvePorts(node) : type->ports,
                                        bool(type->resolvePorts));
    if (!error.code.isEmpty()) {
        error.nodeId = node.id;
        return {{}, error};
    }
    const auto check = checkInstance(node, *type);
    if (!check.error.code.isEmpty())
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
        return {{}, {"graph.reentrant_edit", "Cannot edit during a change notification."}};
    const int index = nodeIndex(nodeId);
    if (index < 0)
        return {{}, {"graph.missing_node", "The node does not exist.", nodeId}};
    if (!qIsFinite(position.x()) || !qIsFinite(position.y()))
        return {{}, {"graph.invalid_position", "The node position must be finite."}};
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
        return {{}, {"graph.reentrant_edit", "Cannot edit during a change notification."}};
    const int index = nodeIndex(nodeId);
    if (index < 0)
        return {{}, {"graph.missing_node", "The node does not exist.", nodeId}};

    const NodeData &node = m_data.nodes.at(index);
    auto overrides = node.parameterOverrides;
    QStringList changedKeys;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        const ParameterDefinition *definition = parameter(node, it.key());
        if (!definition)
            return {{}, {"graph.unknown_parameter", QStringLiteral("Unknown parameter '%1'.").arg(it.key()), nodeId, it.key()}};
        if (it.value().isValid() && !NodeRegistry::acceptsParameterValue(*definition, it.value()))
            return {{}, {"graph.invalid_parameter", QStringLiteral("Invalid value for parameter '%1'.").arg(it.key()), nodeId, it.key()}};

        const QVariant previous = node.parameterOverrides.value(it.key(), definition->defaultValue);
        const QVariant next = it.value().isValid() ? it.value() : definition->defaultValue;
        // QVariant 对数值使用近似比较，参数编辑需要保留实际变化。
        const bool equal = previous.isValid() == next.isValid()
            && (definition->valueTypeId == QStringLiteral("number") && next.isValid()
                ? previous.toDouble() == next.toDouble() : previous == next);
        if (equal && (it.value().isValid() || !overrides.contains(it.key())))
            continue;
        const bool isDefault = next.isValid() == definition->defaultValue.isValid()
            && (definition->valueTypeId == QStringLiteral("number") && next.isValid()
                ? next.toDouble() == definition->defaultValue.toDouble() : next == definition->defaultValue);
        if (!it.value().isValid() || isDefault)
            overrides.remove(it.key());
        else
            overrides.insert(it.key(), next);
        changedKeys.append(it.key());
    }
    if (changedKeys.isEmpty())
        return {nodeId, {}};

    const auto *type = m_registry.find(node.typeId);
    const auto check = checkInstance({node.id, node.typeId, node.position, overrides}, *type);
    if (!check.error.code.isEmpty())
        return check;

    // 只检查此实例的派生端口与相关连线，失败时保留原配置。
    if (type->resolvePorts) {
        const NodeData candidate{node.id, node.typeId, node.position, overrides};
        const auto ports = type->resolvePorts(candidate);
        Diagnostic error = NodeRegistry::validatePorts(ports, true);
        if (!error.code.isEmpty()) {
            error.nodeId = node.id;
            return {{}, error};
        }
        for (const auto &link : m_data.connections) {
            for (const Endpoint &endpoint : {link.source, link.target}) {
                if (endpoint.nodeId != nodeId)
                    continue;
                const auto previous = port(endpoint);
                const bool execution = port(link.target)->kind == PortKind::Execution;
                bool compatible = false;
                for (const auto &next : ports) {
                    if (next.key == endpoint.portKey && next.direction == previous->direction
                        && next.kind == previous->kind
                        && (execution || next.valueTypeId == previous->valueTypeId)) {
                        compatible = true;
                        break;
                    }
                }
                if (!compatible)
                    return {{}, {"graph.connected_port_change",
                        tr("请先断开端口「%1」的连线，再切换属性类型。").arg(endpoint.portKey), nodeId, endpoint.portKey}};
            }
        }
    }
    m_data.nodes[index].parameterOverrides = std::move(overrides);

    GraphChangeSet change;
    change.changedNodes.append(NodeChange{nodeId, false, changedKeys, bool(type->resolvePorts)});
    publishChange(change);
    return {nodeId, {}};
}

EditResult GraphDocument::connectPorts(const Endpoint &source, const Endpoint &target)
{
    if (m_notifying)
        return {{}, {"graph.reentrant_edit", "Cannot edit during a change notification."}};
    const Diagnostic error = canConnect(source, target);
    if (!error.code.isEmpty())
        return {{}, error};

    const QUuid id = QUuid::createUuid();
    m_data.connections.append(ConnectionData{id, source, target});

    GraphChangeSet change;
    change.addedConnectionIds.append(id);
    publishChange(change);
    return {id, {}};
}

EditResult GraphDocument::reconnectConnection(QUuid connectionId, const Endpoint &source, const Endpoint &target)
{
    if (m_notifying)
        return {{}, {"graph.reentrant_edit", "Cannot edit during a change notification."}};
    const auto first = m_data.connections.begin();
    const auto last = m_data.connections.end();
    const auto it = std::find_if(first, last, [&connectionId](const ConnectionData &connection) {
        return connection.id == connectionId;
    });
    if (it == last)
        return {{}, {"graph.missing_connection", "The connection does not exist.", {}, connectionId.toString()}};
    if (it->source.nodeId == source.nodeId && it->source.portKey == source.portKey
        && it->target.nodeId == target.nodeId && it->target.portKey == target.portKey)
        return {connectionId, {}};
    const Diagnostic error = canConnect(source, target, connectionId);
    if (!error.code.isEmpty())
        return {{}, error};

    it->source = source;
    it->target = target;

    GraphChangeSet change;
    change.removedConnectionIds.append(connectionId);
    change.addedConnectionIds.append(connectionId);
    publishChange(change);
    return {connectionId, {}};
}

EditResult GraphDocument::removeConnection(QUuid connectionId)
{
    if (m_notifying)
        return {{}, {"graph.reentrant_edit", "Cannot edit during a change notification."}};
    const auto first = m_data.connections.cbegin();
    const auto last = m_data.connections.cend();
    const auto it = std::find_if(first, last, [&connectionId](const ConnectionData &connection) {
        return connection.id == connectionId;
    });
    if (it == last)
        return {{}, {"graph.missing_connection", "The connection does not exist.", {}, connectionId.toString()}};

    m_data.connections.removeAt(static_cast<int>(it - first));

    GraphChangeSet change;
    change.removedConnectionIds.append(connectionId);
    publishChange(change);
    return {connectionId, {}};
}

EditResult GraphDocument::removeNode(QUuid nodeId)
{
    if (m_notifying)
        return {{}, {"graph.reentrant_edit", "Cannot edit during a change notification."}};
    const int index = nodeIndex(nodeId);
    if (index < 0)
        return {{}, {"graph.missing_node", "The node does not exist.", nodeId}};

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

Diagnostic GraphDocument::replaceData(GraphData data)
{
    GraphChangeSet change;
    change.reset = true;
    return applyData(std::move(data), change);
}

Diagnostic GraphDocument::applyData(GraphData data, GraphChangeSet change)
{
    if (m_notifying)
        return {"graph.reentrant_edit", "Cannot edit during a change notification."};
    if (data.id.isNull())
        return {"graph.invalid_id", "The graph ID is invalid."};

    QSet<QUuid> nodeIds;
    QHash<QPair<QString, QString>, QUuid> instances;
    for (const NodeData &node : qAsConst(data.nodes)) {
        if (node.id.isNull() || nodeIds.contains(node.id))
            return {"graph.invalid_node_id", "Invalid or duplicate node ID.", node.id};
        const auto *type = m_registry.find(node.typeId);
        if (!type)
            return {"graph.unknown_type", QStringLiteral("Node type '%1' is not registered.").arg(node.typeId), node.id};
        if (!qIsFinite(node.position.x()) || !qIsFinite(node.position.y()))
            return {"graph.invalid_position", "The node position must be finite.", node.id};

        auto error = NodeRegistry::validateValues(type->parameters, node.parameterOverrides);
        if (error.code.isEmpty())
            error = NodeRegistry::validatePorts(type->resolvePorts ? type->resolvePorts(node) : type->ports,
                                                bool(type->resolvePorts));
        if (!error.code.isEmpty()) {
            error.nodeId = node.id;
            return error;
        }
        nodeIds.insert(node.id);

        if (type->instancePolicy != InstancePolicy::Multiple) {
            const auto key = instanceKey(node, *type);
            if (key.isNull())
                return {"graph.instance_key", tr("节点类型「%1」需要有效的实例标识。").arg(node.typeId), node.id};
            const auto identity = qMakePair(node.typeId, key);
            const auto previous = instances.constFind(identity);
            if (previous != instances.cend())
                return {"graph.instance_conflict", tr("节点类型「%1」有重复实例（%2 和 %3）。")
                    .arg(node.typeId, previous.value().toString(), node.id.toString()), node.id};
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
            return {"graph.invalid_connection_id", "Invalid or duplicate connection ID.", {}, connection.id.toString()};
        const Diagnostic error = validated.canConnect(connection.source, connection.target);
        if (!error.code.isEmpty())
            return error;
        validated.m_data.connections.append(connection);
        connectionIds.insert(connection.id);
    }

    m_data = std::move(validated.m_data);
    publishChange(std::move(change));
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

std::optional<PortDefinition> GraphDocument::port(const Endpoint &endpoint) const
{
    for (const PortDefinition &definition : nodePorts(endpoint.nodeId)) {
        if (definition.key == endpoint.portKey)
            return definition;
    }
    return std::nullopt;
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
        return {{}, {"graph.instance_key", tr("节点类型「%1」需要有效的实例标识。").arg(node.typeId), node.id}};
    for (const NodeData &other : m_data.nodes) {
        if (other.typeId == node.typeId && other.id != node.id && instanceKey(other, type) == key)
            return {{}, {"graph.instance_conflict", tr("节点类型「%1」已有匹配的实例。").arg(node.typeId), node.id}, other.id};
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
