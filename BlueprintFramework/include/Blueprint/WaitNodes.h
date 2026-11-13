#pragma once

#include <Blueprint/GraphRuntime.h>
#include <Blueprint/NodeRegistry.h>

#include <QElapsedTimer>

namespace Blueprint {

//! 注册两种等待节点的定义。发现类型冲突时保留原状态。
Diagnostic registerWaitNodes(NodeRegistry &registry);

//! 为一次运行提供等待动作。计时器由运行线程中的 timerOwner 持有，owner 必须至少存活到运行结束。
//! timeline 已启动时用它作为全局等待的时间零点。未提供时，相对等待仍可用。
void addWaitImplementations(RuntimeImplementations &implementations, QObject &timerOwner,
                            QElapsedTimer timeline = {});

} // namespace Blueprint
