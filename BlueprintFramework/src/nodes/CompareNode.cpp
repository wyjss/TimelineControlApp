#include "CompareNode.h"

#include <Blueprint/NodeRegistry.h>

#include <QMetaType>

namespace Blueprint {

namespace {

const auto inputA = QStringLiteral("A");
const auto inputB = QStringLiteral("B");
const auto operatorKey = QStringLiteral("operator");
const auto valueKey = QStringLiteral("value");
const auto numberType = QStringLiteral("number");

class CompareExecutor final : public Executor
{
public:
    CompareExecutor() : Executor(Trigger::OnDemand) {}

    void start(const ExecutionContext &context, Completion done) override
    {
        const auto a = context.inputs.value(inputA);
        const auto b = context.inputs.value(inputB);
        const auto operation = context.parameters.value(operatorKey).toString();
        bool result = false;
        if (NodeRegistry::acceptsValue(numberType, a) && NodeRegistry::acceptsValue(numberType, b)) {
            const double left = a.toDouble();
            const double right = b.toDouble();
            if (operation == "gt")
                result = left > right;
            else if (operation == "ge")
                result = left >= right;
            else if (operation == "lt")
                result = left < right;
            else if (operation == "le")
                result = left <= right;
            else if (operation == "eq")
                result = left == right;
            else if (operation == "ne")
                result = left != right;
        } else if (a.userType() == b.userType()
                   && (a.userType() == QMetaType::QString || a.userType() == QMetaType::Bool)) {
            if (operation == "eq")
                result = a == b;
            else if (operation == "ne")
                result = a != b;
        }
        // 异类值及尚未支持的同类运算保留 false，不做隐式转换。
        done({{}, {{valueKey, result}}, {}});
    }
};

} // namespace

std::pair<NodeTypeDefinition, std::shared_ptr<Executor>> compareNode()
{
    const PortDefinition boolOutput{valueKey, PortDirection::Output, "bool", "输出"};
    return {
        {"demo.compare", "比较",
         {{inputA, PortDirection::Input, anyValueType}, {inputB, PortDirection::Input, anyValueType}, boolOutput},
         {{operatorKey, "string", QStringLiteral("eq"),
           {"gt", "ge", "lt", "le", "eq", "ne"}, "运算符"}}, "logic",
         InstancePolicy::Multiple, {}, "选择运算符比较两个输入", "≷"},
        std::make_shared<CompareExecutor>()
    };
}

} // namespace Blueprint
