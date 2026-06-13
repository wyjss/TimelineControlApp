#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

namespace EarthUI {

//! 表单中的单个字段描述，负责向 QML renderer 暴露字段 schema。
class AppFormField final : public QObject
{
    Q_OBJECT

public:
    //! 字段渲染类型，和 Foundation.AppUiEnums.FormFieldKind 对齐。
    enum Kind {
        TextField,
        Summary,
        Segmented,
        Choice,
        Toggle,
        Slider,
        Color,
        Custom,
        Chips,
        Select,
        Button
    };
    Q_ENUM(Kind)

    //! 输入控件外观模式。
    enum Appearance {
        Filled,
        Ghost
    };
    Q_ENUM(Appearance)

    //! 按钮类字段的视觉等级。
    enum Variant {
        Primary,
        Secondary,
        Tonal,
        GhostVariant,
        Nav
    };
    Q_ENUM(Variant)

    //! 字段渲染类型。
    Q_PROPERTY(Kind kind READ kind WRITE setKind NOTIFY kindChanged FINAL)
    //! 表单节点类型，和 Foundation.AppUiEnums.FormNodeKind 对齐。
    Q_PROPERTY(int formNodeKind READ formNodeKind CONSTANT FINAL)
    //! 字段稳定键，用于编辑回调和对象查找。
    Q_PROPERTY(QString key READ key WRITE setKey NOTIFY keyChanged FINAL)
    //! 字段主标签。
    Q_PROPERTY(QString label READ label WRITE setLabel NOTIFY labelChanged FINAL)
    //! 字段辅助说明。
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged FINAL)
    //! 字段当前值。
    Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged FINAL)
    //! 选择类字段的候选项。
    Q_PROPERTY(QVariantList options READ options WRITE setOptions NOTIFY optionsChanged FINAL)
    //! 摘要、chips 等列表型字段的数据项。
    Q_PROPERTY(QVariantList items READ items WRITE setItems NOTIFY itemsChanged FINAL)
    //! 文本语义色 token。
    Q_PROPERTY(QString textTone READ textTone WRITE setTextTone NOTIFY textToneChanged FINAL)
    //! 表面语义色 token。
    Q_PROPERTY(QString surfaceTone READ surfaceTone WRITE setSurfaceTone NOTIFY surfaceToneChanged FINAL)
    //! 输入控件外观。
    Q_PROPERTY(Appearance appearance READ appearance WRITE setAppearance NOTIFY appearanceChanged FINAL)
    //! 文本输入占位提示。
    Q_PROPERTY(QString placeholderText READ placeholderText WRITE setPlaceholderText NOTIFY placeholderTextChanged FINAL)
    //! 字段是否只读。
    Q_PROPERTY(bool readOnly READ readOnly WRITE setReadOnly NOTIFY readOnlyChanged FINAL)
    //! 数值字段最小值。
    Q_PROPERTY(double minimum READ minimum WRITE setMinimum NOTIFY minimumChanged FINAL)
    //! 数值字段最大值。
    Q_PROPERTY(double maximum READ maximum WRITE setMaximum NOTIFY maximumChanged FINAL)
    //! 数值字段步进。
    Q_PROPERTY(double stepSize READ stepSize WRITE setStepSize NOTIFY stepSizeChanged FINAL)
    //! 数值字段后缀文本。
    Q_PROPERTY(QString suffix READ suffix WRITE setSuffix NOTIFY suffixChanged FINAL)
    //! 按钮类字段视觉等级。
    Q_PROPERTY(Variant variant READ variant WRITE setVariant NOTIFY variantChanged FINAL)
    //! 按钮或自定义字段触发的 action 标识。
    Q_PROPERTY(QString actionId READ actionId WRITE setActionId NOTIFY actionIdChanged FINAL)
    //! action 附加数据。
    Q_PROPERTY(QVariantMap payload READ payload WRITE setPayload NOTIFY payloadChanged FINAL)
    //! 自定义字段 QML delegate 地址。
    Q_PROPERTY(QUrl delegateSource READ delegateSource WRITE setDelegateSource NOTIFY delegateSourceChanged FINAL)
    //! 自定义字段附加数据。
    Q_PROPERTY(QVariantMap customData READ customData WRITE setCustomData NOTIFY customDataChanged FINAL)

    explicit AppFormField(QObject *parent = nullptr);

    Kind kind() const;
    void setKind(Kind kind);
    int formNodeKind() const;

    QString key() const;
    void setKey(const QString &key);

    QString label() const;
    void setLabel(const QString &label);

    QString subtitle() const;
    void setSubtitle(const QString &subtitle);

    QVariant value() const;
    void setValue(const QVariant &value);

    QVariantList options() const;
    void setOptions(const QVariantList &options);

    QVariantList items() const;
    void setItems(const QVariantList &items);

    QString textTone() const;
    void setTextTone(const QString &textTone);

    QString surfaceTone() const;
    void setSurfaceTone(const QString &surfaceTone);

    Appearance appearance() const;
    void setAppearance(Appearance appearance);

    QString placeholderText() const;
    void setPlaceholderText(const QString &placeholderText);

    bool readOnly() const;
    void setReadOnly(bool readOnly);

    double minimum() const;
    void setMinimum(double minimum);

    double maximum() const;
    void setMaximum(double maximum);

    double stepSize() const;
    void setStepSize(double stepSize);

    QString suffix() const;
    void setSuffix(const QString &suffix);

    Variant variant() const;
    void setVariant(Variant variant);

    QString actionId() const;
    void setActionId(const QString &actionId);

    QVariantMap payload() const;
    void setPayload(const QVariantMap &payload);

    QUrl delegateSource() const;
    void setDelegateSource(const QUrl &delegateSource);

    QVariantMap customData() const;
    void setCustomData(const QVariantMap &customData);

signals:
    void kindChanged();
    void keyChanged();
    void labelChanged();
    void subtitleChanged();
    void valueChanged();
    void optionsChanged();
    void itemsChanged();
    void textToneChanged();
    void surfaceToneChanged();
    void appearanceChanged();
    void placeholderTextChanged();
    void readOnlyChanged();
    void minimumChanged();
    void maximumChanged();
    void stepSizeChanged();
    void suffixChanged();
    void variantChanged();
    void actionIdChanged();
    void payloadChanged();
    void delegateSourceChanged();
    void customDataChanged();

private:
    Kind m_kind = TextField;
    QString m_key;
    QString m_label;
    QString m_subtitle;
    QVariant m_value;
    QVariantList m_options;
    QVariantList m_items;
    QString m_textTone;
    QString m_surfaceTone;
    Appearance m_appearance = Filled;
    QString m_placeholderText;
    bool m_readOnly = false;
    double m_minimum = 0.0;
    double m_maximum = 100.0;
    double m_stepSize = 1.0;
    QString m_suffix;
    Variant m_variant = Secondary;
    QString m_actionId;
    QVariantMap m_payload;
    QUrl m_delegateSource;
    QVariantMap m_customData;
};

} // namespace EarthUI

Q_DECLARE_METATYPE(EarthUI::AppFormField::Kind)
Q_DECLARE_METATYPE(EarthUI::AppFormField::Appearance)
Q_DECLARE_METATYPE(EarthUI::AppFormField::Variant)
