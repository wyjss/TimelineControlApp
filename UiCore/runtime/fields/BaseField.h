#pragma once

#include <QObject>
#include <QString>
#include <QColor>
#include <QSize>
#include <QVariant>
#include <QVariantList>

namespace EarthUI {

//! 基础字段描述，只表达字段值、约束和通用信息，不绑定具体 QML 渲染方式。
class BaseField : public QObject
{
    Q_OBJECT

public:
    //! 字段值类型，供校验、序列化和运行时执行逻辑使用。
    enum ValueType {
        InvalidType,
        BoolType,
        IntType,
        DoubleType,
        StringType,
        EnumType,
        ColorType,
        SizeType,
        VariantType
    };
    Q_ENUM(ValueType)

    //! 推荐编辑方式，只表达 UI 意图，不绑定具体 QML renderer。
    enum EditorHint {
        AutoEditor,
        TextEditor,
        SliderEditor,
        ToggleEditor,
        SelectEditor,
        ChoiceEditor,
        SegmentedEditor,
        ColorEditor,
        SizeEditor,
        CustomEditor
    };
    Q_ENUM(EditorHint)

    //! 字段稳定键，用于对象查找、值映射和编辑回调。
    Q_PROPERTY(QString key READ key WRITE setKey NOTIFY keyChanged FINAL)
    //! 字段主标签。
    Q_PROPERTY(QString label READ label WRITE setLabel NOTIFY labelChanged FINAL)
    //! 字段辅助说明。
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged FINAL)
    //! 字段值类型。
    Q_PROPERTY(ValueType valueType READ valueType WRITE setValueType NOTIFY valueTypeChanged FINAL)
    //! 推荐编辑方式，供表单适配层选择控件。
    Q_PROPERTY(EditorHint editorHint READ editorHint WRITE setEditorHint NOTIFY editorHintChanged FINAL)
    //! 字段当前值。
    Q_PROPERTY(QVariant value READ value WRITE setValue NOTIFY valueChanged FINAL)
    //! 字段默认值。
    Q_PROPERTY(QVariant defaultValue READ defaultValue WRITE setDefaultValue NOTIFY defaultValueChanged FINAL)
    //! 字段是否必填。
    Q_PROPERTY(bool required READ required WRITE setRequired NOTIFY requiredChanged FINAL)
    //! 字段是否只读。
    Q_PROPERTY(bool readOnly READ readOnly WRITE setReadOnly NOTIFY readOnlyChanged FINAL)
    //! 选择类字段的候选项。
    Q_PROPERTY(QVariantList options READ options WRITE setOptions NOTIFY optionsChanged FINAL)
    //! 文本输入占位提示。
    Q_PROPERTY(QString placeholderText READ placeholderText WRITE setPlaceholderText NOTIFY placeholderTextChanged FINAL)
    //! 字符串字段匹配模式。
    Q_PROPERTY(QString pattern READ pattern WRITE setPattern NOTIFY patternChanged FINAL)
    //! 数值字段最小值。
    Q_PROPERTY(double minimum READ minimum WRITE setMinimum NOTIFY minimumChanged FINAL)
    //! 数值字段最大值。
    Q_PROPERTY(double maximum READ maximum WRITE setMaximum NOTIFY maximumChanged FINAL)
    //! 数值字段步进。
    Q_PROPERTY(double stepSize READ stepSize WRITE setStepSize NOTIFY stepSizeChanged FINAL)
    //! 数值字段后缀文本。
    Q_PROPERTY(QString suffix READ suffix WRITE setSuffix NOTIFY suffixChanged FINAL)

    explicit BaseField(QObject *parent = nullptr);

    QString key() const;
    void setKey(const QString &key);

    QString label() const;
    void setLabel(const QString &label);

    QString subtitle() const;
    void setSubtitle(const QString &subtitle);

    ValueType valueType() const;
    void setValueType(ValueType valueType);

    EditorHint editorHint() const;
    void setEditorHint(EditorHint editorHint);

    QVariant value() const;
    void setValue(const QVariant &value);
    
    // value help
    int intValue() const { return value().toInt(); }
    double doubleValue() const { return value().toDouble(); }
    float floatValue() const { return value().toFloat(); }
    bool boolValue() const { return value().toBool(); }
    QString stringValue() const { return value().toString(); }
    QColor colorValue() const { return value().value<QColor>(); }
    QSize sizeValue() const { return value().value<QSize>(); }

    QVariant defaultValue() const;
    void setDefaultValue(const QVariant &defaultValue);

    bool required() const;
    void setRequired(bool required);

    bool readOnly() const;
    void setReadOnly(bool readOnly);

    QVariantList options() const;
    void setOptions(const QVariantList &options);

    QString placeholderText() const;
    void setPlaceholderText(const QString &placeholderText);

    QString pattern() const;
    void setPattern(const QString &pattern);

    double minimum() const;
    void setMinimum(double minimum);

    double maximum() const;
    void setMaximum(double maximum);

    double stepSize() const;
    void setStepSize(double stepSize);

    QString suffix() const;
    void setSuffix(const QString &suffix);

signals:
    void keyChanged();
    void labelChanged();
    void subtitleChanged();
    void valueTypeChanged();
    void editorHintChanged();
    void valueChanged();
    void defaultValueChanged();
    void requiredChanged();
    void readOnlyChanged();
    void optionsChanged();
    void placeholderTextChanged();
    void patternChanged();
    void minimumChanged();
    void maximumChanged();
    void stepSizeChanged();
    void suffixChanged();

private:
    QString m_key;
    QString m_label;
    QString m_subtitle;
    ValueType m_valueType = VariantType;
    EditorHint m_editorHint = AutoEditor;
    QVariant m_value;
    QVariant m_defaultValue;
    bool m_required = false;
    bool m_readOnly = false;
    QVariantList m_options;
    QString m_placeholderText;
    QString m_pattern;
    double m_minimum = 0.0;
    double m_maximum = 100.0;
    double m_stepSize = 1.0;
    QString m_suffix;
};

} // namespace EarthUI

Q_DECLARE_METATYPE(EarthUI::BaseField *)
Q_DECLARE_METATYPE(EarthUI::BaseField::ValueType)
Q_DECLARE_METATYPE(EarthUI::BaseField::EditorHint)
