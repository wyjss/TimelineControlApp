#include <Blueprint/NodeRegistry.h>

#include <QMetaType>
#include <QSet>
#include <QtMath>

#include <cmath>

namespace Blueprint {
namespace {

QMetaType::Type valueType(const QString &id)
{
    if (id == QStringLiteral("bool"))
        return QMetaType::Bool;
    if (id == QStringLiteral("number"))
        return QMetaType::Double;
    if (id == QStringLiteral("string"))
        return QMetaType::QString;
    return QMetaType::UnknownType;
}

Diagnostic validateParameterDefinitions(const QVector<ParameterDefinition> &definitions)
{
    QSet<QString> keys;
    for (const ParameterDefinition &parameter : definitions) {
        if (parameter.key.trimmed().isEmpty() || keys.contains(parameter.key))
            return {"definition.parameterKey",
                    QStringLiteral("Empty or duplicate parameter key '%1'.").arg(parameter.key), {}, parameter.key};
        const auto type = valueType(parameter.valueTypeId);
        if (type == QMetaType::UnknownType)
            return {"definition.valueType",
                    QStringLiteral("Unknown value type '%1' for parameter '%2'.")
                        .arg(parameter.valueTypeId, parameter.key), {}, parameter.key};
        if (!parameter.allowedValues.isEmpty() && type != QMetaType::QString)
            return {"definition.allowedValues",
                    QStringLiteral("Allowed values require a string parameter '%1'.").arg(parameter.key), {}, parameter.key};
        QSet<QString> allowedValues;
        for (const QString &value : parameter.allowedValues) {
            if (allowedValues.contains(value))
                return {"definition.allowedValues",
                        QStringLiteral("Duplicate allowed value for parameter '%1'.").arg(parameter.key), {}, parameter.key};
            allowedValues.insert(value);
        }
        if ((parameter.minimum.isValid() || parameter.maximum.isValid() || parameter.integer)
            && type != QMetaType::Double)
            return {"definition.numericConstraint",
                    QStringLiteral("Numeric constraints require a number parameter '%1'.").arg(parameter.key), {}, parameter.key};
        if ((parameter.minimum.isValid() && !NodeRegistry::acceptsValue(QStringLiteral("number"), parameter.minimum))
            || (parameter.maximum.isValid() && !NodeRegistry::acceptsValue(QStringLiteral("number"), parameter.maximum))
            || (parameter.minimum.isValid() && parameter.maximum.isValid()
                && parameter.minimum.toDouble() > parameter.maximum.toDouble()))
            return {"definition.numericConstraint",
                    QStringLiteral("Invalid numeric bounds for parameter '%1'.").arg(parameter.key), {}, parameter.key};
        if (parameter.defaultValue.isValid()
            && !NodeRegistry::acceptsParameterValue(parameter, parameter.defaultValue))
            return {"definition.defaultValue",
                    QStringLiteral("Invalid default value for parameter '%1'.").arg(parameter.key), {}, parameter.key};
        keys.insert(parameter.key);
    }
    return {};
}

} // namespace

NodeRegistry::NodeRegistry(QObject *parent)
    : QObject(parent)
{
}

Diagnostic NodeRegistry::add(const NodeTypeDefinition &definition)
{
    if (definition.typeId.trimmed().isEmpty())
        return {"definition.typeId", "The node type ID is empty."};
    if (m_types.contains(definition.typeId))
        return {"registry.duplicateType",
                QStringLiteral("Node type '%1' is already registered.").arg(definition.typeId)};

    const Diagnostic portError = validatePorts(definition.ports);
    if (!portError.code.isEmpty())
        return portError;
    const Diagnostic parameterError = validateParameterDefinitions(definition.parameters);
    if (!parameterError.code.isEmpty())
        return parameterError;

    QVector<ParameterDefinition> properties;
    properties.reserve(definition.properties.size());
    for (const PropertyDefinition &property : definition.properties)
        properties.append(property.value);
    const Diagnostic propertyError = validateParameterDefinitions(properties);
    if (!propertyError.code.isEmpty())
        return propertyError;

    QSet<QString> methodKeys;
    for (const MethodDefinition &method : definition.methods) {
        if (method.key.trimmed().isEmpty() || methodKeys.contains(method.key))
            return {"definition.methodKey",
                    QStringLiteral("Empty or duplicate method key '%1'.").arg(method.key), {}, method.key};
        const Diagnostic inputError = validateParameterDefinitions(method.inputs);
        if (!inputError.code.isEmpty())
            return inputError;
        const Diagnostic outputError = validateParameterDefinitions(method.outputs);
        if (!outputError.code.isEmpty())
            return outputError;
        methodKeys.insert(method.key);
    }

    if (definition.instancePolicy == InstancePolicy::UniqueByParameter) {
        bool hasStringKey = false;
        for (const auto &parameter : definition.parameters) {
            if (parameter.key == definition.instanceKeyParameter) {
                hasStringKey = parameter.valueTypeId == QStringLiteral("string");
                break;
            }
        }
        if (!hasStringKey)
            return {"definition.instanceKey",
                    "The instance key must name a string parameter.", {}, definition.instanceKeyParameter};
    } else if (definition.instancePolicy != InstancePolicy::Multiple
               && definition.instancePolicy != InstancePolicy::SinglePerDocument) {
        return {"definition.instancePolicy", "Unknown instance policy."};
    } else if (!definition.instanceKeyParameter.isEmpty()) {
        return {"definition.instanceKey",
                "An instance key requires the UniqueByParameter policy.", {}, definition.instanceKeyParameter};
    }

    m_types.insert(definition.typeId, std::make_shared<const NodeTypeDefinition>(definition));
    m_typeOrder.append(definition.typeId);
    emit typeAdded(definition.typeId);
    return {};
}

const NodeTypeDefinition *NodeRegistry::find(const QString &typeId) const
{
    const auto it = m_types.constFind(typeId);
    return it == m_types.cend() ? nullptr : it.value().get();
}

QVector<NodeTypeDefinition> NodeRegistry::definitions() const
{
    QVector<NodeTypeDefinition> result;
    result.reserve(m_typeOrder.size());
    for (const QString &typeId : m_typeOrder)
        result.append(*m_types.value(typeId));
    return result;
}

bool NodeRegistry::acceptsValue(const QString &valueTypeId, const QVariant &value)
{
    if (valueTypeId == anyValueType) {
        return value.userType() == QMetaType::Bool || value.userType() == QMetaType::QString
            || acceptsValue(QStringLiteral("number"), value);
    }
    const auto expected = valueType(valueTypeId);
    if (expected == QMetaType::UnknownType)
        return false;

    const int actual = value.userType();
    if (expected == QMetaType::Double) {
        return (actual == QMetaType::Int || actual == QMetaType::UInt
                || actual == QMetaType::Float || actual == QMetaType::Double)
            && qIsFinite(value.toDouble());
    }

    return actual == expected;
}

bool NodeRegistry::acceptsParameterValue(const ParameterDefinition &parameter, const QVariant &value)
{
    if (!acceptsValue(parameter.valueTypeId, value)
        || (!parameter.allowedValues.isEmpty() && !parameter.allowedValues.contains(value.toString())))
        return false;
    if (parameter.valueTypeId == QStringLiteral("number")) {
        const double number = value.toDouble();
        return (!parameter.minimum.isValid() || number >= parameter.minimum.toDouble())
            && (!parameter.maximum.isValid() || number <= parameter.maximum.toDouble())
            && (!parameter.integer || std::floor(number) == number);
    }
    return true;
}

Diagnostic NodeRegistry::validateValues(const QVector<ParameterDefinition> &definitions,
                                        const QVariantMap &values)
{
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        bool declared = false;
        for (const ParameterDefinition &parameter : definitions) {
            if (parameter.key == it.key()) {
                declared = true;
                break;
            }
        }
        if (!declared)
            return {"value.unknownKey",
                    QStringLiteral("Unknown value key '%1'.").arg(it.key()), {}, it.key()};
        if (!it.value().isValid())
            return {"value.invalid",
                    QStringLiteral("The value for '%1' is unset.").arg(it.key()), {}, it.key()};
    }
    for (const ParameterDefinition &parameter : definitions) {
        const QVariant value = values.value(parameter.key, parameter.defaultValue);
        if (value.isValid() && !acceptsParameterValue(parameter, value))
            return {"value.constraint",
                    QStringLiteral("Invalid value for '%1'.").arg(parameter.key), {}, parameter.key};
    }
    return {};
}

