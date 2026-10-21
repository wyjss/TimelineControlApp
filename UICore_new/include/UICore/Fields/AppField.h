#pragma once

#include <QObject>
#include <QPointer>
#include <QString>
#include <QUrl>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

#include <UICore/Fields/BaseField.h>
#include <UICore/Style/UiStyleEnums.h>

namespace UICore {

//! 通用 UI 字段 schema，可独立渲染，也可绑定 BaseField 作为数据源。
class AppField : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("RegisterEnumClassesUnscoped", "false")

public:
    //! 字段渲染类型。
    enum class Kind : int {
        TextField = 0,
        Summary = 1,
        Segmented = 2,
        Choice = 3,
        Toggle = 4,
        Slider = 5,
        Color = 6,
        Custom = 7,
        Chips = 8,
        Select = 9,
        Button = 10,
        TextArea = 11,
        CheckBox = 12
    };
    Q_ENUM(Kind)

    Q_PROPERTY(Kind kind READ kind WRITE setKind NOTIFY kindChanged FINAL)
    //! 字段值类型。
    Q_PROPERTY(UICore::BaseField::ValueType valueType READ valueType WRITE setValueType NOTIFY valueTypeChanged FINAL)
    //! 字段稳定键，用于编辑回调和对象查找。
    Q_PROPERTY(QString key READ key WRITE setKey NOTIFY keyChanged FINAL)
    //! 字段主标签。
    Q_PROPERTY(QString label READ label WRITE setLabel NOTIFY labelChanged FINAL)
    //! 字段辅助说明。
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged FINAL)
    //! 字段当前值。
    Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged FINAL)
    //! 字段是否必填，仅用于呈现必填标记。
    Q_PROPERTY(bool required READ required WRITE setRequired NOTIFY requiredChanged FINAL)
    //! 字段外部校验错误文本。
    Q_PROPERTY(QString errorText READ errorText WRITE setErrorText NOTIFY errorTextChanged FINAL)
    //! 字段当前是否有效，仅由 errorText 是否为空决定。
    Q_PROPERTY(bool valid READ valid NOTIFY validChanged FINAL)
    //! 选择类字段的候选项。
    Q_PROPERTY(QVariantList options READ options WRITE setOptions NOTIFY optionsChanged FINAL)
    //! 是否允许输入候选项之外的值。
    Q_PROPERTY(bool allowCustomValue READ allowCustomValue WRITE setAllowCustomValue NOTIFY allowCustomValueChanged FINAL)
    //! 摘要、chips 等列表型字段的数据项。
    Q_PROPERTY(QVariantList items READ items WRITE setItems NOTIFY itemsChanged FINAL)
    //! 文本语义色 token。
    Q_PROPERTY(UICore::UiStyle::TextTone textTone READ textTone WRITE setTextTone NOTIFY textToneChanged FINAL)
    //! 表面语义色 token。
    Q_PROPERTY(UICore::UiStyle::SurfaceTone surfaceTone READ surfaceTone WRITE setSurfaceTone NOTIFY surfaceToneChanged FINAL)
    //! 输入控件外观。
    Q_PROPERTY(UICore::UiStyle::ControlAppearance appearance READ appearance WRITE setAppearance NOTIFY appearanceChanged FINAL)
    //! 是否显式设置过输入控件外观。
    Q_PROPERTY(bool hasExplicitAppearance READ hasExplicitAppearance NOTIFY appearanceChanged FINAL)
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
    Q_PROPERTY(UICore::UiStyle::ButtonVariant variant READ variant WRITE setVariant NOTIFY variantChanged FINAL)
    //! 按钮或自定义字段触发的 action 标识。
    Q_PROPERTY(QString actionId READ actionId WRITE setActionId NOTIFY actionIdChanged FINAL)
    //! action 附加数据。
    Q_PROPERTY(QVariantMap payload READ payload WRITE setPayload NOTIFY payloadChanged FINAL)
    //! 自定义字段 QML delegate 地址。
    Q_PROPERTY(QUrl delegateSource READ delegateSource WRITE setDelegateSource NOTIFY delegateSourceChanged FINAL)
    //! 自定义字段附加数据。
    Q_PROPERTY(QVariantMap customData READ customData WRITE setCustomData NOTIFY customDataChanged FINAL)
    //! 字段数据源；默认使用内部 BaseField，也可绑定外部字段。
    Q_PROPERTY(UICore::BaseField *sourceField READ sourceField WRITE setSourceField NOTIFY sourceFieldChanged FINAL)

    explicit AppField(QObject *parent = nullptr);

    Kind kind() const;
    void setKind(Kind kind);

    BaseField::ValueType valueType() const;
    void setValueType(BaseField::ValueType valueType);

    QString key() const;
    void setKey(const QString &key);

    QString label() const;
    void setLabel(const QString &label);

    QString subtitle() const;
    void setSubtitle(const QString &subtitle);

    QVariant value() const;
    void setValue(const QVariant &value);

    bool required() const;
    void setRequired(bool required);

    QString errorText() const;
    void setErrorText(const QString &errorText);
    bool valid() const;

    QVariantList options() const;
    void setOptions(const QVariantList &options);

    bool allowCustomValue() const;
    void setAllowCustomValue(bool allowCustomValue);

    QVariantList items() const;
    void setItems(const QVariantList &items);

    UiStyle::TextTone textTone() const;
    void setTextTone(UiStyle::TextTone textTone);

    UiStyle::SurfaceTone surfaceTone() const;
    void setSurfaceTone(UiStyle::SurfaceTone surfaceTone);

    UiStyle::ControlAppearance appearance() const;
    void setAppearance(UiStyle::ControlAppearance appearance);
    bool hasExplicitAppearance() const;

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

    UiStyle::ButtonVariant variant() const;
    void setVariant(UiStyle::ButtonVariant variant);

    QString actionId() const;
    void setActionId(const QString &actionId);

    QVariantMap payload() const;
    void setPayload(const QVariantMap &payload);

    QUrl delegateSource() const;
    void setDelegateSource(const QUrl &delegateSource);

    QVariantMap customData() const;
    void setCustomData(const QVariantMap &customData);

    BaseField *sourceField() const;
    void setSourceField(BaseField *sourceField);

signals:
    void kindChanged();
    void valueTypeChanged();
    void keyChanged();
    void labelChanged();
    void subtitleChanged();
    void valueChanged();
    void requiredChanged();
    void errorTextChanged();
    void validChanged();
    void optionsChanged();
    void allowCustomValueChanged();
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
    void sourceFieldChanged();

private:
    static Kind kindFromBaseField(const BaseField *sourceField);
    void connectSourceFieldSignals();

    Kind m_kind = Kind::TextField;
    QVariantList m_items;
    UiStyle::TextTone m_textTone = UiStyle::TextTone::Primary;
    UiStyle::SurfaceTone m_surfaceTone = UiStyle::SurfaceTone::Control;
    UiStyle::ControlAppearance m_appearance = UiStyle::ControlAppearance::Filled;
    bool m_hasExplicitAppearance = false;
    UiStyle::ButtonVariant m_variant = UiStyle::ButtonVariant::Subtle;
    QString m_actionId;
    QVariantMap m_payload;
    QUrl m_delegateSource;
    QVariantMap m_customData;
    BaseField *m_ownedField = nullptr;
    QPointer<BaseField> m_sourceField;
};

} // namespace UICore

Q_DECLARE_METATYPE(UICore::AppField *)
Q_DECLARE_METATYPE(UICore::AppField::Kind)
