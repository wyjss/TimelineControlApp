#include "AppFormField.h"

#include <QtGlobal>

#include "runtime/fields/BaseField.h"

namespace EarthUI {

namespace {

AppFormField::Appearance normalizeAppearance(AppFormField::Appearance appearance)
{
    switch (appearance) {
    case AppFormField::Ghost:
        return AppFormField::Ghost;
    case AppFormField::Filled:
    default:
        return AppFormField::Filled;
    }
}

AppFormField::Variant normalizeVariant(AppFormField::Variant variant)
{
    switch (variant) {
    case AppFormField::Primary:
    case AppFormField::Secondary:
    case AppFormField::Tonal:
    case AppFormField::GhostVariant:
    case AppFormField::Nav:
        return variant;
    default:
        return AppFormField::Secondary;
    }
}

} // namespace

AppFormField::AppFormField(QObject *parent)
    : QObject(parent)
{
}

AppFormField::Kind AppFormField::kind() const
{
    return m_kind;
}

void AppFormField::setKind(Kind kind)
{
    if (m_kind == kind)
        return;

    m_kind = kind;
    emit kindChanged();
}

int AppFormField::formNodeKind() const
{
    return 2;
}

QString AppFormField::key() const
{
    return m_key;
}

void AppFormField::setKey(const QString &key)
{
    if (m_key == key)
        return;

    m_key = key;
    emit keyChanged();
}

QString AppFormField::label() const
{
    return m_label;
}

void AppFormField::setLabel(const QString &label)
{
    if (m_label == label)
        return;

    m_label = label;
    emit labelChanged();
}

QString AppFormField::subtitle() const
{
    return m_subtitle;
}

void AppFormField::setSubtitle(const QString &subtitle)
{
    if (m_subtitle == subtitle)
        return;

    m_subtitle = subtitle;
    emit subtitleChanged();
}

QVariant AppFormField::value() const
{
    return m_value;
}

void AppFormField::setValue(const QVariant &value)
{
    if (m_value == value)
        return;

    m_value = value;
    emit valueChanged();

    if (m_autoCommitToSource && !m_syncingFromSource)
        commitToSourceField();
}

QVariantList AppFormField::options() const
{
    return m_options;
}

void AppFormField::setOptions(const QVariantList &options)
{
    if (m_options == options)
        return;

    m_options = options;
    emit optionsChanged();
}

QVariantList AppFormField::items() const
{
    return m_items;
}

void AppFormField::setItems(const QVariantList &items)
{
    if (m_items == items)
        return;

    m_items = items;
    emit itemsChanged();
}

QString AppFormField::textTone() const
{
    return m_textTone;
}

void AppFormField::setTextTone(const QString &textTone)
{
    if (m_textTone == textTone)
        return;

    m_textTone = textTone;
    emit textToneChanged();
}

QString AppFormField::surfaceTone() const
{
    return m_surfaceTone;
}

void AppFormField::setSurfaceTone(const QString &surfaceTone)
{
    if (m_surfaceTone == surfaceTone)
        return;

    m_surfaceTone = surfaceTone;
    emit surfaceToneChanged();
}

AppFormField::Appearance AppFormField::appearance() const
{
    return m_appearance;
}

void AppFormField::setAppearance(Appearance appearance)
{
    const Appearance normalizedAppearance = normalizeAppearance(appearance);
    if (m_appearance == normalizedAppearance)
        return;

    m_appearance = normalizedAppearance;
    emit appearanceChanged();
}

QString AppFormField::placeholderText() const
{
    return m_placeholderText;
}

void AppFormField::setPlaceholderText(const QString &placeholderText)
{
    if (m_placeholderText == placeholderText)
        return;

    m_placeholderText = placeholderText;
    emit placeholderTextChanged();
}

bool AppFormField::readOnly() const
{
    return m_readOnly;
}

void AppFormField::setReadOnly(bool readOnly)
{
    if (m_readOnly == readOnly)
        return;

    m_readOnly = readOnly;
    emit readOnlyChanged();
}

double AppFormField::minimum() const
{
    return m_minimum;
}

void AppFormField::setMinimum(double minimum)
{
    if (qFuzzyCompare(m_minimum, minimum))
        return;

    m_minimum = minimum;
    emit minimumChanged();
}

double AppFormField::maximum() const
{
    return m_maximum;
}

void AppFormField::setMaximum(double maximum)
{
    if (qFuzzyCompare(m_maximum, maximum))
        return;

    m_maximum = maximum;
    emit maximumChanged();
}

double AppFormField::stepSize() const
{
    return m_stepSize;
}

void AppFormField::setStepSize(double stepSize)
{
    if (qFuzzyCompare(m_stepSize, stepSize))
        return;

    m_stepSize = stepSize;
    emit stepSizeChanged();
}

QString AppFormField::suffix() const
{
    return m_suffix;
}

void AppFormField::setSuffix(const QString &suffix)
{
    if (m_suffix == suffix)
        return;

    m_suffix = suffix;
    emit suffixChanged();
}

AppFormField::Variant AppFormField::variant() const
{
    return m_variant;
}

void AppFormField::setVariant(Variant variant)
{
    const Variant normalizedVariant = normalizeVariant(variant);
    if (m_variant == normalizedVariant)
        return;

    m_variant = normalizedVariant;
    emit variantChanged();
}

QString AppFormField::actionId() const
{
    return m_actionId;
}

void AppFormField::setActionId(const QString &actionId)
{
    if (m_actionId == actionId)
        return;

    m_actionId = actionId;
    emit actionIdChanged();
}

QVariantMap AppFormField::payload() const
{
    return m_payload;
}

void AppFormField::setPayload(const QVariantMap &payload)
{
    if (m_payload == payload)
        return;

    m_payload = payload;
    emit payloadChanged();
}

QUrl AppFormField::delegateSource() const
{
    return m_delegateSource;
}

void AppFormField::setDelegateSource(const QUrl &delegateSource)
{
    if (m_delegateSource == delegateSource)
        return;

    m_delegateSource = delegateSource;
    emit delegateSourceChanged();
}

QVariantMap AppFormField::customData() const
{
    return m_customData;
}

void AppFormField::setCustomData(const QVariantMap &customData)
{
    if (m_customData == customData)
        return;

    m_customData = customData;
    emit customDataChanged();
}

BaseField *AppFormField::sourceField() const
{
    return m_sourceField.data();
}

void AppFormField::setSourceField(BaseField *sourceField)
{
    if (m_sourceField.data() == sourceField)
        return;

    if (m_sourceField)
        QObject::disconnect(m_sourceField, nullptr, this, nullptr);

    m_sourceField = sourceField;
    connectSourceFieldSignals();
    syncFromSourceField();
    emit sourceFieldChanged();
}

bool AppFormField::autoCommitToSource() const
{
    return m_autoCommitToSource;
}

void AppFormField::setAutoCommitToSource(bool autoCommitToSource)
{
    if (m_autoCommitToSource == autoCommitToSource)
        return;

    m_autoCommitToSource = autoCommitToSource;
    emit autoCommitToSourceChanged();
}

void AppFormField::syncFromSourceField()
{
    if (!m_sourceField)
        return;

    m_syncingFromSource = true;
    copyFromBaseField(m_sourceField.data());
    m_syncingFromSource = false;
}

void AppFormField::commitToSourceField()
{
    if (!m_sourceField || m_sourceField->value() == m_value)
        return;

    m_sourceField->setValue(m_value);
}

void AppFormField::copyFromBaseField(const BaseField *sourceField)
{
    if (!sourceField)
        return;

    setKey(sourceField->key());
    setLabel(sourceField->label());
    setSubtitle(sourceField->subtitle());
    setKind(kindFromBaseField(sourceField));
    setValue(sourceField->value());
    setOptions(sourceField->options());
    setPlaceholderText(sourceField->placeholderText());
    setReadOnly(sourceField->readOnly());
    setMinimum(sourceField->minimum());
    setMaximum(sourceField->maximum());
    setStepSize(sourceField->stepSize());
    setSuffix(sourceField->suffix());
}

AppFormField *AppFormField::fromBaseField(BaseField *sourceField, QObject *parent)
{
    auto *field = new AppFormField(parent);
    field->setSourceField(sourceField);
    return field;
}

AppFormField::Kind AppFormField::kindFromBaseField(const BaseField *sourceField)
{
    if (!sourceField)
        return TextField;

    switch (sourceField->editorHint()) {
    case BaseField::ToggleEditor:
        return Toggle;
    case BaseField::SliderEditor:
        return Slider;
    case BaseField::SelectEditor:
        return Select;
    case BaseField::ChoiceEditor:
        return Choice;
    case BaseField::SegmentedEditor:
        return Segmented;
    case BaseField::ColorEditor:
        return Color;
    case BaseField::CustomEditor:
        return Custom;
    case BaseField::SizeEditor:
    case BaseField::TextEditor:
        return TextField;
    case BaseField::AutoEditor:
    default:
        break;
    }

    switch (sourceField->valueType()) {
    case BaseField::BoolType:
        return Toggle;
    case BaseField::EnumType:
        return Select;
    case BaseField::ColorType:
        return Color;
    default:
        return TextField;
    }
}

void AppFormField::connectSourceFieldSignals()
{
    if (!m_sourceField)
        return;

    QObject::connect(m_sourceField, &BaseField::keyChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::labelChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::subtitleChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::valueTypeChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::editorHintChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::valueChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::optionsChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::placeholderTextChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::readOnlyChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::minimumChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::maximumChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::stepSizeChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField, &BaseField::suffixChanged, this, &AppFormField::syncFromSourceField);
    QObject::connect(m_sourceField,
                     &QObject::destroyed,
                     this,
                     [this]() {
                         m_sourceField = nullptr;
                         emit sourceFieldChanged();
                     });
}

} // namespace EarthUI
