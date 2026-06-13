#pragma once

#include <QObject>
#include <QVariantList>

namespace EarthUI {

class AppFormField;
class AppFormSection;

//! 菜单或 inspector 中的标准表单 block，承载 section 和表单级布局默认值。
class AppForm final : public QObject
{
    Q_OBJECT

public:
    //! 表单 block 的外层呈现方式。
    enum SurfaceMode {
        //! 显示标准 block surface 与常规内边距。
        Section,
        //! 隐藏 block surface，但保留紧凑内边距。
        Flat,
        //! 隐藏 block surface，并移除 block 内边距与间距。
        Bare
    };
    Q_ENUM(SurfaceMode)

    //! 表单字段的默认排列方向。
    enum LayoutMode {
        //! 由渲染器按宽度和上下文自动选择。
        Auto,
        //! 字段纵向排列。
        Vertical,
        //! 字段横向排列。
        Horizontal
    };
    Q_ENUM(LayoutMode)

    //! 表单 block 标题。
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged FINAL)
    //! 表单 block 副标题。
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged FINAL)
    //! 菜单 block 类型，和 Foundation.AppUiEnums.MenuBlockKind 对齐。
    Q_PROPERTY(int menuBlockKind READ menuBlockKind CONSTANT FINAL)
    //! 表单节点类型，和 Foundation.AppUiEnums.FormNodeKind 对齐。
    Q_PROPERTY(int formNodeKind READ formNodeKind CONSTANT FINAL)
    //! 表单 block 外层 chrome 模式。
    Q_PROPERTY(SurfaceMode surfaceMode READ surfaceMode WRITE setSurfaceMode NOTIFY surfaceModeChanged FINAL)
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
    Q_PROPERTY(LayoutMode layoutMode READ layoutMode WRITE setLayoutMode NOTIFY layoutModeChanged FINAL)
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
    //! 表单包含的 section 列表。
    Q_PROPERTY(QVariantList sections READ sections NOTIFY sectionsChanged FINAL)

    explicit AppForm(QObject *parent = nullptr);

    QString title() const;
    void setTitle(const QString &title);

    QString subtitle() const;
    void setSubtitle(const QString &subtitle);

    int menuBlockKind() const;
    int formNodeKind() const;

    SurfaceMode surfaceMode() const;
    void setSurfaceMode(SurfaceMode surfaceMode);

    bool collapsible() const;
    void setCollapsible(bool collapsible);

    bool expanded() const;
    void setExpanded(bool expanded);

    bool showHeaderDivider() const;
    void setShowHeaderDivider(bool showHeaderDivider);
    bool hasExplicitHeaderDivider() const;

    bool showFieldDividers() const;
    void setShowFieldDividers(bool showFieldDividers);

    LayoutMode layoutMode() const;
    void setLayoutMode(LayoutMode layoutMode);

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

    QVariantList sections() const;
    void appendField(AppFormField *field);
    void appendSection(AppFormSection *section);
    void clearSections();

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
    void sectionsChanged();

private:
    AppFormSection *ensureDefaultSection();

    QString m_title;
    QString m_subtitle;
    SurfaceMode m_surfaceMode = Section;
    bool m_collapsible = false;
    bool m_expanded = true;
    bool m_showHeaderDivider = true;
    bool m_hasExplicitHeaderDivider = true;
    bool m_showFieldDividers = true;
    LayoutMode m_layoutMode = Horizontal;
    int m_horizontalBreakpoint = 840;
    int m_labelWidth = 156;
    int m_fieldSpacing = 12;
    int m_sectionSpacing = 12;
    bool m_showFieldUnderline = false;
    QList<AppFormSection *> m_sections;
    AppFormSection *m_defaultSection = nullptr;
};

} // namespace EarthUI

Q_DECLARE_METATYPE(EarthUI::AppForm::SurfaceMode)
Q_DECLARE_METATYPE(EarthUI::AppForm::LayoutMode)
