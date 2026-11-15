#include <Blueprint/GraphEditSession.h>

#include <QScopedValueRollback>

// Qt 资源初始化需要在全局命名空间调用，静态库也能显式链接资源。
static void initializeBlueprintQuickResources()
{
    Q_INIT_RESOURCE(BlueprintQuick);
}

namespace Blueprint {

GraphEditSession::GraphEditSession(GraphDocument &document, QObject *parent)
    : QAbstractListModel(parent), m_document(document), m_nodes(document.data().nodes),
      m_history{{document.data(), {}}}, m_graphId(document.data().id)
{
    static const bool initialized = (initializeBlueprintQuickResources(), true);
    Q_UNUSED(initialized);
    connect(&m_document, &GraphDocument::changed, this, &GraphEditSession::applyChange);
    connect(&m_document, &GraphDocument::typesChanged, this, &GraphEditSession::typesChanged);
}

int GraphEditSession::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_nodes.size();
}

QVariant GraphEditSession::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_nodes.size())
        return {};
    const NodeData &node = m_nodes.at(index.row());
    switch (role) {
    case IdRole: return node.id.toString(QUuid::WithoutBraces);
    case TypeRole: return node.typeId;
    case TitleRole: return m_document.findNodeType(node.typeId)->displayName;
    case PositionRole: return node.position;
    case InputsRole:
    case OutputsRole: {
        QVariantList ports;
        const auto direction = role == InputsRole ? PortDirection::Input : PortDirection::Output;
        for (const PortDefinition &port : m_document.nodePorts(node.id)) {
            if (port.direction == direction)
                ports.append(QVariantMap{{QStringLiteral("key"), port.key},
                    {QStringLiteral("title"), port.displayName.isEmpty() ? port.key : port.displayName},
                    {QStringLiteral("valueTypeId"), port.valueTypeId},
                    {QStringLiteral("execution"), port.kind == PortKind::Execution},
                    {QStringLiteral("data"), port.kind != PortKind::Execution},
                    {QStringLiteral("executionCapable"), port.kind != PortKind::Data}});
        }
        return ports;
    }
    case ParametersRole: {
        QVariantMap parameters;
        for (const ParameterDefinition &definition : m_document.findNodeType(node.typeId)->parameters)
            parameters.insert(definition.key, node.parameterOverrides.value(definition.key, definition.defaultValue));
        return parameters;
    }
    default: return {};
    }
}

QHash<int, QByteArray> GraphEditSession::roleNames() const
{
    return {{IdRole, "nodeId"}, {TypeRole, "nodeType"}, {TitleRole, "nodeTitle"},
            {PositionRole, "nodePosition"}, {InputsRole, "inputPorts"}, {OutputsRole, "outputPorts"},
            {ParametersRole, "nodeParameters"}};
}

QString GraphEditSession::graphId() const { return m_graphId.toString(QUuid::WithoutBraces); }

QVariantList GraphEditSession::connections() const
{
    QVariantList links;
    links.reserve(m_document.data().connections.size());
    for (const ConnectionData &link : m_document.data().connections) {
        bool execution = false;
        for (const PortDefinition &port : m_document.nodePorts(link.target.nodeId)) {
            if (port.key == link.target.portKey) {
                execution = port.kind == PortKind::Execution;
                break;
            }
        }
        links.append(QVariantMap{
            {QStringLiteral("id"), link.id.toString(QUuid::WithoutBraces)},
            {QStringLiteral("execution"), execution},
            {QStringLiteral("source"), link.source.nodeId.toString(QUuid::WithoutBraces)},
            {QStringLiteral("sourcePort"), link.source.portKey},
            {QStringLiteral("target"), link.target.nodeId.toString(QUuid::WithoutBraces)},
            {QStringLiteral("targetPort"), link.target.portKey}
        });
    }
    return links;
}

QString GraphEditSession::error() const { return m_error.message; }

QVariantMap GraphEditSession::diagnostic() const
{
    return {{QStringLiteral("code"), m_error.code}, {QStringLiteral("message"), m_error.message},
            {QStringLiteral("nodeId"), m_error.nodeId.toString(QUuid::WithoutBraces)},
            {QStringLiteral("key"), m_error.key}};
}

