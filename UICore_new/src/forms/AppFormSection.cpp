#include <UICore/Forms/AppFormSection.h>

#include <QtGlobal>

#include <UICore/Fields/AppField.h>

using namespace UICore;

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

UiForm::NodeKind AppFormSection::formNodeKind() const
{
    return UiForm::NodeKind::Section;
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

UiStyle::LayoutMode AppFormSection::layoutMode() const
{
    return m_layoutMode;
}

void AppFormSection::setLayoutMode(UiStyle::LayoutMode layoutMode)
{
    if (m_hasExplicitLayoutMode && m_layoutMode == layoutMode)
        return;

    m_layoutMode = layoutMode;
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

UiStyle::ControlAppearance AppFormSection::fieldAppearance() const
{
    return m_fieldAppearance;
}

void AppFormSection::setFieldAppearance(UiStyle::ControlAppearance fieldAppearance)
{
    if (m_hasExplicitFieldAppearance && m_fieldAppearance == fieldAppearance)
        return;

    m_fieldAppearance = fieldAppearance;
    m_hasExplicitFieldAppearance = true;
    emit fieldAppearanceChanged();
}

bool AppFormSection::hasExplicitFieldAppearance() const
{
    return m_hasExplicitFieldAppearance;
}

QVariantList AppFormSection::fields() const
{
    return m_fieldsCache;
}

int AppFormSection::fieldCount() const
{
    return m_fields.size();
}

bool AppFormSection::valid() const
{
    return m_valid;
}

QObject *AppFormSection::fieldAt(int index) const
{
    if (index < 0 || index >= m_fields.size())
        return nullptr;

    return m_fields.at(index);
}

QObject *AppFormSection::fieldByKey(const QString &key) const
{
    const QString normalizedKey = key.trimmed();
    if (normalizedKey.isEmpty())
        return nullptr;

    for (AppField *field : m_fields) {
        if (field && field->key() == normalizedKey)
            return field;
    }

    return nullptr;
}

QVariant AppFormSection::fieldValue(const QString &key, const QVariant &fallback) const
{
    AppField *field = qobject_cast<AppField *>(fieldByKey(key));
    return field ? field->value() : fallback;
}

bool AppFormSection::setFieldValue(const QString &key, const QVariant &value)
{
    AppField *field = qobject_cast<AppField *>(fieldByKey(key));
    if (!field)
        return false;

    field->setValue(value);
    return true;
}

void AppFormSection::appendField(AppField *field)
{
    appendFieldObject(field);
}

void AppFormSection::appendFields(const QVariantList &fields)
{
    if (fields.isEmpty())
        return;

    beginUpdate();
    for (const QVariant &value : fields) {
        QObject *object = value.value<QObject *>();
        appendFieldObject(qobject_cast<AppField *>(object));
    }
    endUpdate();
}

void AppFormSection::clearFields()
{
    if (m_fields.isEmpty())
        return;

    const QList<AppField *> fieldsToRemove = m_fields;
    m_fields.clear();
    m_fieldsCache.clear();
    updateValid();
    emitFieldsChanged();

    for (AppField *field : fieldsToRemove) {
        if (!field)
            continue;

        QObject::disconnect(field, nullptr, this, nullptr);
        if (field->parent() == this)
            field->deleteLater();
    }
}

void AppFormSection::beginUpdate()
{
    ++m_updateDepth;
}

void AppFormSection::endUpdate()
{
    if (m_updateDepth <= 0)
        return;

    --m_updateDepth;
    if (m_updateDepth == 0 && m_fieldsDirty) {
        m_fieldsDirty = false;
        emit fieldsChanged();
    }
}

bool AppFormSection::appendFieldObject(AppField *field)
{
    if (!field || m_fields.contains(field))
        return false;

    if (!field->parent())
        field->setParent(this);

    m_fields.append(field);
    m_fieldsCache.append(QVariant::fromValue(static_cast<QObject *>(field)));
    QObject::connect(field,
                     &AppField::valueChanged,
                     this,
                     [this, field]() {
                         emit fieldValueChanged(field->key(), field->value());
                     });
    QObject::connect(field, &AppField::validChanged, this, &AppFormSection::updateValid);
    QObject::connect(field,
                     &QObject::destroyed,
                     this,
                     [this](QObject *fieldObject) {
                         removeFieldObject(fieldObject);
                     });
    updateValid();
    emitFieldsChanged();
    return true;
}

void AppFormSection::removeFieldObject(QObject *fieldObject)
{
    bool changed = false;
    for (int index = 0; index < m_fields.size(); ++index) {
        if (m_fields.at(index) != fieldObject)
            continue;

        m_fields.removeAt(index);
        if (index < m_fieldsCache.size())
            m_fieldsCache.removeAt(index);
        changed = true;
        break;
    }

    if (changed) {
        updateValid();
        emitFieldsChanged();
    }
}

void AppFormSection::emitFieldsChanged()
{
    if (m_updateDepth > 0) {
        m_fieldsDirty = true;
        return;
    }

    emit fieldsChanged();
}

void AppFormSection::updateValid()
{
    bool nextValid = true;
    for (AppField *field : m_fields) {
        if (field && !field->valid()) {
            nextValid = false;
            break;
        }
    }

    if (m_valid == nextValid)
        return;

    m_valid = nextValid;
    emit validChanged();
}
