#pragma once

#include <QObject>
#include <QVariant>
#include <QVariantList>

namespace EarthUI {

class AppFormField;

//! 表单内的分组节点，承载字段列表和可选的 section 级布局覆盖。
class AppFormSection final : public QObject
{
    Q_OBJECT

public:
    //! section 内字段的排列方向。
    enum LayoutMode {
        //! 继承表单默认布局或由渲染器自动选择。
        Auto,
        //! 字段纵向排列。
        Vertical,
        //! 字段横向排列。
        Horizontal
    };
    Q_ENUM(LayoutMode)

    //! section 标题。
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged FINAL)
    //! 表单节点类型，和 Foundation.AppUiEnums.FormNodeKind 对齐。
    Q_PROPERTY(int formNodeKind READ formNodeKind CONSTANT FINAL)
    //! 是否允许折叠该 section。
    Q_PROPERTY(bool collapsible READ collapsible WRITE setCollapsible NOTIFY collapsibleChanged FINAL)
    //! section 当前展开状态。
    Q_PROPERTY(bool expanded READ expanded WRITE setExpanded NOTIFY expandedChanged FINAL)
    //! section 级字段排列方向。
    Q_PROPERTY(LayoutMode layoutMode READ layoutMode WRITE setLayoutMode NOTIFY layoutModeChanged FINAL)
    //! 是否显式设置过字段排列方向。
    Q_PROPERTY(bool hasExplicitLayoutMode READ hasExplicitLayoutMode NOTIFY layoutModeChanged FINAL)
    //! section 级横向布局断点。
    Q_PROPERTY(int horizontalBreakpoint READ horizontalBreakpoint WRITE setHorizontalBreakpoint NOTIFY horizontalBreakpointChanged FINAL)
    //! 是否显式设置过横向布局断点。
    Q_PROPERTY(bool hasExplicitHorizontalBreakpoint READ hasExplicitHorizontalBreakpoint NOTIFY horizontalBreakpointChanged FINAL)
    //! section 级字段标签宽度。
    Q_PROPERTY(int labelWidth READ labelWidth WRITE setLabelWidth NOTIFY labelWidthChanged FINAL)
    //! 是否显式设置过字段标签宽度。
    Q_PROPERTY(bool hasExplicitLabelWidth READ hasExplicitLabelWidth NOTIFY labelWidthChanged FINAL)
    //! section 级字段内部间距。
    Q_PROPERTY(int fieldSpacing READ fieldSpacing WRITE setFieldSpacing NOTIFY fieldSpacingChanged FINAL)
    //! 是否显式设置过字段内部间距。
    Q_PROPERTY(bool hasExplicitFieldSpacing READ hasExplicitFieldSpacing NOTIFY fieldSpacingChanged FINAL)
    //! section 内部字段组间距。
    Q_PROPERTY(int sectionSpacing READ sectionSpacing WRITE setSectionSpacing NOTIFY sectionSpacingChanged FINAL)
    //! 是否显式设置过字段组间距。
    Q_PROPERTY(bool hasExplicitSectionSpacing READ hasExplicitSectionSpacing NOTIFY sectionSpacingChanged FINAL)
    //! 是否显示字段分隔线。
    Q_PROPERTY(bool showFieldDividers READ showFieldDividers WRITE setShowFieldDividers NOTIFY showFieldDividersChanged FINAL)
    //! 是否显式设置过字段分隔线。
    Q_PROPERTY(bool hasExplicitShowFieldDividers READ hasExplicitShowFieldDividers NOTIFY showFieldDividersChanged FINAL)
    //! 是否显示字段下划线。
    Q_PROPERTY(bool showFieldUnderline READ showFieldUnderline WRITE setShowFieldUnderline NOTIFY showFieldUnderlineChanged FINAL)
    //! 是否显式设置过字段下划线。
    Q_PROPERTY(bool hasExplicitShowFieldUnderline READ hasExplicitShowFieldUnderline NOTIFY showFieldUnderlineChanged FINAL)
    //! section 包含的字段列表。
    Q_PROPERTY(QVariantList fields READ fields NOTIFY fieldsChanged FINAL)
    //! section 当前字段数量，避免 QML 为了计数读取并复制整个 fields。
    Q_PROPERTY(int fieldCount READ fieldCount NOTIFY fieldsChanged FINAL)

