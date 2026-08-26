#pragma once

#include <QVariant>

#include <UICore/Fields/BaseField.h>


class TimelineModel;


class DeviceParamSpec final : public UICore::BaseField
{
    Q_OBJECT

    //! 兼容旧 QML 展示用的字段类型名称。
    Q_PROPERTY(QString type READ typeName CONSTANT FINAL)
    Q_PROPERTY(QVariant defaultValue READ defaultValue WRITE setDefaultValue NOTIFY defaultValueChanged FINAL)
    Q_PROPERTY(QString pattern READ pattern WRITE setPattern NOTIFY patternChanged FINAL)

public:
    using ValueType = UICore::BaseField::ValueType;
    using EditorHint = UICore::BaseField::EditorHint;

    static constexpr ValueType InvalidType = UICore::BaseField::InvalidType;
    static constexpr ValueType BoolType = UICore::BaseField::BoolType;
    static constexpr ValueType IntType = UICore::BaseField::IntType;
    static constexpr ValueType DoubleType = UICore::BaseField::DoubleType;
    static constexpr ValueType StringType = UICore::BaseField::StringType;
    static constexpr ValueType SelectType = UICore::BaseField::EnumType;
    static constexpr ValueType ColorType = UICore::BaseField::ColorType;
    static constexpr ValueType VariantType = UICore::BaseField::VariantType;

    static constexpr EditorHint AutoEditor = UICore::BaseField::AutoEditor;
    static constexpr EditorHint TextEditor = UICore::BaseField::TextEditor;
    static constexpr EditorHint SliderEditor = UICore::BaseField::SliderEditor;
    static constexpr EditorHint ToggleEditor = UICore::BaseField::ToggleEditor;
    static constexpr EditorHint SelectEditor = UICore::BaseField::SelectEditor;
    static constexpr EditorHint ChoiceEditor = UICore::BaseField::ChoiceEditor;
    static constexpr EditorHint SegmentedEditor = UICore::BaseField::SegmentedEditor;
    static constexpr EditorHint ColorEditor = UICore::BaseField::ColorEditor;
    static constexpr EditorHint CustomEditor = UICore::BaseField::CustomEditor;

    explicit DeviceParamSpec(QObject *parent = nullptr);
    DeviceParamSpec(const QString &key,
                    const QString &label,
                    const QVariant &value = QVariant(),
                    ValueType valueType = VariantType,
                    EditorHint editorHint = AutoEditor,
                    QObject *parent = nullptr);

    QVariant defaultValue() const;
    void setDefaultValue(const QVariant &defaultValue);
    QString pattern() const;
    void setPattern(const QString &pattern);

    QString typeName() const;
    DeviceParamSpec *clone(QObject *parent = nullptr) const;
    Q_INVOKABLE QString invalidReason(const QVariant &value = QVariant()) const;

    static QString typeName(ValueType valueType);
    static DeviceParamSpec *createForKey(const QString &deviceKey,
                                         TimelineModel *timelineModel = nullptr);

signals:
    void defaultValueChanged();
    void patternChanged();

private:
    static QVariant normalizedValue(ValueType valueType, const QVariant &value);

    QVariant m_defaultValue;
    QString m_pattern;
    TimelineModel *m_timelineModel = nullptr;
};


Q_DECLARE_METATYPE(DeviceParamSpec *)
