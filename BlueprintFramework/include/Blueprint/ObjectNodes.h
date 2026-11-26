#pragma once

#include <Blueprint/GraphRuntime.h>
#include <Blueprint/NodeRegistry.h>

namespace Blueprint {

//! 对象由宿主持有。目标类型查询只解析稳定标识，目标暂不可用时仍应返回声明的类型。
struct ObjectNodeBindings
{
    using TargetType = std::function<QString(const QString &)>;
    using MethodCompletion = std::function<void(QVariantMap, Diagnostic)>;

    TargetType targetType;
    std::function<ValueResult(const QString &target, const QString &member)> read;
    std::function<Diagnostic(const QString &target, const QString &member, const QVariant &value)> write;
    //! 立即拒绝时返回诊断；受理后通过完成回调交付结果，允许异步完成。
    //! 成功结果须显式返回全部声明的输出，不使用输出声明的默认值补齐。
    std::function<Diagnostic(const QString &target, const QString &member, const QUuid &callId,
                             const QVariantMap &inputs, MethodCompletion complete)> invoke;
    RuntimeImplementations::Cancel cancel;
};

//! 在对象类型注册后调用。可指定设置和调用节点的初始成员；设置初始值沿用 value 参数键。
Diagnostic registerObjectNodes(NodeRegistry &registry, const ObjectNodeBindings::TargetType &targetType,
                               const ParameterDefinition &defaultWriteProperty = {},
                               const QString &defaultMethod = {});

//! 为运行实例准备对象操作。声明在注册表线程复制，宿主回调在运行线程调用。
void addObjectImplementations(RuntimeImplementations &implementations, const NodeRegistry &registry,
                              const ObjectNodeBindings &bindings);

//! 接口编辑器和运行端口使用同一键，替换同类型的目标时保留连线。
QString objectCallPortKey(PortDirection direction, const QString &type, const QString &method, const QString &key);

} // namespace Blueprint