    explicit AppFormSection(QObject *parent = nullptr);

    QString title() const;
    void setTitle(const QString &title);

    int formNodeKind() const;

    bool collapsible() const;
    void setCollapsible(bool collapsible);

    bool expanded() const;
    void setExpanded(bool expanded);

    LayoutMode layoutMode() const;
    void setLayoutMode(LayoutMode layoutMode);
    bool hasExplicitLayoutMode() const;

    int horizontalBreakpoint() const;
    void setHorizontalBreakpoint(int horizontalBreakpoint);
    bool hasExplicitHorizontalBreakpoint() const;

    int labelWidth() const;
    void setLabelWidth(int labelWidth);
    bool hasExplicitLabelWidth() const;

    int fieldSpacing() const;
    void setFieldSpacing(int fieldSpacing);
    bool hasExplicitFieldSpacing() const;

    int sectionSpacing() const;
    void setSectionSpacing(int sectionSpacing);
    bool hasExplicitSectionSpacing() const;

    bool showFieldDividers() const;
    void setShowFieldDividers(bool showFieldDividers);
    bool hasExplicitShowFieldDividers() const;

    bool showFieldUnderline() const;
    void setShowFieldUnderline(bool showFieldUnderline);
    bool hasExplicitShowFieldUnderline() const;

    QVariantList fields() const;
    int fieldCount() const;
    Q_INVOKABLE QObject *fieldAt(int index) const;
    Q_INVOKABLE QObject *fieldByKey(const QString &key) const;
    Q_INVOKABLE QVariant fieldValue(const QString &key, const QVariant &fallback = QVariant()) const;
    Q_INVOKABLE bool setFieldValue(const QString &key, const QVariant &value);
    void appendField(AppFormField *field);
    void appendFields(const QVariantList &fields);
    void clearFields();
    void beginUpdate();
    void endUpdate();

signals:
    void titleChanged();
    void collapsibleChanged();
    void expandedChanged();
    void layoutModeChanged();
    void horizontalBreakpointChanged();
    void labelWidthChanged();
    void fieldSpacingChanged();
    void sectionSpacingChanged();
    void showFieldDividersChanged();
    void showFieldUnderlineChanged();
    void fieldsChanged();

private:
    bool appendFieldObject(AppFormField *field);
    void removeFieldObject(QObject *fieldObject);
    void emitFieldsChanged();

    QString m_title;
    bool m_collapsible = false;
    bool m_expanded = true;
    LayoutMode m_layoutMode = Horizontal;
    bool m_hasExplicitLayoutMode = false;
    int m_horizontalBreakpoint = 840;
    bool m_hasExplicitHorizontalBreakpoint = false;
    int m_labelWidth = 156;
    bool m_hasExplicitLabelWidth = false;
    int m_fieldSpacing = 12;
    bool m_hasExplicitFieldSpacing = false;
    int m_sectionSpacing = 12;
    bool m_hasExplicitSectionSpacing = false;
    bool m_showFieldDividers = false;
    bool m_hasExplicitShowFieldDividers = false;
    bool m_showFieldUnderline = false;
    bool m_hasExplicitShowFieldUnderline = false;
    QList<AppFormField *> m_fields;
    QVariantList m_fieldsCache;
    int m_updateDepth = 0;
    bool m_fieldsDirty = false;
};

} // namespace EarthUI

Q_DECLARE_METATYPE(EarthUI::AppFormSection *)
Q_DECLARE_METATYPE(EarthUI::AppFormSection::LayoutMode)
