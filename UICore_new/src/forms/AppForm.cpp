#include <UICore/Forms/AppForm.h>

#include <QtGlobal>

#include <UICore/Fields/AppField.h>
#include <UICore/Forms/AppFormSection.h>

using namespace UICore;

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

UiForm::MenuBlockKind AppForm::menuBlockKind() const
{
    return UiForm::MenuBlockKind::Form;
}

UiForm::NodeKind AppForm::formNodeKind() const
{
    return UiForm::NodeKind::Form;
}

UiForm::SurfaceMode AppForm::surfaceMode() const
{
    return m_surfaceMode;
}

void AppForm::setSurfaceMode(UiForm::SurfaceMode surfaceMode)
{
    if (m_surfaceMode == surfaceMode)
        return;

    m_surfaceMode = surfaceMode;
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

UiStyle::LayoutMode AppForm::layoutMode() const
{
    return m_layoutMode;
}

void AppForm::setLayoutMode(UiStyle::LayoutMode layoutMode)
{
    if (m_layoutMode == layoutMode)
        return;

    m_layoutMode = layoutMode;
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

UiStyle::ControlAppearance AppForm::fieldAppearance() const
{
    return m_fieldAppearance;
}

void AppForm::setFieldAppearance(UiStyle::ControlAppearance fieldAppearance)
{
    if (m_fieldAppearance == fieldAppearance)
        return;

    m_fieldAppearance = fieldAppearance;
    emit fieldAppearanceChanged();
}

QVariantList AppForm::sections() const
{
    return m_sectionsCache;
}

int AppForm::sectionCount() const
{
    return m_sections.size();
}

bool AppForm::valid() const
{
    return m_valid;
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
    AppField *field = qobject_cast<AppField *>(fieldByKey(key));
    return field ? field->value() : fallback;
}

bool AppForm::setFieldValue(const QString &key, const QVariant &value)
{
    AppField *field = qobject_cast<AppField *>(fieldByKey(key));
    if (!field)
        return false;

    field->setValue(value);
    return true;
}

void AppForm::appendField(AppField *field)
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
    updateValid();
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
                     &AppFormSection::fieldValueChanged,
                     this,
                     &AppForm::fieldValueChanged);
    QObject::connect(section, &AppFormSection::validChanged, this, &AppForm::updateValid);
    QObject::connect(section,
                     &QObject::destroyed,
                     this,
                     [this](QObject *sectionObject) {
                         removeSectionObject(sectionObject);
                     });
    updateValid();
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

    if (changed) {
        updateValid();
        emitSectionsChanged();
    }
}

void AppForm::emitSectionsChanged()
{
    if (m_updateDepth > 0) {
        m_sectionsDirty = true;
        return;
    }

    emit sectionsChanged();
}

void AppForm::updateValid()
{
    bool nextValid = true;
    for (AppFormSection *section : m_sections) {
        if (section && !section->valid()) {
            nextValid = false;
            break;
        }
    }

    if (m_valid == nextValid)
        return;

    m_valid = nextValid;
    emit validChanged();
}
