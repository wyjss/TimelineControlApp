#pragma once

#include <Blueprint/NodeRegistry.h>

#include <QObject>
#include <QStringList>

namespace Blueprint {

struct EditResult
{
    QUuid id;
    //! 成功时为空，包含未产生实际变化的操作。
    QString error;
    //! 实例规则冲突时，指向文档中已占用该实例标识的节点。
    QUuid conflictingNodeId = {};
};

struct NodeChange
{
    QUuid nodeId;
    bool positionChanged = false;
    QStringList parameterKeys;
};

//! 一次成功提交的完整变更，删除节点时包含移除的关联连线。
struct GraphChangeSet
{
    quint64 revision = 0;
    //! 整图替换后，观察者应重建投影。
    bool reset = false;
    QVector<QUuid> addedNodeIds;
    QVector<QUuid> removedNodeIds;
    QVector<NodeChange> changedNodes;
    QVector<QUuid> addedConnectionIds;
    QVector<QUuid> removedConnectionIds;
};

//! 持有图数据并校验编辑操作。在文档所属线程使用。
class GraphDocument final : public QObject
{
    Q_OBJECT

public:
    //! 使用构建文档时的注册表快照，后续注册不会改变当前图的规则。
    explicit GraphDocument(const NodeRegistry &registry, QObject *parent = nullptr);

    const GraphData &data() const;
    quint64 revision() const;

    //! 返回借用的节点数据，文档编辑后应重新查询。
    const NodeData *findNode(const QUuid &nodeId) const;
    //! 查询文档使用的类型定义，定义在文档生命周期内保持稳定。
    const NodeTypeDefinition *findNodeType(const QString &typeId) const;

    //! 返回实际参数值，缺少覆盖时读取默认值。
    QVariant parameterValue(const QUuid &nodeId, const QString &key) const;
    //! 返回启动行为所需的参数快照，省略未设置的参数。
    QVariantMap parameterValues(const QUuid &nodeId) const;

    //! 检查连线。允许时返回空字符串。
    QString canConnect(const Endpoint &source, const Endpoint &target) const;

    //! 初始参数和新节点一次提交，供创建已绑定的节点使用。
    EditResult addNode(const QString &typeId, QPointF position, QVariantMap parameters = {});
    EditResult moveNode(QUuid nodeId, QPointF position);
    EditResult setParameter(QUuid nodeId, QString key, QVariant value);
    //! 原子更新相关参数。已接线的端口不能更改类型。
    EditResult setParameters(QUuid nodeId, const QVariantMap &values);
    EditResult connectPorts(const Endpoint &source, const Endpoint &target);
    EditResult removeConnection(QUuid connectionId);
    EditResult removeNode(QUuid nodeId);

    //! 校验完整图后一次替换。成功时返回空字符串。
    QString replaceData(GraphData data);
    QString loadFile(const QString &path);
    QString saveFile(const QString &path) const;

signals:
    //! 图数据已提交。订阅者应在此次通知结束后再发起编辑。
    void changed(const Blueprint::GraphChangeSet &changeSet);

private:
    int nodeIndex(const QUuid &nodeId) const;
    const PortDefinition *port(const Endpoint &endpoint) const;
    const ParameterDefinition *parameter(const NodeData &node, const QString &key) const;
    //! 受约束类型的实例键。空字符串代表单实例，空值代表缺少唯一键。
    QString instanceKey(const NodeData &node, const NodeTypeDefinition &type) const;
    EditResult checkInstance(const NodeData &node, const NodeTypeDefinition &type) const;
    void publishChange(GraphChangeSet changeSet);

    const NodeRegistry m_registry;
    GraphData m_data;
    quint64 m_revision = 0;
    bool m_notifying = false;
};

} // namespace Blueprint
