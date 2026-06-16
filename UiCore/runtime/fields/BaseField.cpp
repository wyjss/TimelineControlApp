#include "BaseField.h"

#include <QtGlobal>

namespace EarthUI {

namespace {

BaseField::ValueType normalizeValueType(BaseField::ValueType valueType)
{
    switch (valueType) {
    case BaseField::BoolType:
    case BaseField::IntType:
    case BaseField::DoubleType:
    case BaseField::StringType:
    case BaseField::EnumType:
    case BaseField::ColorType:
    case BaseField::SizeType:
    case BaseField::VariantType:
        return valueType;
    case BaseField::InvalidType:
    default:
        return BaseField::InvalidType;
    }
}

BaseField::EditorHint normalizeEditorHint(BaseField::EditorHint editorHint)
{
    switch (editorHint) {
    case BaseField::AutoEditor:
    case BaseField::TextEditor:
    case BaseField::SliderEditor:
    case BaseField::ToggleEditor:
    case BaseField::SelectEditor:
    case BaseField::ChoiceEditor:
    case BaseField::SegmentedEditor:
    case BaseField::ColorEditor:
    case BaseField::SizeEditor:
    case BaseField::CustomEditor:
        return editorHint;
    default:
        return BaseField::AutoEditor;
    }
}

} // namespace

BaseField::BaseField(QObject *parent)
    : QObject(parent)
{
}

BaseField::BaseField(const QString& key, const QString& label, const QVariant& value, ValueType valueType /* = VariantType */, EditorHint editorHint /* = AutoEditor */, QObject* parent /* = nullptr */)
    : QObject(parent)
    , m_key(key)
    , m_label(label)
    , m_value(value)
    , m_valueType(valueType)
    , m_editorHint(editorHint)
{

}

QString BaseField::key() const
{
    return m_key;
}

void BaseField::setKey(const QString &key)
{
    if (m_key == key)
        return;

    m_key = key;
    emit keyChanged();
}

QString BaseField::label() const
{
    return m_label;
}

void BaseField::setLabel(const QString &label)
{
    if (m_label == label)
        return;

    m_label = label;
    emit labelChanged();
}

QString BaseField::subtitle() const
{
    return m_subtitle;
}

void BaseField::setSubtitle(const QString &subtitle)
{
    if (m_subtitle == subtitle)
        return;

    m_subtitle = subtitle;
    emit subtitleChanged();
}

BaseField::ValueType BaseField::valueType() const
{
    return m_valueType;
}

void BaseField::setValueType(ValueType valueType)
{
    const ValueType normalizedValueType = normalizeValueType(valueType);
    if (m_valueType == normalizedValueType)
        return;

    m_valueType = normalizedValueType;
    emit valueTypeChanged();
}

BaseField::EditorHint BaseField::editorHint() const
{
    return m_editorHint;
}

void BaseField::setEditorHint(EditorHint editorHint)
{
    const EditorHint normalizedEditorHint = normalizeEditorHint(editorHint);
    if (m_editorHint == normalizedEditorHint)
        return;

    m_editorHint = normalizedEditorHint;
    emit editorHintChanged();
}

QVariant BaseField::value() const
{
    return m_value;
}

void BaseField::setValue(const QVariant &value)
{
    if (m_value == value)
        return;

    m_value = value;
    emit valueChanged();
}

QVariant BaseField::defaultValue() const
{
    return m_defaultValue;
}

void BaseField::setDefaultValue(const QVariant &defaultValue)
{
    if (m_defaultValue == defaultValue)
        return;

    m_defaultValue = defaultValue;
    emit defaultValueChanged();
}

bool BaseField::required() const
{
    return m_required;
}

void BaseField::setRequired(bool required)
{
    if (m_required == required)
        return;

    m_required = required;
    emit requiredChanged();
}

bool BaseField::readOnly() const
{
    return m_readOnly;
}

void BaseField::setReadOnly(bool readOnly)
{
    if (m_readOnly == readOnly)
        return;

    m_readOnly = readOnly;
    emit readOnlyChanged();
}

QVariantList BaseField::options() const
{
    return m_options;
}

void BaseField::setOptions(const QVariantList &options)
{
    if (m_options == options)
        return;

    m_options = options;
    emit optionsChanged();
}

QString BaseField::placeholderText() const
{
    return m_placeholderText;
}

void BaseField::setPlaceholderText(const QString &placeholderText)
{
    if (m_placeholderText == placeholderText)
        return;

    m_placeholderText = placeholderText;
    emit placeholderTextChanged();
}

QString BaseField::pattern() const
{
    return m_pattern;
}

void BaseField::setPattern(const QString &pattern)
{
    if (m_pattern == pattern)
        return;

    m_pattern = pattern;
    emit patternChanged();
}

double BaseField::minimum() const
{
    return m_minimum;
}

void BaseField::setMinimum(double minimum)
{
    if (qFuzzyCompare(m_minimum, minimum))
        return;

    m_minimum = minimum;
    emit minimumChanged();
}

double BaseField::maximum() const
{
    return m_maximum;
}

void BaseField::setMaximum(double maximum)
{
    if (qFuzzyCompare(m_maximum, maximum))
        return;

    m_maximum = maximum;
    emit maximumChanged();
}

double BaseField::stepSize() const
{
    return m_stepSize;
}

void BaseField::setStepSize(double stepSize)
{
    if (qFuzzyCompare(m_stepSize, stepSize))
        return;

    m_stepSize = stepSize;
    emit stepSizeChanged();
}

QString BaseField::suffix() const
{
    return m_suffix;
}

void BaseField::setSuffix(const QString &suffix)
{
    if (m_suffix == suffix)
        return;

    m_suffix = suffix;
    emit suffixChanged();
}

} // namespace EarthUI
