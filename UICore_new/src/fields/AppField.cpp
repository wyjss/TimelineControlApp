#include <UICore/Fields/AppField.h>

#include <UICore/Fields/BaseField.h>

using namespace UICore;

AppField::AppField(QObject *parent)
    : QObject(parent)
    , m_ownedField(new BaseField(this))
    , m_sourceField(m_ownedField)
{
    connectSourceFieldSignals();
}

AppField::Kind AppField::kind() const
{
    return m_kind;
}

void AppField::setKind(Kind kind)
{
    if (m_kind == kind)
        return;

    m_kind = kind;
    emit kindChanged();
}

BaseField::ValueType AppField::valueType() const
{
    return m_sourceField->valueType();
}

void AppField::setValueType(BaseField::ValueType valueType)
{
    m_sourceField->setValueType(valueType);
}

QString AppField::key() const
{
    return m_sourceField->key();
}

void AppField::setKey(const QString &key)
{
    m_sourceField->setKey(key);
}

QString AppField::label() const
{
    return m_sourceField->label();
}

void AppField::setLabel(const QString &label)
{
    m_sourceField->setLabel(label);
}

QString AppField::subtitle() const
{
    return m_sourceField->subtitle();
}

void AppField::setSubtitle(const QString &subtitle)
{
    m_sourceField->setSubtitle(subtitle);
}

QVariant AppField::value() const
{
    return m_sourceField->value();
}

void AppField::setValue(const QVariant &value)
{
    m_sourceField->setValue(value);
}

bool AppField::required() const
{
    return m_sourceField->required();
}

void AppField::setRequired(bool required)
{
    m_sourceField->setRequired(required);
}

QString AppField::errorText() const
{
    return m_sourceField->errorText();
}

void AppField::setErrorText(const QString &errorText)
{
    m_sourceField->setErrorText(errorText);
}

bool AppField::valid() const
{
    return m_sourceField->valid();
}

QVariantList AppField::options() const
{
    return m_sourceField->options();
}

void AppField::setOptions(const QVariantList &options)
{
    m_sourceField->setOptions(options);
}

bool AppField::allowCustomValue() const
{
    return m_sourceField->allowCustomValue();
}

void AppField::setAllowCustomValue(bool allowCustomValue)
{
    m_sourceField->setAllowCustomValue(allowCustomValue);
}

QVariantList AppField::items() const
{
    return m_items;
}

void AppField::setItems(const QVariantList &items)
{
    if (m_items == items)
        return;

    m_items = items;
    emit itemsChanged();
}

UiStyle::TextTone AppField::textTone() const
{
    return m_textTone;
}

void AppField::setTextTone(UiStyle::TextTone textTone)
{
    if (m_textTone == textTone)
        return;

    m_textTone = textTone;
    emit textToneChanged();
}

UiStyle::SurfaceTone AppField::surfaceTone() const
{
    return m_surfaceTone;
}

void AppField::setSurfaceTone(UiStyle::SurfaceTone surfaceTone)
{
    if (m_surfaceTone == surfaceTone)
        return;

    m_surfaceTone = surfaceTone;
    emit surfaceToneChanged();
}

UiStyle::ControlAppearance AppField::appearance() const
{
    return m_appearance;
}

void AppField::setAppearance(UiStyle::ControlAppearance appearance)
{
    if (m_hasExplicitAppearance && m_appearance == appearance)
        return;

    m_appearance = appearance;
    m_hasExplicitAppearance = true;
    emit appearanceChanged();
}

bool AppField::hasExplicitAppearance() const
{
    return m_hasExplicitAppearance;
}

QString AppField::placeholderText() const
{
    return m_sourceField->placeholderText();
}

void AppField::setPlaceholderText(const QString &placeholderText)
{
    m_sourceField->setPlaceholderText(placeholderText);
}

bool AppField::readOnly() const
{
    return m_sourceField->readOnly();
}

void AppField::setReadOnly(bool readOnly)
{
    m_sourceField->setReadOnly(readOnly);
}

double AppField::minimum() const
{
    return m_sourceField->minimum();
}

void AppField::setMinimum(double minimum)
{
    m_sourceField->setMinimum(minimum);
}

double AppField::maximum() const
{
    return m_sourceField->maximum();
}

void AppField::setMaximum(double maximum)
{
    m_sourceField->setMaximum(maximum);
}

double AppField::stepSize() const
{
    return m_sourceField->stepSize();
}

void AppField::setStepSize(double stepSize)
{
    m_sourceField->setStepSize(stepSize);
}

QString AppField::suffix() const
{
    return m_sourceField->suffix();
}

void AppField::setSuffix(const QString &suffix)
{
    m_sourceField->setSuffix(suffix);
}

UiStyle::ButtonVariant AppField::variant() const
{
    return m_variant;
}

void AppField::setVariant(UiStyle::ButtonVariant variant)
{
    if (m_variant == variant)
        return;

    m_variant = variant;
    emit variantChanged();
}

QString AppField::actionId() const
{
    return m_actionId;
}

void AppField::setActionId(const QString &actionId)
{
    if (m_actionId == actionId)
        return;

    m_actionId = actionId;
    emit actionIdChanged();
}

QVariantMap AppField::payload() const
{
    return m_payload;
}

void AppField::setPayload(const QVariantMap &payload)
{
    if (m_payload == payload)
        return;

    m_payload = payload;
    emit payloadChanged();
}

