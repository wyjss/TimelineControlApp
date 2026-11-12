#include <Blueprint/GraphRuntime.h>

#include <Blueprint/GraphDocument.h>

#include <QSet>

#include <utility>
#include <vector>

namespace Blueprint {

QString NodeBehavior::writeState(const QString &key, const QVariant &)
{
    return QStringLiteral("Property '%1' is not writable.").arg(key);
}

QString GraphRuntime::start(const GraphDocument &document, const QHash<QString, Factory> &factories)
{
    if (!m_behaviors.isEmpty())
        return QStringLiteral("Stop the current graph before starting it again.");
    return syncNodes(document, factories);
}

QString GraphRuntime::syncNodes(const GraphDocument &document, const QHash<QString, Factory> &factories)
{
    QSet<QUuid> retainedIds;
    std::vector<std::pair<QUuid, std::unique_ptr<NodeBehavior>>> behaviors;
    for (const NodeData &node : document.data().nodes) {
        const auto factory = factories.constFind(node.typeId);
        if (factory == factories.cend())
            continue;
        retainedIds.insert(node.id);
        if (m_behaviors.contains(node.id))
            continue;
        auto behavior = factory.value() ? factory.value()(document.parameterValues(node.id)) : nullptr;
        if (!behavior)
            return QStringLiteral("Cannot create behavior for '%1'.").arg(node.typeId);
        behaviors.emplace_back(node.id, std::move(behavior));
    }

    bool changed = !behaviors.empty();
    for (auto it = m_behaviors.begin(); it != m_behaviors.end();) {
        if (retainedIds.contains(it.key())) {
            ++it;
            continue;
        }
        NodeBehavior *behavior = it.value();
        it = m_behaviors.erase(it);
        disconnect(behavior, nullptr, this, nullptr);
        behavior->deleteLater();
        changed = true;
    }

    for (auto &[nodeId, behavior] : behaviors) {
        const QUuid id = nodeId;
        behavior->setParent(this);
        connect(behavior.get(), &NodeBehavior::stateChanged, this, [this, id](const QStringList &keys) {
            emit stateChanged(id, keys);
        });
        m_behaviors.insert(id, behavior.release());
    }
    if (changed)
        emit reset();
    return {};
}

void GraphRuntime::stop()
{
    if (m_behaviors.isEmpty())
        return;

    const auto behaviors = std::exchange(m_behaviors, QHash<QUuid, NodeBehavior *>{});
    for (NodeBehavior *behavior : behaviors) {
        // 停止可以从状态回调发起，延迟销毁当前仍在执行的行为。
        disconnect(behavior, nullptr, this, nullptr);
        behavior->deleteLater();
    }
    emit reset();
}

QVariantMap GraphRuntime::state(const QUuid &nodeId) const
{
    const NodeBehavior *behavior = m_behaviors.value(nodeId);
    return behavior ? behavior->state() : QVariantMap{};
}

QString GraphRuntime::invoke(const QUuid &nodeId, const QString &actionKey)
{
    NodeBehavior *behavior = m_behaviors.value(nodeId);
    if (!behavior)
        return QStringLiteral("The node has no active behavior.");
    return behavior->invoke(actionKey);
}

QString GraphRuntime::writeState(const QUuid &nodeId, const QString &key, const QVariant &value)
{
    NodeBehavior *behavior = m_behaviors.value(nodeId);
    if (!behavior)
        return QStringLiteral("The node has no active behavior.");
    return behavior->writeState(key, value);
}

} // namespace Blueprint
