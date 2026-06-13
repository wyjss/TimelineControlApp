#include "AppForm.h"

#include <QtGlobal>

#include "AppFormSection.h"

namespace {

EarthUI::AppForm::SurfaceMode normalizeSurfaceMode(EarthUI::AppForm::SurfaceMode surfaceMode)
{
    switch (surfaceMode) {
    case EarthUI::AppForm::Bare:
        return EarthUI::AppForm::Bare;
    case EarthUI::AppForm::Flat:
        return EarthUI::AppForm::Flat;
    case EarthUI::AppForm::Section:
    default:
        return EarthUI::AppForm::Section;
    }
}

EarthUI::AppForm::LayoutMode normalizeLayoutMode(EarthUI::AppForm::LayoutMode layoutMode)
{
    switch (layoutMode) {
    case EarthUI::AppForm::Auto:
    case EarthUI::AppForm::Vertical:
    case EarthUI::AppForm::Horizontal:
        return layoutMode;
    default:
        return EarthUI::AppForm::Horizontal;
    }
}

} // namespace

namespace EarthUI {

AppForm::AppForm(QObject *parent)
    : QObject(parent)
{
}

QString AppForm::title() const
{
    return m_title;
}

void AppForm::setTitle(const QString &title)
{
    if (m_title == title)
        return;

    m_title = title;
    emit titleChanged();
}

QString AppForm::subtitle() const
{
    return m_subtitle;
}

void AppForm::setSubtitle(const QString &subtitle)
{
    if (m_subtitle == subtitle)
        return;

    m_subtitle = subtitle;
    emit subtitleChanged();
}

int AppForm::menuBlockKind() const
{
    return 0;
}

int AppForm::formNodeKind() const
{
    return 0;
}

AppForm::SurfaceMode AppForm::surfaceMode() const
{
    return m_surfaceMode;
}

void AppForm::setSurfaceMode(SurfaceMode surfaceMode)
{
    const SurfaceMode resolvedMode = normalizeSurfaceMode(surfaceMode);
    if (m_surfaceMode == resolvedMode)
        return;

    m_surfaceMode = resolvedMode;
    emit surfaceModeChanged();
}

bool AppForm::collapsible() const
{
    return m_collapsible;
}

void AppForm::setCollapsible(bool collapsible)
{
    if (m_collapsible == collapsible)
        return;

    m_collapsible = collapsible;
    emit collapsibleChanged();
}

bool AppForm::expanded() const
{
    return m_expanded;
}

void AppForm::setExpanded(bool expanded)
{
    if (m_expanded == expanded)
        return;

    m_expanded = expanded;
    emit expandedChanged();
}

bool AppForm::showHeaderDivider() const
{
    return m_showHeaderDivider;
}

void AppForm::setShowHeaderDivider(bool showHeaderDivider)
{
    if (m_hasExplicitHeaderDivider && m_showHeaderDivider == showHeaderDivider)
        return;

    m_showHeaderDivider = showHeaderDivider;
    m_hasExplicitHeaderDivider = true;
    emit showHeaderDividerChanged();
}

bool AppForm::hasExplicitHeaderDivider() const
{
    return m_hasExplicitHeaderDivider;
}

bool AppForm::showFieldDividers() const
{
    return m_showFieldDividers;
}

void AppForm::setShowFieldDividers(bool showFieldDividers)
{
    if (m_showFieldDividers == showFieldDividers)
        return;

    m_showFieldDividers = showFieldDividers;
    emit showFieldDividersChanged();
}

AppForm::LayoutMode AppForm::layoutMode() const
{
    return m_layoutMode;
}

void AppForm::setLayoutMode(LayoutMode layoutMode)
{
    const LayoutMode normalizedMode = normalizeLayoutMode(layoutMode);
    if (m_layoutMode == normalizedMode)
        return;

    m_layoutMode = normalizedMode;
    emit layoutModeChanged();
}

int AppForm::horizontalBreakpoint() const
{
    return m_horizontalBreakpoint;
}

void AppForm::setHorizontalBreakpoint(int horizontalBreakpoint)
{
    const int normalizedBreakpoint = qMax(0, horizontalBreakpoint);
    if (m_horizontalBreakpoint == normalizedBreakpoint)
        return;

    m_horizontalBreakpoint = normalizedBreakpoint;
    emit horizontalBreakpointChanged();
}

int AppForm::labelWidth() const
{
    return m_labelWidth;
}

void AppForm::setLabelWidth(int labelWidth)
{
    const int normalizedLabelWidth = qMax(0, labelWidth);
    if (m_labelWidth == normalizedLabelWidth)
        return;

    m_labelWidth = normalizedLabelWidth;
    emit labelWidthChanged();
}

int AppForm::fieldSpacing() const
{
    return m_fieldSpacing;
}

void AppForm::setFieldSpacing(int fieldSpacing)
{
    const int normalizedFieldSpacing = qMax(0, fieldSpacing);
    if (m_fieldSpacing == normalizedFieldSpacing)
        return;

    m_fieldSpacing = normalizedFieldSpacing;
    emit fieldSpacingChanged();
}

int AppForm::sectionSpacing() const
{
    return m_sectionSpacing;
}

void AppForm::setSectionSpacing(int sectionSpacing)
{
    const int normalizedSectionSpacing = qMax(0, sectionSpacing);
    if (m_sectionSpacing == normalizedSectionSpacing)
        return;

    m_sectionSpacing = normalizedSectionSpacing;
    emit sectionSpacingChanged();
}

bool AppForm::showFieldUnderline() const
{
    return m_showFieldUnderline;
}

void AppForm::setShowFieldUnderline(bool showFieldUnderline)
{
    if (m_showFieldUnderline == showFieldUnderline)
        return;

    m_showFieldUnderline = showFieldUnderline;
    emit showFieldUnderlineChanged();
}

QVariantList AppForm::sections() const
{
    QVariantList values;
    values.reserve(m_sections.size());

    for (AppFormSection *section : m_sections)
        values.append(QVariant::fromValue(static_cast<QObject *>(section)));

    return values;
}

void AppForm::appendField(AppFormField *field)
{
    if (!field)
        return;

    ensureDefaultSection()->appendField(field);
}

void AppForm::appendSection(AppFormSection *section)
{
    if (!section || m_sections.contains(section))
        return;

    if (!section->parent())
        section->setParent(this);

    m_sections.append(section);
    emit sectionsChanged();
}

void AppForm::clearSections()
{
    if (m_sections.isEmpty())
        return;

    const QList<AppFormSection *> sectionsToRemove = m_sections;
    m_sections.clear();
    m_defaultSection = nullptr;
    emit sectionsChanged();

    for (AppFormSection *section : sectionsToRemove) {
        if (section && section->parent() == this)
            section->deleteLater();
    }
}

AppFormSection *AppForm::ensureDefaultSection()
{
    if (m_defaultSection && m_sections.contains(m_defaultSection))
        return m_defaultSection;

    auto *section = new AppFormSection(this);
    m_defaultSection = section;
    m_sections.append(section);
    emit sectionsChanged();
    return section;
}

} // namespace EarthUI
