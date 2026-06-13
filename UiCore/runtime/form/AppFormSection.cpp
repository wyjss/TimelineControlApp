#include "AppFormSection.h"

#include <QtGlobal>

#include "AppFormField.h"

namespace EarthUI {

namespace {

AppFormSection::LayoutMode normalizeLayoutMode(AppFormSection::LayoutMode layoutMode)
{
    switch (layoutMode) {
    case AppFormSection::Auto:
    case AppFormSection::Vertical:
    case AppFormSection::Horizontal:
        return layoutMode;
    default:
        return AppFormSection::Horizontal;
    }
}

} // namespace

AppFormSection::AppFormSection(QObject *parent)
    : QObject(parent)
{
}

QString AppFormSection::title() const
{
    return m_title;
}

void AppFormSection::setTitle(const QString &title)
{
    if (m_title == title)
        return;

    m_title = title;
    emit titleChanged();
}

int AppFormSection::formNodeKind() const
{
    return 1;
}

bool AppFormSection::collapsible() const
{
    return m_collapsible;
}

void AppFormSection::setCollapsible(bool collapsible)
{
    if (m_collapsible == collapsible)
        return;

    m_collapsible = collapsible;
    emit collapsibleChanged();
}

bool AppFormSection::expanded() const
{
    return m_expanded;
}

void AppFormSection::setExpanded(bool expanded)
{
    if (m_expanded == expanded)
        return;

    m_expanded = expanded;
    emit expandedChanged();
}

AppFormSection::LayoutMode AppFormSection::layoutMode() const
{
    return m_layoutMode;
}

void AppFormSection::setLayoutMode(LayoutMode layoutMode)
{
    const LayoutMode normalizedMode = normalizeLayoutMode(layoutMode);
    if (m_hasExplicitLayoutMode && m_layoutMode == normalizedMode)
        return;

    m_layoutMode = normalizedMode;
    m_hasExplicitLayoutMode = true;
    emit layoutModeChanged();
}

bool AppFormSection::hasExplicitLayoutMode() const
{
    return m_hasExplicitLayoutMode;
}

int AppFormSection::horizontalBreakpoint() const
{
    return m_horizontalBreakpoint;
}

void AppFormSection::setHorizontalBreakpoint(int horizontalBreakpoint)
{
    const int normalizedBreakpoint = qMax(0, horizontalBreakpoint);
    if (m_hasExplicitHorizontalBreakpoint && m_horizontalBreakpoint == normalizedBreakpoint)
        return;

    m_horizontalBreakpoint = normalizedBreakpoint;
    m_hasExplicitHorizontalBreakpoint = true;
    emit horizontalBreakpointChanged();
}

bool AppFormSection::hasExplicitHorizontalBreakpoint() const
{
    return m_hasExplicitHorizontalBreakpoint;
}

int AppFormSection::labelWidth() const
{
    return m_labelWidth;
}

void AppFormSection::setLabelWidth(int labelWidth)
{
    const int normalizedLabelWidth = qMax(0, labelWidth);
    if (m_hasExplicitLabelWidth && m_labelWidth == normalizedLabelWidth)
        return;

    m_labelWidth = normalizedLabelWidth;
    m_hasExplicitLabelWidth = true;
    emit labelWidthChanged();
}

bool AppFormSection::hasExplicitLabelWidth() const
{
    return m_hasExplicitLabelWidth;
}

int AppFormSection::fieldSpacing() const
{
    return m_fieldSpacing;
}

void AppFormSection::setFieldSpacing(int fieldSpacing)
{
    const int normalizedFieldSpacing = qMax(0, fieldSpacing);
    if (m_hasExplicitFieldSpacing && m_fieldSpacing == normalizedFieldSpacing)
        return;

    m_fieldSpacing = normalizedFieldSpacing;
    m_hasExplicitFieldSpacing = true;
    emit fieldSpacingChanged();
}

bool AppFormSection::hasExplicitFieldSpacing() const
{
    return m_hasExplicitFieldSpacing;
}

int AppFormSection::sectionSpacing() const
{
    return m_sectionSpacing;
}

void AppFormSection::setSectionSpacing(int sectionSpacing)
{
    const int normalizedSectionSpacing = qMax(0, sectionSpacing);
    if (m_hasExplicitSectionSpacing && m_sectionSpacing == normalizedSectionSpacing)
        return;

    m_sectionSpacing = normalizedSectionSpacing;
    m_hasExplicitSectionSpacing = true;
    emit sectionSpacingChanged();
}

bool AppFormSection::hasExplicitSectionSpacing() const
{
    return m_hasExplicitSectionSpacing;
}

bool AppFormSection::showFieldDividers() const
{
    return m_showFieldDividers;
}

void AppFormSection::setShowFieldDividers(bool showFieldDividers)
{
    if (m_hasExplicitShowFieldDividers && m_showFieldDividers == showFieldDividers)
        return;

    m_showFieldDividers = showFieldDividers;
    m_hasExplicitShowFieldDividers = true;
    emit showFieldDividersChanged();
}

bool AppFormSection::hasExplicitShowFieldDividers() const
{
    return m_hasExplicitShowFieldDividers;
}

bool AppFormSection::showFieldUnderline() const
{
    return m_showFieldUnderline;
}

void AppFormSection::setShowFieldUnderline(bool showFieldUnderline)
{
    if (m_hasExplicitShowFieldUnderline && m_showFieldUnderline == showFieldUnderline)
        return;

    m_showFieldUnderline = showFieldUnderline;
    m_hasExplicitShowFieldUnderline = true;
    emit showFieldUnderlineChanged();
}

bool AppFormSection::hasExplicitShowFieldUnderline() const
{
    return m_hasExplicitShowFieldUnderline;
}

QVariantList AppFormSection::fields() const
{
    QVariantList values;
    values.reserve(m_fields.size());

    for (AppFormField *field : m_fields)
        values.append(QVariant::fromValue(static_cast<QObject *>(field)));

    return values;
}

void AppFormSection::appendField(AppFormField *field)
{
    if (!field || m_fields.contains(field))
        return;

    if (!field->parent())
        field->setParent(this);

    m_fields.append(field);
    emit fieldsChanged();
}

void AppFormSection::clearFields()
{
    if (m_fields.isEmpty())
        return;

    const QList<AppFormField *> fieldsToRemove = m_fields;
    m_fields.clear();
    emit fieldsChanged();

    for (AppFormField *field : fieldsToRemove) {
        if (field && field->parent() == this)
            field->deleteLater();
    }
}

} // namespace EarthUI
