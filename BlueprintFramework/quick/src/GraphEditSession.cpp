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
      m_history{document.data()}, m_graphId(document.data().id)
{
    static const bool initialized = (initializeBlueprintQuickResources(), true);
    Q_UNUSED(initialized);
    connect(&m_document, &GraphDocument::changed, this, &GraphEditSession::applyChange);
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
    case ExecutionPortsRole: {
        QStringList ports;
        for (const PortDefinition &port : m_document.findNodeType(node.typeId)->ports) {
            if (port.valueTypeId == executionPortType)
                ports.append(port.key);
        }
        return ports;
    }
    case InputsRole:
    case OutputsRole: {
        QStringList ports;
        const auto direction = role == InputsRole ? PortDirection::Input : PortDirection::Output;
        for (const PortDefinition &port : m_document.findNodeType(node.typeId)->ports) {
            if (port.direction == direction)
                ports.append(port.key);
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
            {ParametersRole, "nodeParameters"}, {ExecutionPortsRole, "executionPorts"}};
}

QString GraphEditSession::graphId() const { return m_graphId.toString(QUuid::WithoutBraces); }

QVariantList GraphEditSession::connections() const
{
    QVariantList links;
    links.reserve(m_document.data().connections.size());
    for (const ConnectionData &link : m_document.data().connections) {
        links.append(QVariantMap{
            {QStringLiteral("id"), link.id.toString(QUuid::WithoutBraces)},
            {QStringLiteral("source"), link.source.nodeId.toString(QUuid::WithoutBraces)},
            {QStringLiteral("sourcePort"), link.source.portKey},
            {QStringLiteral("target"), link.target.nodeId.toString(QUuid::WithoutBraces)},
            {QStringLiteral("targetPort"), link.target.portKey}
        });
    }
    return links;
}

QString GraphEditSession::error() const { return m_error; }
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

bool GraphEditSession::connectPorts(const QString &sourceId, const QString &sourcePort,
                                     const QString &targetId, const QString &targetPort)
{
    return report(m_document.connectPorts({QUuid(sourceId), sourcePort}, {QUuid(targetId), targetPort}).error);
}

void GraphEditSession::removeConnection(const QString &connectionId)
{
    report(m_document.removeConnection(QUuid(connectionId)).error);
}

void GraphEditSession::disconnectInput(const QString &nodeId, const QString &portKey)
{
    const QUuid id(nodeId);
    for (const ConnectionData &link : m_document.data().connections) {
        if (link.target.nodeId == id && link.target.portKey == portKey) {
            report(m_document.removeConnection(link.id).error);
            return;
        }
    }
}

void GraphEditSession::undo() { restoreHistory(m_historyIndex - 1); }
void GraphEditSession::redo() { restoreHistory(m_historyIndex + 1); }

void GraphEditSession::applyChange(const GraphChangeSet &change)
{
    if (change.reset) {
        beginResetModel();
        m_nodes = m_document.data().nodes;
        endResetModel();
        if (!m_restoring) {
            m_history = {m_document.data()};
            m_historyIndex = 0;
            m_savedIndex = 0;
            report({});
        }
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
        for (const QUuid &id : change.addedNodeIds) {
            const int row = m_nodes.size();
            beginInsertRows({}, row, row);
            m_nodes.append(*m_document.findNode(id));
            endInsertRows();
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
                emit dataChanged(index(row), index(row), roles);
                break;
            }
        }
        if (m_savedIndex > m_historyIndex)
            m_savedIndex = -1;
        m_history.resize(m_historyIndex + 1);
        m_history.append(m_document.data());
        ++m_historyIndex;
    }

    if (change.reset || !change.addedConnectionIds.isEmpty() || !change.removedConnectionIds.isEmpty())
        emit connectionsChanged();
    if (!m_restoring)
        emit historyChanged();
    emit graphChanged();
}

bool GraphEditSession::report(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
    return error.isEmpty();
}

void GraphEditSession::restoreHistory(int index)
{
    if (index < 0 || index >= m_history.size())
        return;
    QString error;
    {
        QScopedValueRollback<bool> restoring(m_restoring, true);
        error = m_document.replaceData(m_history.at(index));
    }
    if (error.isEmpty()) {
        m_historyIndex = index;
        emit historyChanged();
    }
    report(error);
}

} // namespace Blueprint
