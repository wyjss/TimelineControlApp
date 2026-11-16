#include <Blueprint/BasicNodes.h>

#include "BranchNode.h"
#include "CompareNode.h"

namespace Blueprint {

namespace {

// 沿用原示例的类型 ID 和端口键，已有图可以直接加载。
const auto constantType = QStringLiteral("demo.constant");
const auto stringConstantType = QStringLiteral("demo.stringConstant");
const auto optionConstantType = QStringLiteral("demo.optionConstant");
const auto boolConstantType = QStringLiteral("demo.boolConstant");
const auto additionType = QStringLiteral("demo.add");
const auto greaterType = QStringLiteral("demo.greater");
const auto lessType = QStringLiteral("demo.less");
const auto equalType = QStringLiteral("demo.equal");
const auto andType = QStringLiteral("demo.and");
const auto orType = QStringLiteral("demo.or");
const auto notType = QStringLiteral("demo.not");
const auto parallelJoinType = QStringLiteral("blueprint.parallelJoin");
const auto nextKey = QStringLiteral("next");
const auto valueCategory = QStringLiteral("values");
const auto logicCategory = QStringLiteral("logic");
const auto valueKey = QStringLiteral("value");
const auto inputA = QStringLiteral("A");
const auto inputB = QStringLiteral("B");
const auto numberType = QStringLiteral("number");
const auto stringType = QStringLiteral("string");
const auto boolType = QStringLiteral("bool");
const auto autoOption = QStringLiteral("auto");
const auto manualOption = QStringLiteral("manual");

class ConstantExecutor final : public Executor
{
public:
    ConstantExecutor() : Executor(Trigger::OnDemand) {}

    void start(const ExecutionContext &context, Completion done) override
    {
        done({{}, {{valueKey, context.parameters.value(valueKey)}}, {}});
    }
};

class BasicOperationExecutor final : public Executor
{
public:
    explicit BasicOperationExecutor(const QString &typeId)
        : Executor(Trigger::OnDemand), m_typeId(typeId)
    {}

    void start(const ExecutionContext &context, Completion done) override
    {
        const auto a = context.inputs.value(inputA);
        const auto b = context.inputs.value(inputB);
        QVariant output;
        if (m_typeId == additionType)
            output = a.toDouble() + b.toDouble();
        else if (m_typeId == greaterType)
            output = a.toDouble() > b.toDouble();
        else if (m_typeId == lessType)
            output = a.toDouble() < b.toDouble();
        else if (m_typeId == equalType)
            output = a.toDouble() == b.toDouble();
        else if (m_typeId == andType)
            output = a.toBool() && b.toBool();
        else if (m_typeId == orType)
            output = a.toBool() || b.toBool();
        else
            output = !a.toBool();
        done({{}, {{valueKey, output}}, {}});
    }

private:
    const QString m_typeId;
};

class ParallelJoinExecutor final : public Executor
{
public:
    ParallelJoinExecutor() : Executor(Trigger::AllExecutionInputs) {}

    void start(const ExecutionContext &, Completion done) override
    {
        done({nextKey, {}, {}});
    }
};

} // namespace

Diagnostic registerBasicNodes(NodeRegistry &registry, RuntimeImplementations &implementations)
{
    const PortDefinition output{valueKey, PortDirection::Output, numberType, "输出"};
    const PortDefinition textOutput{valueKey, PortDirection::Output, stringType, "输出"};
    const PortDefinition boolOutput{valueKey, PortDirection::Output, boolType, "输出"};
    const PortDefinition numberA{inputA, PortDirection::Input, numberType};
    const PortDefinition numberB{inputB, PortDirection::Input, numberType};
    const PortDefinition boolA{inputA, PortDirection::Input, boolType};
    const PortDefinition boolB{inputB, PortDirection::Input, boolType};
    const auto [branchDefinition, branchExecutor] = branchNode();
    const auto [compareDefinition, compareExecutor] = compareNode();
    QVector<NodeTypeDefinition> definitions{
        {constantType, "数值常量", {output}, {{valueKey, numberType, 0.0, {}, "数值"}}, valueCategory,
         InstancePolicy::Multiple, {}, "输出可编辑的数值", "#"},
        {stringConstantType, "字符串常量", {textOutput},
         {{valueKey, stringType, QStringLiteral("示例文本"), {}, "文本"}}, valueCategory,
         InstancePolicy::Multiple, {}, "输出文本", "T"},
        {optionConstantType, "选项常量", {textOutput},
         {{valueKey, stringType, autoOption, {autoOption, manualOption}, "选项"}}, valueCategory,
         InstancePolicy::Multiple, {}, "输出所选选项的值", "▾"},
        {boolConstantType, "布尔常量", {boolOutput}, {{valueKey, boolType, false, {}, "布尔值"}}, valueCategory,
         InstancePolicy::Multiple, {}, "输出真或假", "✓"},
        {additionType, "加法", {numberA, numberB, output}, {}, logicCategory,
         InstancePolicy::Multiple, {}, "相加两个数值输入", "+"},
        compareDefinition,
        {greaterType, "大于", {numberA, numberB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, "判断 A 是否大于 B", ">"},
        {lessType, "小于", {numberA, numberB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, "判断 A 是否小于 B", "<"},
        {equalType, "等于", {numberA, numberB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, "判断 A 是否等于 B", "="},
        {andType, "且", {boolA, boolB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, "两个输入都为真", "∧"},
        {orType, "或", {boolA, boolB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, "至少一个输入为真", "∨"},
        {notType, "非", {boolA, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, "对输入取反", "¬"},
        branchDefinition,
        {parallelJoinType, "等待并行汇合",
         {{inputA, PortDirection::Input, {}, "A", PortKind::Execution},
          {inputB, PortDirection::Input, {}, "B", PortKind::Execution},
          {nextKey, PortDirection::Output, {}, "继续", PortKind::Execution}},
         {}, "flow", InstancePolicy::Multiple, {}, "两路执行输入都到达后继续一次", "⇥"},
    };
    for (const auto &definition : qAsConst(definitions)) {
        const auto &type = definition.typeId;
        if (registry.find(type))
            return {"registry.duplicateType",
                    QStringLiteral("Node type '%1' is already registered.").arg(type), {}, type};
        if (implementations.evaluators.contains(type) || implementations.actions.contains(type)
            || implementations.cancellations.contains(type) || implementations.executors.contains(type)) {
            return {"runtime.duplicate_implementation",
                    QStringLiteral("Node type '%1' already has a runtime implementation.").arg(type), {}, type};
        }
    }

    for (auto &definition : definitions) {
        const auto &type = definition.typeId;
        if (definition.categoryId == valueCategory) {
            for (const auto &parameter : definition.parameters)
                definition.properties.append({parameter, false});
        }
        const auto error = registry.add(definition);
        if (!error.code.isEmpty())
            return error;

        if (definition.categoryId == valueCategory) {
            implementations.executors.insert(type, std::make_shared<ConstantExecutor>());
        } else if (type == branchDefinition.typeId) {
            implementations.executors.insert(type, branchExecutor);
        } else if (type == compareDefinition.typeId) {
            implementations.executors.insert(type, compareExecutor);
        } else if (type == parallelJoinType) {
            implementations.executors.insert(type, std::make_shared<ParallelJoinExecutor>());
        } else {
            implementations.executors.insert(type, std::make_shared<BasicOperationExecutor>(type));
        }
    }
    return {};
}

} // namespace Blueprint
