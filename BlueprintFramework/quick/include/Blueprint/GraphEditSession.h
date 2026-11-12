#pragma once

#include <Blueprint/GraphDocument.h>

#include <QAbstractListModel>

namespace Blueprint {

//! 同一文档的编辑视图共享一个会话。文档应比会话存活更久。
class GraphEditSession final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString graphId READ graphId NOTIFY graphIdChanged)
    Q_PROPERTY(QVariantList connections READ connections NOTIFY connectionsChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QVariantMap diagnostic READ diagnostic NOTIFY errorChanged)
    Q_PROPERTY(QVariantList nodeTypes READ nodeTypes NOTIFY typesChanged)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY historyChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY historyChanged)
    Q_PROPERTY(bool modified READ modified NOTIFY historyChanged)

public:
    explicit GraphEditSession(GraphDocument &document, QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString graphId() const;
    QVariantList connections() const;
    QString error() const;
    QVariantMap diagnostic() const;
    QVariantList nodeTypes() const;
    bool canUndo() const;
    bool canRedo() const;
    bool modified() const;
    void markSaved();

    Q_INVOKABLE bool containsNode(const QString &nodeId) const;
    Q_INVOKABLE QString addNode(const QString &typeId, QPointF position);
    //! 放置新节点，实例规则冲突时返回已放置的节点 ID。
    Q_INVOKABLE QString placeNode(const QString &typeId, QPointF position, const QVariantMap &parameters);
    Q_INVOKABLE void moveNode(const QString &nodeId, QPointF position);
    Q_INVOKABLE void removeNode(const QString &nodeId);
    Q_INVOKABLE bool setParameter(const QString &nodeId, const QString &key, const QVariant &value);
    Q_INVOKABLE bool setParameters(const QString &nodeId, const QVariantMap &values);
    Q_INVOKABLE bool resetParameter(const QString &nodeId, const QString &key);
    //! 预检返回空字符串表示允许，不改变文档或会话错误。重接时排除原连线。
    Q_INVOKABLE QString canConnect(const QString &sourceId, const QString &sourcePort,
                                   const QString &targetId, const QString &targetPort,
                                   const QString &connectionToIgnore = {}) const;
    Q_INVOKABLE bool connectPorts(const QString &sourceId, const QString &sourcePort,
                                  const QString &targetId, const QString &targetPort);
    Q_INVOKABLE bool reconnectConnection(const QString &connectionId,
                                          const QString &sourceId, const QString &sourcePort,
                                          const QString &targetId, const QString &targetPort);
    Q_INVOKABLE void removeConnection(const QString &connectionId);
    Q_INVOKABLE void disconnectInput(const QString &nodeId, const QString &portKey);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();

signals:
    void graphIdChanged();
    void typesChanged();
    void connectionsChanged();
    void errorChanged();
    void historyChanged();
    //! 整批模型变更已应用，视图可以清理失效的选择和连线预览。
    void graphChanged();

private:
    enum Role { IdRole = Qt::UserRole + 1, TypeRole, TitleRole, PositionRole,
                InputsRole, OutputsRole, ParametersRole };

    void applyChange(const GraphChangeSet &change);
    bool report(const Diagnostic &error);
    void restoreHistory(int index);

    GraphDocument &m_document;
    QVector<NodeData> m_nodes;
    QVector<GraphData> m_history;
    QUuid m_graphId;
    int m_historyIndex = 0;
    int m_savedIndex = 0;
    bool m_restoring = false;
    Diagnostic m_error;
};

} // namespace Blueprint
