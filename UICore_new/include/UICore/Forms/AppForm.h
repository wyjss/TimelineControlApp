#pragma once

#include <QObject>
#include <QVariant>
#include <QVariantList>

#include <UICore/Forms/UiFormEnums.h>
#include <UICore/Style/UiStyleEnums.h>

namespace UICore {

class AppField;
class AppFormSection;

//! 菜单或其它面板中的标准表单 block，承载 section 和表单级布局默认值。
class AppForm final : public QObject
{
    Q_OBJECT

public:
    //! 表单 block 标题。
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged FINAL)
    //! 表单 block 副标题。
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged FINAL)
    //! 菜单 block 类型。
    Q_PROPERTY(UICore::UiForm::MenuBlockKind menuBlockKind READ menuBlockKind CONSTANT FINAL)
    //! 表单节点类型。
    Q_PROPERTY(UICore::UiForm::NodeKind formNodeKind READ formNodeKind CONSTANT FINAL)
    //! 表单 block 外层 chrome 模式。
    Q_PROPERTY(UICore::UiForm::SurfaceMode surfaceMode READ surfaceMode WRITE setSurfaceMode NOTIFY surfaceModeChanged FINAL)
    //! 是否允许折叠整个表单 block。
    Q_PROPERTY(bool collapsible READ collapsible WRITE setCollapsible NOTIFY collapsibleChanged FINAL)
    //! 表单 block 当前展开状态。
    Q_PROPERTY(bool expanded READ expanded WRITE setExpanded NOTIFY expandedChanged FINAL)
    //! 是否显示 block 标题与内容之间的分隔线。
    Q_PROPERTY(bool showHeaderDivider READ showHeaderDivider WRITE setShowHeaderDivider NOTIFY showHeaderDividerChanged FINAL)
    //! 是否显式设置过标题分隔线。
    Q_PROPERTY(bool hasExplicitHeaderDivider READ hasExplicitHeaderDivider NOTIFY showHeaderDividerChanged FINAL)
    //! 是否显示字段之间的分隔线。
    Q_PROPERTY(bool showFieldDividers READ showFieldDividers WRITE setShowFieldDividers NOTIFY showFieldDividersChanged FINAL)
    //! section 未覆盖时使用的默认字段排列方向。
    Q_PROPERTY(UICore::UiStyle::LayoutMode layoutMode READ layoutMode WRITE setLayoutMode NOTIFY layoutModeChanged FINAL)
    //! 自动布局切换到横向排列的最小宽度。
    Q_PROPERTY(int horizontalBreakpoint READ horizontalBreakpoint WRITE setHorizontalBreakpoint NOTIFY horizontalBreakpointChanged FINAL)
    //! 字段标签默认宽度。
    Q_PROPERTY(int labelWidth READ labelWidth WRITE setLabelWidth NOTIFY labelWidthChanged FINAL)
    //! 字段内部默认间距。
    Q_PROPERTY(int fieldSpacing READ fieldSpacing WRITE setFieldSpacing NOTIFY fieldSpacingChanged FINAL)
    //! section 之间的默认间距。
    Q_PROPERTY(int sectionSpacing READ sectionSpacing WRITE setSectionSpacing NOTIFY sectionSpacingChanged FINAL)
    //! 是否显示字段下划线。
    Q_PROPERTY(bool showFieldUnderline READ showFieldUnderline WRITE setShowFieldUnderline NOTIFY showFieldUnderlineChanged FINAL)
    //! 字段输入控件的默认外观。
    Q_PROPERTY(UICore::UiStyle::ControlAppearance fieldAppearance READ fieldAppearance WRITE setFieldAppearance NOTIFY fieldAppearanceChanged FINAL)
    //! 表单包含的 section 列表。
    Q_PROPERTY(QVariantList sections READ sections NOTIFY sectionsChanged FINAL)
    //! section 数量，避免 QML 为了计数读取并复制整个 sections。
    Q_PROPERTY(int sectionCount READ sectionCount NOTIFY sectionsChanged FINAL)
    //! 表单内所有 section 当前是否有效。
    Q_PROPERTY(bool valid READ valid NOTIFY validChanged FINAL)

    explicit AppForm(QObject *parent = nullptr);

    QString title() const;
    void setTitle(const QString &title);

    QString subtitle() const;
    void setSubtitle(const QString &subtitle);

    UiForm::MenuBlockKind menuBlockKind() const;
    UiForm::NodeKind formNodeKind() const;

    UiForm::SurfaceMode surfaceMode() const;
    void setSurfaceMode(UiForm::SurfaceMode surfaceMode);

    bool collapsible() const;
    void setCollapsible(bool collapsible);

    bool expanded() const;
    void setExpanded(bool expanded);

    bool showHeaderDivider() const;
    void setShowHeaderDivider(bool showHeaderDivider);
    bool hasExplicitHeaderDivider() const;

    bool showFieldDividers() const;
    void setShowFieldDividers(bool showFieldDividers);

    UiStyle::LayoutMode layoutMode() const;
    void setLayoutMode(UiStyle::LayoutMode layoutMode);

    int horizontalBreakpoint() const;
    void setHorizontalBreakpoint(int horizontalBreakpoint);

    int labelWidth() const;
    void setLabelWidth(int labelWidth);

    int fieldSpacing() const;
    void setFieldSpacing(int fieldSpacing);

    int sectionSpacing() const;
    void setSectionSpacing(int sectionSpacing);

    bool showFieldUnderline() const;
    void setShowFieldUnderline(bool showFieldUnderline);

    UiStyle::ControlAppearance fieldAppearance() const;
    void setFieldAppearance(UiStyle::ControlAppearance fieldAppearance);

    QVariantList sections() const;
    int sectionCount() const;
    bool valid() const;
    Q_INVOKABLE QObject *sectionAt(int index) const;
    Q_INVOKABLE QObject *fieldByKey(const QString &key) const;
    Q_INVOKABLE QVariant fieldValue(const QString &key, const QVariant &fallback = QVariant()) const;
    Q_INVOKABLE bool setFieldValue(const QString &key, const QVariant &value);
    void appendField(AppField *field);
    void appendFields(const QVariantList &fields);
    void appendSection(AppFormSection *section);
    void appendSections(const QVariantList &sections);
    void clearSections();
    void beginUpdate();
    void endUpdate();