Diagnostic NodeRegistry::validatePorts(const QVector<PortDefinition> &ports, bool allowUnconfigured)
{
    QSet<QString> keys;
    for (const PortDefinition &port : ports) {
        if (port.key.trimmed().isEmpty() || keys.contains(port.key))
            return {"definition.portKey",
                    QStringLiteral("Empty or duplicate port key '%1'.").arg(port.key), {}, port.key};
        if (port.direction != PortDirection::Input && port.direction != PortDirection::Output)
            return {"definition.portDirection",
                    QStringLiteral("Unknown direction for port '%1'.").arg(port.key), {}, port.key};
        if (port.kind != PortKind::Data && port.kind != PortKind::Execution)
            return {"definition.portKind",
                    QStringLiteral("Unknown kind for port '%1'.").arg(port.key), {}, port.key};
        if (port.kind == PortKind::Execution) {
            if (!port.valueTypeId.isEmpty())
                return {"definition.portType",
                        QStringLiteral("Execution port '%1' cannot declare a value type.").arg(port.key), {}, port.key};
        } else if (!(allowUnconfigured && port.valueTypeId.isEmpty())
                   && !(port.direction == PortDirection::Input && port.valueTypeId == anyValueType)
                   && valueType(port.valueTypeId) == QMetaType::UnknownType) {
            return {"definition.portType",
                    QStringLiteral("Unknown value type '%1' for port '%2'.")
                        .arg(port.valueTypeId, port.key), {}, port.key};
        }
        if (port.defaultValue.isValid()
            && (port.kind != PortKind::Data || port.direction != PortDirection::Input
                || !acceptsValue(port.valueTypeId, port.defaultValue)))
            return {"definition.portDefault",
                    QStringLiteral("Invalid default value for port '%1'.").arg(port.key), {}, port.key};
        keys.insert(port.key);
    }
    return {};
}

} // namespace Blueprint
