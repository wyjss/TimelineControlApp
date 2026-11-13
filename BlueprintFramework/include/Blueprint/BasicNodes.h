#pragma once

#include <Blueprint/GraphRuntime.h>
#include <Blueprint/NodeRegistry.h>

namespace Blueprint {

//! 宿主初始化时显式注册基础节点及其运行实现。发现类型或实现冲突时保留原状态。
Diagnostic registerBasicNodes(NodeRegistry &registry, RuntimeImplementations &implementations);

} // namespace Blueprint