signals:
    void titleChanged();
    void subtitleChanged();
    void surfaceModeChanged();
    void collapsibleChanged();
    void expandedChanged();
    void showHeaderDividerChanged();
    void showFieldDividersChanged();
    void layoutModeChanged();
    void horizontalBreakpointChanged();
    void labelWidthChanged();
    void fieldSpacingChanged();
    void sectionSpacingChanged();
    void showFieldUnderlineChanged();
    void fieldAppearanceChanged();
    void sectionsChanged();
    void validChanged();
    void fieldValueChanged(const QString &fieldKey, const QVariant &value);

private:
    AppFormSection *ensureDefaultSection();
    bool appendSectionObject(AppFormSection *section);
    void removeSectionObject(QObject *sectionObject);
    void emitSectionsChanged();
    void updateValid();

    QString m_title;
    QString m_subtitle;
    UiForm::SurfaceMode m_surfaceMode = UiForm::SurfaceMode::Flat;
    bool m_collapsible = false;
    bool m_expanded = true;
    bool m_showHeaderDivider = true;
    bool m_hasExplicitHeaderDivider = false;
    bool m_showFieldDividers = false;
    UiStyle::LayoutMode m_layoutMode = UiStyle::LayoutMode::Horizontal;
    int m_horizontalBreakpoint = 840;
    int m_labelWidth = 156;
    int m_fieldSpacing = 12;
    int m_sectionSpacing = 12;
    bool m_showFieldUnderline = false;
    UiStyle::ControlAppearance m_fieldAppearance = UiStyle::ControlAppearance::Filled;
    QList<AppFormSection *> m_sections;
    QVariantList m_sectionsCache;
    AppFormSection *m_defaultSection = nullptr;
    bool m_valid = true;
    int m_updateDepth = 0;
    bool m_sectionsDirty = false;
};

} // namespace UICore

Q_DECLARE_METATYPE(UICore::AppForm *)
