#include <Blueprint/ObjectNodes.h>

#include <algorithm>
#include <utility>

namespace Blueprint {
namespace {

const auto readType = QStringLiteral("demo.readProperty");
const auto writeType = QStringLiteral("demo.setProperty");
const auto callType = QStringLiteral("demo.call");
const auto targetKey = QStringLiteral("target");
const auto memberKey = QStringLiteral("member");
const auto valueKey = QStringLiteral("value");
const auto execOut = QStringLiteral("execOut");
const auto stringType = QStringLiteral("string");

const PropertyDefinition *findProperty(const NodeTypeDefinition *type, const QString &key)
{
    if (!type)
        return nullptr;
    const auto it = std::find_if(type->properties.cbegin(), type->properties.cend(), [&](const PropertyDefinition &item) {
        return item.value.key == key;
    });
    return it == type->properties.cend() ? nullptr : &*it;
}

const MethodDefinition *findMethod(const NodeTypeDefinition *type, const QString &key)
{
    if (!type)
        return nullptr;
    const auto it = std::find_if(type->methods.cbegin(), type->methods.cend(), [&](const MethodDefinition &item) {
        return item.key == key;
    });
    return it == type->methods.cend() ? nullptr : &*it;
}

struct ObjectServices
{
    QHash<QString, NodeTypeDefinition> types;
    ObjectNodeBindings bindings;

    const NodeTypeDefinition *findType(const QString &target) const
    {
        const auto found = types.constFind(bindings.targetType ? bindings.targetType(target) : QString{});
        return found == types.cend() ? nullptr : &found.value();
    }
};

class ReadPropertyExecutor final : public Executor
{
public:
    explicit ReadPropertyExecutor(std::shared_ptr<const ObjectServices> services)
        : Executor(Trigger::OnDemand), m_services(std::move(services)) {}

    void start(const ExecutionContext &context, Completion done) override
    {
        const auto target = context.parameters.value(targetKey).toString();
        const auto member = context.parameters.value(memberKey).toString();
        const auto *property = findProperty(m_services->findType(target), member);
        if (!property || !m_services->bindings.read) {
            done({{}, {}, {"object.unavailable_property",
                QStringLiteral("目标对象或属性不可用：%1 / %2").arg(target, member), {}, member}});
            return;
        }
        const auto result = m_services->bindings.read(target, member);
        if (!result.error.code.isEmpty()) {
            done({{}, {}, result.error});
            return;
        }
        if (!NodeRegistry::acceptsParameterValue(property->value, result.value)) {
            done({{}, {}, {"value.constraint",
                QStringLiteral("属性「%1」返回了无效值。").arg(property->value.displayName), {}, member}});
            return;
        }
        done({{}, {{valueKey, result.value}}, {}});
    }

private:
    const std::shared_ptr<const ObjectServices> m_services;
};

class WritePropertyExecutor final : public Executor
{
public:
    explicit WritePropertyExecutor(std::shared_ptr<const ObjectServices> services)
        : Executor(Trigger::Execution), m_services(std::move(services)) {}

    void start(const ExecutionContext &context, Completion done) override
    {
        const auto target = context.parameters.value(targetKey).toString();
        const auto member = context.parameters.value(memberKey).toString();
        const auto *property = findProperty(m_services->findType(target), member);
        Diagnostic error;
        if (!property || !m_services->bindings.write)
            error = {"object.unavailable_property",
                     QStringLiteral("目标对象或属性不可用：%1 / %2").arg(target, member), context.nodeId, memberKey};
        else if (!property->writable)
            error = {"object.read_only_property",
                     QStringLiteral("属性不可写：%1").arg(member), context.nodeId, memberKey};
        else {
            const auto value = context.inputs.value(valueKey);
            if (NodeRegistry::acceptsParameterValue(property->value, value))
                error = m_services->bindings.write(target, member, value);
            else
                error = {"value.constraint",
                         QStringLiteral("属性「%1」的输入无效。").arg(property->value.displayName), context.nodeId, valueKey};
        }
        done({execOut, {}, error});
    }

private:
    const std::shared_ptr<const ObjectServices> m_services;
};

class CallMethodExecutor final : public Executor
{
public:
    explicit CallMethodExecutor(std::shared_ptr<const ObjectServices> services)
        : Executor(Trigger::Execution), m_services(std::move(services)) {}

