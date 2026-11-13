#pragma once

#include <Blueprint/GraphRuntime.h>

#include <utility>

namespace Blueprint {

std::pair<NodeTypeDefinition, std::shared_ptr<Executor>> branchNode();

} // namespace Blueprint
