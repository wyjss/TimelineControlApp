#pragma once

#include <QHash>
#include <QObject>
#include <QStringList>
#include <QUuid>
#include <QVariant>

#include <functional>
#include <memory>

namespace Blueprint {

class GraphDocument;

//! 由节点类型提供的单节点行为实例。
class NodeBehavior : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;

    virtual QVariantMap state() const = 0;
    //! 运行时属性由行为校验，写入成功返回空字符串。
    virtual QString writeState(const QString &key, const QVariant &value);
    //! 返回空字符串表示动作已受理。
    virtual QString invoke(const QString &actionKey) = 0;

signals:
    //! 状态提交后列出发生变化的键。
    void stateChanged(const QStringList &keys);
};

//! 按节点标识分发动作，持有同一张图的一份运行实例。
class GraphRuntime final : public QObject
{
    Q_OBJECT

public:
    //! 工厂在运行实例所属线程创建无父对象的行为。
    using Factory = std::function<std::unique_ptr<NodeBehavior>(const QVariantMap &parameters)>;
    using QObject::QObject;

    //! 使用当前参数快照启动。只有提供工厂的类型才创建行为。
    QString start(const GraphDocument &document, const QHash<QString, Factory> &factories);
    //! 按节点 ID 同步增删，保留仍在图中的行为及其状态。
    QString syncNodes(const GraphDocument &document, const QHash<QString, Factory> &factories);
    void stop();

    Q_INVOKABLE QVariantMap state(const QUuid &nodeId) const;
    QString writeState(const QUuid &nodeId, const QString &key, const QVariant &value);
    Q_INVOKABLE QString invoke(const QUuid &nodeId, const QString &actionKey);

signals:
    void stateChanged(const QUuid &nodeId, const QStringList &keys);
    void reset();

private:
    QHash<QUuid, NodeBehavior *> m_behaviors;
};

} // namespace Blueprint