    void start(const ExecutionContext &context, Completion done) override
    {
        const auto target = context.parameters.value(targetKey).toString();
        const auto member = context.parameters.value(memberKey).toString();
        const auto *type = m_services->findType(target);
        const auto *method = findMethod(type, member);
        if (!method || !m_services->bindings.invoke) {
            done({{}, {}, {"object.unavailable_method",
                "请选择目标对象和接口。", context.nodeId, memberKey}});
            return;
        }
        QVariantMap inputs;
        for (const auto &input : method->inputs) {
            const auto port = objectCallPortKey(PortDirection::Input, type->typeId, member, input.key);
            const auto value = context.inputs.value(port);
            if (!NodeRegistry::acceptsParameterValue(input, value)) {
                done({{}, {}, {"value.constraint",
                    QStringLiteral("接口参数「%1」的输入无效。").arg(input.displayName), context.nodeId, port}});
                return;
            }
            inputs.insert(input.key, value);
        }
        const auto error = m_services->bindings.invoke(target, member, context.callId, inputs,
            [done, typeId = type->typeId, member, outputDefinitions = method->outputs](QVariantMap values, Diagnostic error) {
                if (!error.code.isEmpty()) {
                    done({{}, {}, error});
                    return;
                }
                error = NodeRegistry::validateValues(outputDefinitions, values);
                if (!error.code.isEmpty()) {
                    error.key = objectCallPortKey(PortDirection::Output, typeId, member, error.key);
                    done({{}, {}, error});
                    return;
                }
                QVariantMap outputs;
                for (auto it = values.cbegin(); it != values.cend(); ++it)
                    outputs.insert(objectCallPortKey(PortDirection::Output, typeId, member, it.key()), it.value());
                const auto exit = outputDefinitions.size() == 1
                    ? objectCallPortKey(PortDirection::Output, typeId, member, outputDefinitions.first().key) : execOut;
                done({exit, outputs, {}});
            });
        if (!error.code.isEmpty())
            done({{}, {}, error});
    }

