#include "AppForm.h"

#include <QtGlobal>

#include "AppFormField.h"
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
    return m_sectionsCache;
}

int AppForm::sectionCount() const
{
    return m_sections.size();
}

QObject *AppForm::sectionAt(int index) const
{
    if (index < 0 || index >= m_sections.size())
        return nullptr;

    return m_sections.at(index);
}

QObject *AppForm::fieldByKey(const QString &key) const
{
    for (AppFormSection *section : m_sections) {
        if (!section)
            continue;

        QObject *field = section->fieldByKey(key);
        if (field)
            return field;
    }

    return nullptr;
}

QVariant AppForm::fieldValue(const QString &key, const QVariant &fallback) const
{
    AppFormField *field = qobject_cast<AppFormField *>(fieldByKey(key));
    return field ? field->value() : fallback;
}

bool AppForm::setFieldValue(const QString &key, const QVariant &value)
{
    AppFormField *field = qobject_cast<AppFormField *>(fieldByKey(key));
    if (!field)
        return false;

    field->setValue(value);
    return true;
}

void AppForm::appendField(AppFormField *field)
{
    if (!field)
        return;

    ensureDefaultSection()->appendField(field);
}

void AppForm::appendFields(const QVariantList &fields)
{
    if (fields.isEmpty())
        return;

    AppFormSection *section = ensureDefaultSection();
    section->beginUpdate();
    section->appendFields(fields);
    section->endUpdate();
}

void AppForm::appendSection(AppFormSection *section)
{
    appendSectionObject(section);
}

void AppForm::appendSections(const QVariantList &sections)
{
    if (sections.isEmpty())
        return;

    beginUpdate();
    for (const QVariant &value : sections) {
        QObject *object = value.value<QObject *>();
        appendSectionObject(qobject_cast<AppFormSection *>(object));
    }
    endUpdate();
}

void AppForm::clearSections()
{
    if (m_sections.isEmpty())
        return;

    const QList<AppFormSection *> sectionsToRemove = m_sections;
    m_sections.clear();
    m_sectionsCache.clear();
    m_defaultSection = nullptr;
    emitSectionsChanged();

    for (AppFormSection *section : sectionsToRemove) {
        if (!section)
            continue;

        QObject::disconnect(section, nullptr, this, nullptr);
        if (section->parent() == this)
            section->deleteLater();
    }
}

void AppForm::beginUpdate()
{
    ++m_updateDepth;
}

void AppForm::endUpdate()
{
    if (m_updateDepth <= 0)
        return;

    --m_updateDepth;
    if (m_updateDepth == 0 && m_sectionsDirty) {
        m_sectionsDirty = false;
        emit sectionsChanged();
    }
}

AppFormSection *AppForm::ensureDefaultSection()
{
    if (m_defaultSection && m_sections.contains(m_defaultSection))
        return m_defaultSection;

    auto *section = new AppFormSection(this);
    m_defaultSection = section;
    appendSectionObject(section);
    return section;
}

bool AppForm::appendSectionObject(AppFormSection *section)
{
    if (!section || m_sections.contains(section))
        return false;

    if (!section->parent())
        section->setParent(this);

    m_sections.append(section);
    m_sectionsCache.append(QVariant::fromValue(static_cast<QObject *>(section)));
    QObject::connect(section,
                     &QObject::destroyed,
                     this,
                     [this](QObject *sectionObject) {
                         removeSectionObject(sectionObject);
                     });
    emitSectionsChanged();
    return true;
}

void AppForm::removeSectionObject(QObject *sectionObject)
{
    bool changed = false;
    for (int index = 0; index < m_sections.size(); ++index) {
        if (m_sections.at(index) != sectionObject)
            continue;

        if (m_defaultSection == sectionObject)
            m_defaultSection = nullptr;

        m_sections.removeAt(index);
        if (index < m_sectionsCache.size())
            m_sectionsCache.removeAt(index);
        changed = true;
        break;
    }

    if (changed)
        emitSectionsChanged();
}

void AppForm::emitSectionsChanged()
{
    if (m_updateDepth > 0) {
        m_sectionsDirty = true;
        return;
    }

    emit sectionsChanged();
}

} // namespace EarthUI
