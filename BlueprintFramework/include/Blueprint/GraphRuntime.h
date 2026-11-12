#pragma once

#include <Blueprint/GraphData.h>

#include <QHash>
#include <QObject>

#include <functional>
#include <memory>
#include <optional>

namespace Blueprint {

struct EvaluationResult
{
    QVariantMap outputs;
    Diagnostic error;
};

struct ValueResult
{
    QVariant value;
    Diagnostic error;
};

struct ExecutionContext
{
    QUuid runtimeId;
    QUuid executionId;
    QUuid callId;
    QUuid nodeId;
    QVariantMap parameters;
    QVariantMap inputs;
    QString inputPort;
};

struct ActionResult
{
    //! 留空表示不再推进此分支，否则必须是本节点的执行输出端口。
    QString exitPort;
    QVariantMap outputs;
    Diagnostic error;
};

struct RuntimeImplementations
{
    using Evaluator = std::function<EvaluationResult(const QVariantMap &parameters,
                                                     const QVariantMap &inputs)>;
    using Completion = std::function<void(ActionResult)>;
    using Action = std::function<void(const ExecutionContext &, Completion)>;
    using Cancel = std::function<void(const QUuid &callId)>;

    //! 计算函数在运行实例所属线程同步求值，每次求值可读取宿主的最新状态。
    QHash<QString, Evaluator> evaluators;
    //! 动作完成回调允许从任意线程调用，结果统一排队回运行实例所属线程。
    QHash<QString, Action> actions;
    //! 可取消的动作按调用标识取消；停止后其完成回调仍然安全，但不会推进图。
    QHash<QString, Cancel> cancellations;
};

struct ExecutionResult
{
    QUuid executionId;
    Diagnostic error;
};

//! 持有启动时的图快照。公共方法只能在所属线程调用；每个实例同时执行一条执行链。
class GraphRuntime final : public QObject
{
    Q_OBJECT

public:
    explicit GraphRuntime(QObject *parent = nullptr);
    ~GraphRuntime() override;

    //! 数据依赖和执行连线分别要求无环；启动后编辑图不会改变此运行实例。
    Diagnostic start(const GraphSnapshot &snapshot, const RuntimeImplementations &implementations);
    //! 先使调用失效，再取消宿主请求；正在执行时发出取消完成通知。
    void stop();

    QUuid runtimeId() const { return m_runtimeId; }
    //! 数据输入沿连线取值，未连线时使用端口默认值；一次求值内共享上游计算结果。
    ValueResult evaluate(const Endpoint &endpoint);
    //! 从执行输出端口触发，动作选择出口后沿唯一连线继续；下一次执行前清空动作输出。
    ExecutionResult execute(const Endpoint &executionOutput);

signals:
    //! 成功的诊断 code 为空；完成不早于 execute 返回，stop 清理后同步通知取消。
    void executionFinished(const QUuid &executionId, const Blueprint::Diagnostic &error);

private:
    struct CompletionGate;

    //! 公开求值和节点输入复用完整端点解析、默认值与上游求值规则。
    ValueResult evaluateValue(const Endpoint &endpoint, QHash<QUuid, QVariantMap> &values);
    //! 递归求值共享缓存，保证菱形依赖只计算一次，并校验节点完整输出。
    EvaluationResult evaluateNode(const QUuid &nodeId, QHash<QUuid, QVariantMap> &values);
    //! 求值和动作完成共同使用输出契约，避免两条路径接受不同的数据。
    Diagnostic validateOutputs(const SnapshotNode &node, const QVariantMap &outputs) const;
    //! 执行推进和异步回调分别进入此处，始终只发起一个宿主调用。
    void advance();
    //! 接收投回所属线程的动作结果，校验调用身份并继续执行。
    void complete(const QUuid &runtimeId, const QUuid &executionId, const QUuid &callId,
                  ActionResult result);
    //! 成功、求值失败和动作失败都统一结束本次执行。
    void finish(const Diagnostic &error);

    std::shared_ptr<CompletionGate> m_completionGate;
    QUuid m_runtimeId;
    GraphSnapshot m_snapshot;
    RuntimeImplementations m_implementations;
    QHash<QUuid, int> m_nodeIndexes;
    QHash<QUuid, QHash<QString, Endpoint>> m_dataSources;
    QHash<QUuid, QHash<QString, Endpoint>> m_executionTargets;
    QHash<QUuid, QVariantMap> m_actionOutputs;
    QUuid m_executionId;
    QUuid m_callId;
    QUuid m_activeNodeId;
    std::optional<Endpoint> m_pendingInput;
};

} // namespace Blueprint