    void cancel(const QUuid &callId) override
    {
        if (m_services->bindings.cancel)
            m_services->bindings.cancel(callId);
    }

private:
    const std::shared_ptr<const ObjectServices> m_services;
};

} // namespace

QString objectCallPortKey(PortDirection direction, const QString &type, const QString &method, const QString &key)
{
    const auto prefix = direction == PortDirection::Input ? QStringLiteral("in") : QStringLiteral("out");
    return QStringLiteral("%1/%2/%3/%4").arg(prefix,
        QString(type).replace("%", "%25").replace("/", "%2F"),
        QString(method).replace("%", "%25").replace("/", "%2F"),
        QString(key).replace("%", "%25").replace("/", "%2F"));
}

Diagnostic registerObjectNodes(NodeRegistry &registry, const ObjectNodeBindings::TargetType &targetType,
                               const ParameterDefinition &defaultWriteProperty, const QString &defaultMethod)
{
    if (!targetType)
        return {"object.missing_target_type", "Object nodes require a target type resolver."};
    for (const auto &type : {readType, writeType, callType}) {
        if (registry.find(type))
            return {"registry.duplicateType",
                    QStringLiteral("Node type '%1' is already registered.").arg(type), {}, type};
    }

    const QString category = "objectOperations";
    const PortDefinition execute{"execIn", PortDirection::Input, {},
                                 "执行", PortKind::Execution};
    const PortDefinition next{execOut, PortDirection::Output, {},
                              "继续", PortKind::Execution};
    const QString inputLabel = "输入";
    const QString outputLabel = "输出";
    const ParameterDefinition target{targetKey, stringType, QStringLiteral("")};
    const ParameterDefinition readMember{memberKey, stringType, QStringLiteral("")};
    const ParameterDefinition writeMember{memberKey, stringType, defaultWriteProperty.key};
    const ParameterDefinition callMember{memberKey, stringType, defaultMethod};
    NodeTypeDefinition read{readType, "读取属性", {}, {target, readMember},
                            category, InstancePolicy::Multiple, {},
                            "读取所选对象的属性", "↗"};
    NodeTypeDefinition write{writeType, "设置属性", {execute, next},
                             {target, writeMember}, category, InstancePolicy::Multiple, {},
                             "写入所选对象的属性", "↘"};
    NodeTypeDefinition call{callType, "调用接口", {execute, next},
                            {target, callMember}, category, InstancePolicy::Multiple, {},
                            "执行所选接口并传递结果", "▷"};
    if (!defaultWriteProperty.key.isEmpty()) {
        auto parameter = defaultWriteProperty;
        parameter.key = valueKey;
        write.parameters.append(parameter);
    }
    for (const auto &type : registry.definitions()) {
        for (const auto &method : type.methods) {
            for (auto input : method.inputs) {
                input.key = objectCallPortKey(PortDirection::Input, type.typeId, method.key, input.key);
                input.defaultValue = {};
                call.parameters.append(std::move(input));
            }
        }
    }

    read.resolvePorts = [&registry, targetType, outputLabel](const NodeData &node) {
        const auto type = targetType(node.parameterOverrides.value(targetKey).toString());
        const auto *property = findProperty(registry.find(type), node.parameterOverrides.value(memberKey).toString());
        return QVector<PortDefinition>{{valueKey, PortDirection::Output,
                                        property ? property->value.valueTypeId : QString{}, outputLabel}};
    };
    write.resolvePorts = [&registry, targetType, defaultWriteProperty, execute, next, inputLabel](const NodeData &node) {
        const auto type = targetType(node.parameterOverrides.value(targetKey).toString());
        const auto member = node.parameterOverrides.value(memberKey, defaultWriteProperty.key).toString();
        const auto *property = findProperty(registry.find(type), member);
        PortDefinition input{valueKey, PortDirection::Input, {}, inputLabel};
        if (property && property->writable) {
            input.valueTypeId = property->value.valueTypeId;
            input.defaultValue = property->value.defaultValue;
        }
        // 旧图在未绑定目标时也允许给设置节点连数值线。
        if (member == defaultWriteProperty.key && !defaultWriteProperty.key.isEmpty()
            && (!property || (property->writable && input.valueTypeId == defaultWriteProperty.valueTypeId))) {
            input.valueTypeId = defaultWriteProperty.valueTypeId;
            const auto fallback = node.parameterOverrides.value(valueKey, defaultWriteProperty.defaultValue);
            if (!property || NodeRegistry::acceptsParameterValue(property->value, fallback))
                input.defaultValue = fallback;
        }
        return QVector<PortDefinition>{execute, input, next};
    };
    call.resolvePorts = [&registry, targetType, defaultMethod, execute, next](const NodeData &node) {
        const auto type = targetType(node.parameterOverrides.value(targetKey).toString());
        const auto member = node.parameterOverrides.value(memberKey, defaultMethod).toString();
        const auto *method = findMethod(registry.find(type), member);
        QVector<PortDefinition> ports{execute};
        if (!method || method->outputs.size() != 1)
            ports.append(next);
        if (method) {
            for (const auto &input : method->inputs) {
                const auto key = objectCallPortKey(PortDirection::Input, type, member, input.key);
                ports.append({key, PortDirection::Input, input.valueTypeId, input.displayName, PortKind::Data,
                              node.parameterOverrides.value(key, input.defaultValue)});
            }
            for (const auto &output : method->outputs) {
                ports.append({objectCallPortKey(PortDirection::Output, type, member, output.key),
                              PortDirection::Output, output.valueTypeId, output.displayName,
                              method->outputs.size() == 1 ? PortKind::DataAndExecution : PortKind::Data});
            }
        }
        return ports;
    };

    // 三项先在临时注册表完成验证，宿主不会收到半套节点声明。
    NodeRegistry validated;
    for (const auto *definition : {&read, &write, &call}) {
        const auto error = validated.add(*definition);
        if (!error.code.isEmpty())
            return error;
    }
    for (const auto *definition : {&read, &write, &call}) {
        const auto error = registry.add(*definition);
        if (!error.code.isEmpty())
            return error;
    }
    return {};
}

void addObjectImplementations(RuntimeImplementations &implementations, const NodeRegistry &registry,
                              const ObjectNodeBindings &bindings)
{
    QHash<QString, NodeTypeDefinition> types;
    for (const auto &type : registry.definitions()) {
        if (!type.properties.isEmpty() || !type.methods.isEmpty())
            types.insert(type.typeId, type);
    }
    const auto services = std::make_shared<const ObjectServices>(ObjectServices{std::move(types), bindings});
    implementations.executors.insert(readType, std::make_shared<ReadPropertyExecutor>(services));
    implementations.executors.insert(writeType, std::make_shared<WritePropertyExecutor>(services));
    implementations.executors.insert(callType, std::make_shared<CallMethodExecutor>(services));
}

} // namespace Blueprint