QUrl AppField::delegateSource() const
{
    return m_delegateSource;
}

void AppField::setDelegateSource(const QUrl &delegateSource)
{
    if (m_delegateSource == delegateSource)
        return;

    m_delegateSource = delegateSource;
    emit delegateSourceChanged();
}

QVariantMap AppField::customData() const
{
    return m_customData;
}

void AppField::setCustomData(const QVariantMap &customData)
{
    if (m_customData == customData)
        return;

    m_customData = customData;
    emit customDataChanged();
}

BaseField *AppField::sourceField() const
{
    return m_sourceField.data();
}

void AppField::setSourceField(BaseField *sourceField)
{
    BaseField *nextSourceField = sourceField ? sourceField : m_ownedField;
    if (m_sourceField.data() == nextSourceField)
        return;

    if (m_sourceField)
        QObject::disconnect(m_sourceField, nullptr, this, nullptr);

    m_sourceField = nextSourceField;
    connectSourceFieldSignals();
    setKind(kindFromBaseField(m_sourceField));
    emit sourceFieldChanged();
    emit valueTypeChanged();
    emit keyChanged();
    emit labelChanged();
    emit subtitleChanged();
    emit valueChanged();
    emit requiredChanged();
    emit errorTextChanged();
    emit validChanged();
    emit optionsChanged();
    emit allowCustomValueChanged();
    emit placeholderTextChanged();
    emit readOnlyChanged();
    emit minimumChanged();
    emit maximumChanged();
    emit stepSizeChanged();
    emit suffixChanged();
}

AppField::Kind AppField::kindFromBaseField(const BaseField *sourceField)
{
    if (!sourceField)
        return Kind::TextField;

    switch (sourceField->editorHint()) {
    case BaseField::MultilineTextEditor:
        return Kind::TextArea;
    case BaseField::CheckBoxEditor:
        return Kind::CheckBox;
    case BaseField::ToggleEditor:
        return Kind::Toggle;
    case BaseField::SliderEditor:
        return Kind::Slider;
    case BaseField::SelectEditor:
        return sourceField->valueType() != BaseField::EnumType
                && sourceField->allowCustomValue()
            ? Kind::TextField
            : Kind::Select;
    case BaseField::ChoiceEditor:
        return Kind::Choice;
    case BaseField::SegmentedEditor:
        return Kind::Segmented;
    case BaseField::ColorEditor:
        return Kind::Color;
    case BaseField::CustomEditor:
        return Kind::Custom;
    case BaseField::SizeEditor:
    case BaseField::TextEditor:
        return Kind::TextField;
    case BaseField::AutoEditor:
    default:
        break;
    }

    switch (sourceField->valueType()) {
    case BaseField::BoolType:
        return Kind::Toggle;
    case BaseField::EnumType:
        return Kind::Select;
    case BaseField::ColorType:
        return Kind::Color;
    default:
        return Kind::TextField;
    }
}

void AppField::connectSourceFieldSignals()
{
    QObject::connect(m_sourceField, &BaseField::keyChanged, this, &AppField::keyChanged);
    QObject::connect(m_sourceField, &BaseField::labelChanged, this, &AppField::labelChanged);
    QObject::connect(m_sourceField, &BaseField::subtitleChanged, this, &AppField::subtitleChanged);
    QObject::connect(m_sourceField, &BaseField::valueChanged, this, &AppField::valueChanged);
    QObject::connect(m_sourceField, &BaseField::requiredChanged, this, &AppField::requiredChanged);
    QObject::connect(m_sourceField, &BaseField::errorTextChanged, this, &AppField::errorTextChanged);
    QObject::connect(m_sourceField, &BaseField::validChanged, this, &AppField::validChanged);
    QObject::connect(m_sourceField, &BaseField::optionsChanged, this, &AppField::optionsChanged);
    QObject::connect(m_sourceField,
                     &BaseField::allowCustomValueChanged,
                     this,
                     [this]() {
                         emit allowCustomValueChanged();
                         if (m_sourceField->editorHint() == BaseField::SelectEditor)
                             setKind(kindFromBaseField(m_sourceField));
                     });
    QObject::connect(m_sourceField, &BaseField::placeholderTextChanged, this, &AppField::placeholderTextChanged);
    QObject::connect(m_sourceField, &BaseField::readOnlyChanged, this, &AppField::readOnlyChanged);
    QObject::connect(m_sourceField, &BaseField::minimumChanged, this, &AppField::minimumChanged);
    QObject::connect(m_sourceField, &BaseField::maximumChanged, this, &AppField::maximumChanged);
    QObject::connect(m_sourceField, &BaseField::stepSizeChanged, this, &AppField::stepSizeChanged);
    QObject::connect(m_sourceField, &BaseField::suffixChanged, this, &AppField::suffixChanged);
    QObject::connect(m_sourceField,
                     &BaseField::valueTypeChanged,
                     this,
                     [this]() {
                         emit valueTypeChanged();
                         setKind(kindFromBaseField(m_sourceField));
                     });
    QObject::connect(m_sourceField,
                     &BaseField::editorHintChanged,
                     this,
                     [this]() { setKind(kindFromBaseField(m_sourceField)); });
    QObject::connect(m_sourceField,
                     &QObject::destroyed,
                     this,
                     [this]() { setSourceField(nullptr); });
}