QVariantList GraphEditSession::nodeTypes() const
{
    QVariantList result;
    for (const NodeTypeDefinition &type : m_document.registry().definitions()) {
        QVariantList parameters;
        for (const ParameterDefinition &parameter : type.parameters) {
            parameters.append(QVariantMap{{QStringLiteral("key"), parameter.key},
                {QStringLiteral("title"), parameter.displayName.isEmpty() ? parameter.key : parameter.displayName},
                {QStringLiteral("valueTypeId"), parameter.valueTypeId},
                {QStringLiteral("defaultValue"), parameter.defaultValue},
                {QStringLiteral("allowedValues"), parameter.allowedValues},
                {QStringLiteral("description"), parameter.description},
                {QStringLiteral("minimum"), parameter.minimum}, {QStringLiteral("maximum"), parameter.maximum},
                {QStringLiteral("integer"), parameter.integer}});
        }
        QVariantList properties;
        for (const PropertyDefinition &property : type.properties) {
            properties.append(QVariantMap{{QStringLiteral("key"), property.value.key},
                {QStringLiteral("title"), property.value.displayName.isEmpty() ? property.value.key : property.value.displayName},
                {QStringLiteral("valueTypeId"), property.value.valueTypeId},
                {QStringLiteral("writable"), property.writable}});
        }
        result.append(QVariantMap{{QStringLiteral("typeId"), type.typeId},
            {QStringLiteral("title"), type.displayName}, {QStringLiteral("categoryId"), type.categoryId},
            {QStringLiteral("description"), type.description}, {QStringLiteral("symbol"), type.symbol},
            {QStringLiteral("parameters"), parameters}, {QStringLiteral("properties"), properties}});
    }
    return result;
}
bool GraphEditSession::canUndo() const { return m_historyIndex > 0; }
bool GraphEditSession::canRedo() const { return m_historyIndex + 1 < m_history.size(); }
bool GraphEditSession::modified() const { return m_savedIndex != m_historyIndex; }

void GraphEditSession::markSaved()
{
    if (modified()) {
        m_savedIndex = m_historyIndex;
        emit historyChanged();
    }
}

bool GraphEditSession::containsNode(const QString &nodeId) const
{
    return m_document.findNode(QUuid(nodeId)) != nullptr;
}

QString GraphEditSession::addNode(const QString &typeId, QPointF position)
{
    const EditResult result = m_document.addNode(typeId, position);
    return report(result.error) ? result.id.toString(QUuid::WithoutBraces) : QString();
}

QString GraphEditSession::placeNode(const QString &typeId, QPointF position, const QVariantMap &parameters)
{
    const EditResult result = m_document.addNode(typeId, position, parameters);
    if (!result.conflictingNodeId.isNull()) {
        report({});
        return result.conflictingNodeId.toString(QUuid::WithoutBraces);
    }
    return report(result.error) ? result.id.toString(QUuid::WithoutBraces) : QString();
}

void GraphEditSession::moveNode(const QString &nodeId, QPointF position)
{
    report(m_document.moveNode(QUuid(nodeId), position).error);
}

void GraphEditSession::removeNode(const QString &nodeId)
{
    report(m_document.removeNode(QUuid(nodeId)).error);
}

bool GraphEditSession::setParameter(const QString &nodeId, const QString &key, const QVariant &value)
{
    return report(m_document.setParameter(QUuid(nodeId), key, value).error);
}

bool GraphEditSession::setParameters(const QString &nodeId, const QVariantMap &values)
{
    return report(m_document.setParameters(QUuid(nodeId), values).error);
}

bool GraphEditSession::resetParameter(const QString &nodeId, const QString &key)
{
    return report(m_document.setParameter(QUuid(nodeId), key, {}).error);
}

QString GraphEditSession::canConnect(const QString &sourceId, const QString &sourcePort,
                                     const QString &targetId, const QString &targetPort,
                                     const QString &connectionToIgnore) const
{
    return m_document.canConnect({QUuid(sourceId), sourcePort}, {QUuid(targetId), targetPort},
                                 QUuid(connectionToIgnore)).message;
}

bool GraphEditSession::connectPorts(const QString &sourceId, const QString &sourcePort,
                                     const QString &targetId, const QString &targetPort)
{
    return report(m_document.connectPorts({QUuid(sourceId), sourcePort}, {QUuid(targetId), targetPort}).error);
}

