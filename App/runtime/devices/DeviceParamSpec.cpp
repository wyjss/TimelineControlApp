#include "devices/DeviceParamSpec.h"

#include <QColor>
#include <QRegularExpression>

using namespace TimelineControl;

DeviceParamSpec::DeviceParamSpec(QObject *parent)
    : BaseField(parent)
{
    setRequired(true);
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
    setRequired(true);
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

QString DeviceParamSpec::invalidReason(const QVariant &value) const
{
    const QVariant checkedValue = value.isValid() ? value : this->value();
    const QString labelText = label().isEmpty() ? key() : label();
    const QString text = checkedValue.toString();
    if (required() && text.isEmpty())
        return tr("%1 必填").arg(labelText);
    if (text.isEmpty())
        return QString();

    if (!pattern().isEmpty()) {
        const QRegularExpression expression(pattern());
        if (!expression.isValid())
            return tr("%1 的校验规则无效").arg(labelText);
        if (!expression.match(text).hasMatch())
            return tr("%1 格式无效").arg(labelText);
    }

    if (valueType() == IntType || valueType() == DoubleType) {
        bool ok = false;
        const double numberValue = checkedValue.toDouble(&ok);
        if (!ok)
            return tr("%1 必须是数字").arg(labelText);
        if (numberValue < minimum())
            return tr("%1 低于最小值").arg(labelText);
        if (numberValue > maximum())
            return tr("%1 高于最大值").arg(labelText);
    }

    return QString();
}

QString DeviceParamSpec::typeName(ValueType valueType)
{
    switch (valueType) {
    case IntType:
        return QStringLiteral("整数");
    case DoubleType:
        return QStringLiteral("小数");
    case StringType:
        return QStringLiteral("文本");
    case BoolType:
        return QStringLiteral("布尔");
    case SelectType:
        return QStringLiteral("选项");
    case ColorType:
        return QStringLiteral("颜色");
    case VariantType:
        return QStringLiteral("通用");
    case InvalidType:
        break;
    }

    return QStringLiteral("无效");
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
    case VariantType:
    case InvalidType:
        break;
    }

    return value;
}

