#include "AppFormField.h"

#include <QtGlobal>

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

} // namespace EarthUI