bool GraphEditSession::reconnectConnection(const QString &connectionId,
                                             const QString &sourceId, const QString &sourcePort,
                                             const QString &targetId, const QString &targetPort)
{
    return report(m_document.reconnectConnection(QUuid(connectionId),
        {QUuid(sourceId), sourcePort}, {QUuid(targetId), targetPort}).error);
}

void GraphEditSession::removeConnection(const QString &connectionId)
{
    report(m_document.removeConnection(QUuid(connectionId)).error);
}

void GraphEditSession::disconnectInput(const QString &nodeId, const QString &portKey)
{
    const QUuid id(nodeId);
    QUuid connectionId;
    for (const ConnectionData &link : m_document.data().connections) {
        if (link.target.nodeId != id || link.target.portKey != portKey)
            continue;
        if (!connectionId.isNull())
            return;
        connectionId = link.id;
    }
    if (!connectionId.isNull())
        report(m_document.removeConnection(connectionId).error);
}

void GraphEditSession::undo() { restoreHistory(m_historyIndex - 1); }
void GraphEditSession::redo() { restoreHistory(m_historyIndex + 1); }

void GraphEditSession::applyChange(const GraphChangeSet &change)
{
    if (change.reset) {
        beginResetModel();
        m_nodes = m_document.data().nodes;
        endResetModel();
        m_history = {{m_document.data(), {}}};
        m_historyIndex = 0;
        m_savedIndex = 0;
        report({});
        if (m_graphId != m_document.data().id) {
            m_graphId = m_document.data().id;
            emit graphIdChanged();
        }
    } else {
        for (int row = m_nodes.size() - 1; row >= 0; --row) {
            if (change.removedNodeIds.contains(m_nodes.at(row).id)) {
                beginRemoveRows({}, row, row);
                m_nodes.removeAt(row);
                endRemoveRows();
            }
        }
        if (!change.addedNodeIds.isEmpty()) {
            const auto &nodes = m_document.data().nodes;
            for (int row = 0; row < nodes.size(); ++row) {
                if (!change.addedNodeIds.contains(nodes.at(row).id))
                    continue;
                beginInsertRows({}, row, row);
                m_nodes.insert(row, nodes.at(row));
                endInsertRows();
            }
        }
        for (const NodeChange &node : change.changedNodes) {
            for (int row = 0; row < m_nodes.size(); ++row) {
                if (m_nodes.at(row).id != node.nodeId)
                    continue;
                m_nodes[row] = *m_document.findNode(node.nodeId);
                QVector<int> roles;
                if (node.positionChanged)
                    roles.append(PositionRole);
                if (!node.parameterKeys.isEmpty())
                    roles.append(ParametersRole);
                if (node.portsChanged)
                    roles << InputsRole << OutputsRole;
                emit dataChanged(index(row), index(row), roles);
                break;
            }
        }
        if (!m_restoring) {
            if (m_savedIndex > m_historyIndex)
                m_savedIndex = -1;
            m_history.resize(m_historyIndex + 1);
            m_history.append({m_document.data(), change});
            ++m_historyIndex;
            constexpr int maxUndoSteps = 100;
            if (m_historyIndex > maxUndoSteps) {
                m_history.removeFirst();
                --m_historyIndex;
                if (m_savedIndex >= 0)
                    --m_savedIndex;
            }
        }
    }

    if (change.reset || !change.addedConnectionIds.isEmpty() || !change.removedConnectionIds.isEmpty())
        emit connectionsChanged();
    if (!m_restoring)
        emit historyChanged();
    emit graphChanged();
}

bool GraphEditSession::report(const Diagnostic &error)
{
    if (m_error.code != error.code || m_error.message != error.message
        || m_error.nodeId != error.nodeId || m_error.key != error.key) {
        m_error = error;
        emit errorChanged();
    }
    return error.code.isEmpty();
}

void GraphEditSession::restoreHistory(int index)
{
    if (index < 0 || index >= m_history.size())
        return;
    GraphChangeSet change = m_history.at(qMax(index, m_historyIndex)).change;
    if (index < m_historyIndex) {
        change.addedNodeIds.swap(change.removedNodeIds);
        change.addedConnectionIds.swap(change.removedConnectionIds);
    }
    Diagnostic error;
    {
        QScopedValueRollback<bool> restoring(m_restoring, true);
        error = m_document.applyData(m_history.at(index).data, change);
    }
    if (error.code.isEmpty()) {
        m_historyIndex = index;
        emit historyChanged();
    }
    report(error);
}

} // namespace Blueprint
