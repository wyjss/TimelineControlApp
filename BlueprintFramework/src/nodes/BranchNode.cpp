#include "BranchNode.h"

namespace Blueprint {

namespace {

const auto conditionKey = QStringLiteral("condition");
const auto trueExit = QStringLiteral("true");
const auto falseExit = QStringLiteral("false");

class BranchExecutor final : public Executor
{
public:
    BranchExecutor() : Executor(Trigger::Execution) {}

    void start(const ExecutionContext &context, Completion done) override
    {
        done({context.inputs.value(conditionKey).toBool() ? trueExit : falseExit, {}, {}});
    }
};

} // namespace

std::pair<NodeTypeDefinition, std::shared_ptr<Executor>> branchNode()
{
    return {
        {"demo.branch", "条件分支",
         {{"execIn", PortDirection::Input, {}, "执行", PortKind::Execution},
          {conditionKey, PortDirection::Input, "bool", "条件"},
          {trueExit, PortDirection::Output, {}, "成立", PortKind::Execution},
          {falseExit, PortDirection::Output, {}, "不成立", PortKind::Execution}},
         {}, "flow", InstancePolicy::Multiple, {},
         "根据布尔条件选择执行出口", "↗"},
        std::make_shared<BranchExecutor>()
    };
}

} // namespace Blueprint
