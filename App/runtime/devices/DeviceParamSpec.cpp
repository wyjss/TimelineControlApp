#include "devices/DeviceParamSpec.h"

#include <QColor>
#include <QSize>

namespace TimelineControl {

DeviceParamSpec::DeviceParamSpec(QObject *parent)
    : BaseField(parent)
{
}

DeviceParamSpec::DeviceParamSpec(const QString &key,
                                 const QString &label,
                                 const QVariant &value,
                                 ValueType valueType,
                                 EditorHint editorHint,
                                 QObject *parent)
    : BaseField(parent)
{
    const QVariant normalized = normalizedValue(valueType, value);

    setKey(key);
    setLabel(label);
    setValueType(valueType);
    setEditorHint(editorHint);
    setValue(normalized);
    setDefaultValue(normalized);
}

QString DeviceParamSpec::typeName() const
{
    return typeName(valueType());
}

DeviceParamSpec *DeviceParamSpec::clone(QObject *parent) const
{
    auto *field = new DeviceParamSpec(parent);
    field->setKey(key());
    field->setLabel(label());
    field->setSubtitle(subtitle());
    field->setValueType(valueType());
    field->setEditorHint(editorHint());
    field->setValue(value());
    field->setDefaultValue(defaultValue());
    field->setRequired(required());
    field->setReadOnly(readOnly());
    field->setOptions(options());
    field->setPlaceholderText(placeholderText());
    field->setPattern(pattern());
    field->setMinimum(minimum());
    field->setMaximum(maximum());
    field->setStepSize(stepSize());
    field->setSuffix(suffix());
    return field;
}

QString DeviceParamSpec::typeName(ValueType valueType)
{
    switch (valueType) {
    case IntType:
        return QStringLiteral("int");
    case DoubleType:
        return QStringLiteral("double");
    case StringType:
        return QStringLiteral("string");
    case BoolType:
        return QStringLiteral("bool");
    case SelectType:
        return QStringLiteral("select");
    case ColorType:
        return QStringLiteral("color");
    case SizeType:
        return QStringLiteral("size");
    case VariantType:
        return QStringLiteral("variant");
    case InvalidType:
        break;
    }

    return QStringLiteral("invalid");
}

QVariant DeviceParamSpec::normalizedValue(ValueType valueType, const QVariant &value)
{
    switch (valueType) {
    case IntType:
        return value.toInt();
    case DoubleType:
        return value.toDouble();
    case StringType:
    case SelectType:
        return value.toString();
    case BoolType:
        return value.toBool();
    case ColorType:
        return value.value<QColor>();
    case SizeType:
        return value.value<QSize>();
    case VariantType:
    case InvalidType:
        break;
    }

    return value;
}

} // namespace TimelineControl
