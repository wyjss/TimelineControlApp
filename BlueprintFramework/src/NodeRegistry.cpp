#include <Blueprint/NodeRegistry.h>

#include <QMetaType>
#include <QSet>
#include <QtMath>

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

} // namespace

QString NodeRegistry::add(const NodeTypeDefinition &definition)
{
    if (definition.typeId.trimmed().isEmpty())
        return QStringLiteral("The node type ID is empty.");
    if (m_types.contains(definition.typeId))
        return QStringLiteral("Node type '%1' is already registered.").arg(definition.typeId);

    QSet<QString> portKeys;
    for (const PortDefinition &port : definition.ports) {
        if (port.key.trimmed().isEmpty() || portKeys.contains(port.key))
            return QStringLiteral("Empty or duplicate port key '%1'.").arg(port.key);
        if (port.typeParameterKey.isEmpty() && port.valueTypeId != executionPortType
            && valueType(port.valueTypeId) == QMetaType::UnknownType)
            return QStringLiteral("Unknown value type '%1' for port '%2'.")
                .arg(port.valueTypeId, port.key);
        portKeys.insert(port.key);
    }

    QSet<QString> parameterKeys;
    for (const ParameterDefinition &parameter : definition.parameters) {
        if (parameter.key.trimmed().isEmpty() || parameterKeys.contains(parameter.key))
            return QStringLiteral("Empty or duplicate parameter key '%1'.").arg(parameter.key);
        if (valueType(parameter.valueTypeId) == QMetaType::UnknownType)
            return QStringLiteral("Unknown value type '%1' for parameter '%2'.")
                .arg(parameter.valueTypeId, parameter.key);
        if (!parameter.allowedValues.isEmpty() && valueType(parameter.valueTypeId) != QMetaType::QString)
            return QStringLiteral("Allowed values require a string parameter '%1'.").arg(parameter.key);
        if (parameter.defaultValue.isValid()
            && !acceptsParameterValue(parameter, parameter.defaultValue)) {
            return QStringLiteral("Invalid default value for parameter '%1'.").arg(parameter.key);
        }
        parameterKeys.insert(parameter.key);
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
            return QStringLiteral("The instance key must name a string parameter.");
    } else if (definition.instancePolicy != InstancePolicy::Multiple
               && definition.instancePolicy != InstancePolicy::SinglePerDocument) {
        return QStringLiteral("Unknown instance policy.");
    } else if (!definition.instanceKeyParameter.isEmpty()) {
        return QStringLiteral("An instance key requires the UniqueByParameter policy.");
    }

    for (const PortDefinition &port : definition.ports) {
        if (port.typeParameterKey.isEmpty())
            continue;
        const ParameterDefinition *typeParameter = nullptr;
        for (const auto &parameter : definition.parameters) {
            if (parameter.key == port.typeParameterKey) {
                typeParameter = &parameter;
                break;
            }
        }
        if (!port.valueTypeId.isEmpty() || !typeParameter || typeParameter->valueTypeId != QStringLiteral("string")
            || typeParameter->allowedValues.isEmpty())
            return QStringLiteral("Invalid type parameter for port '%1'.").arg(port.key);
        for (const auto &type : typeParameter->allowedValues) {
            if (!type.isEmpty() && valueType(type) == QMetaType::UnknownType)
                return QStringLiteral("Unknown data type '%1' for port '%2'.").arg(type, port.key);
        }
    }

    m_types.insert(definition.typeId, definition);
    return {};
}

const NodeTypeDefinition *NodeRegistry::find(const QString &typeId) const
{
    const auto it = m_types.constFind(typeId);
    return it == m_types.cend() ? nullptr : &it.value();
}

bool NodeRegistry::acceptsValue(const QString &valueTypeId, const QVariant &value)
{
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
    return acceptsValue(parameter.valueTypeId, value)
        && (parameter.allowedValues.isEmpty()
            || (value.userType() == QMetaType::QString && parameter.allowedValues.contains(value.toString())));
}

} // namespace Blueprint
