#include <Blueprint/WaitNodes.h>

#include <QPointer>
#include <QThread>
#include <QTimer>

#include <limits>
#include <memory>
#include <utility>

namespace Blueprint {

namespace {

const auto waitType = QStringLiteral("demo.wait");
const auto waitUntilType = QStringLiteral("demo.waitUntil");
const auto durationKey = QStringLiteral("durationMs");
const auto execOut = QStringLiteral("execOut");

ParameterDefinition durationParameter(bool waitUntil)
{
    const QString label = waitUntil ? "目标时间（毫秒）" : "时长（毫秒）";
    return {durationKey, "number", 1000.0, {}, label, {},
            0, std::numeric_limits<int>::max(), true};
}

class WaitExecutor final : public Executor, public std::enable_shared_from_this<WaitExecutor>
{
public:
    WaitExecutor(QObject &owner, QElapsedTimer timeline, bool waitUntil)
        : Executor(Trigger::Execution)
        , m_owner(&owner)
        , m_timeline(timeline)
        , m_waitUntil(waitUntil)
        , m_parameter(durationParameter(waitUntil))
    {}

    void start(const ExecutionContext &context, Completion complete) override
    {
        const auto duration = context.inputs.value(durationKey);
        if (!NodeRegistry::acceptsParameterValue(m_parameter, duration)) {
            complete({{}, {}, {"demo.invalid_wait_duration",
                               QStringLiteral("「%1」必须是 0 到 %2 的整数。")
                                   .arg(m_parameter.displayName).arg(m_parameter.maximum.toInt()),
                               context.nodeId, durationKey}});
            return;
        }
        if (m_waitUntil && !m_timeline.isValid()) {
            complete({{}, {}, {"demo.missing_automatic_start",
                               "等待全局时间需要从「开始（自动）」触发。",
                               context.nodeId}});
            return;
        }
        const qint64 remaining = duration.toInt() - (m_waitUntil ? m_timeline.elapsed() : 0);
        if (remaining <= 0) {
            complete({execOut, {}, {}});
            return;
        }
        if (!m_owner || m_owner->thread() != QThread::currentThread()) {
            complete({{}, {}, {"runtime.invalid_timer_owner",
                               "等待节点需要运行线程中的计时器所属对象。",
                               context.nodeId}});
            return;
        }

        auto *timer = new QTimer(m_owner.data());
        timer->setSingleShot(true);
        timer->setTimerType(Qt::PreciseTimer);
        const auto callId = context.callId;
        m_timers.insert(callId, timer);
        QObject::connect(timer, &QTimer::timeout, timer, [weak = weak_from_this(), timer, callId, complete = std::move(complete)] {
            timer->deleteLater();
            if (const auto executor = weak.lock()) {
                executor->m_timers.remove(callId);
                complete({execOut, {}, {}});
            }
        });
        timer->start(static_cast<int>(remaining));
    }

    void cancel(const QUuid &callId) override
    {
        if (auto timer = m_timers.take(callId)) {
            timer->stop();
            timer->deleteLater();
        }
    }

private:
    const QPointer<QObject> m_owner;
    const QElapsedTimer m_timeline;
    const bool m_waitUntil;
    const ParameterDefinition m_parameter;
    QHash<QUuid, QPointer<QTimer>> m_timers;
};

} // namespace

Diagnostic registerWaitNodes(NodeRegistry &registry)
{
    for (const auto &type : {waitType, waitUntilType}) {
        if (registry.find(type))
            return {"registry.duplicateType",
                    QStringLiteral("Node type '%1' is already registered.").arg(type), {}, type};
    }

    const PortDefinition execute{"execIn", PortDirection::Input, {},
                                 "执行", PortKind::Execution};
    const PortDefinition next{execOut, PortDirection::Output, {},
                              "继续", PortKind::Execution};
    for (const auto &type : {waitType, waitUntilType}) {
        const bool waitUntil = type == waitUntilType;
        const auto duration = durationParameter(waitUntil);
        const QString title = waitUntil ? "等待全局时间" : "等待时长";
        const QString description = waitUntil ? "等到本次自动入口启动后的指定时间" : "从到达此节点开始计时";
        NodeTypeDefinition definition{type, title, {execute, next}, {duration}, "flow",
                                      InstancePolicy::Multiple, {}, description, "◷"};
        definition.resolvePorts = [execute, next, duration](const NodeData &node) {
            const PortDefinition input{duration.key, PortDirection::Input, duration.valueTypeId,
                                       duration.displayName, PortKind::Data,
                                       node.parameterOverrides.value(duration.key, duration.defaultValue)};
            return QVector<PortDefinition>{execute, input, next};
        };
        const auto error = registry.add(definition);
        if (!error.code.isEmpty())
            return error;
    }
    return {};
}

void addWaitImplementations(RuntimeImplementations &implementations, QObject &timerOwner, QElapsedTimer timeline)
{
    for (const auto &type : {waitType, waitUntilType})
        implementations.executors.insert(type, std::make_shared<WaitExecutor>(timerOwner, timeline, type == waitUntilType));
}

} // namespace Blueprint
