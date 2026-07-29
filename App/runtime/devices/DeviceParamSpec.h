#pragma once

#include <QVariant>

#include <UICore/Fields/BaseField.h>


class DeviceParamSpec final : public UICore::BaseField
{
    Q_OBJECT

    //! 兼容旧 QML 展示用的字段类型名称。
    Q_PROPERTY(QString type READ typeName CONSTANT FINAL)

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

    QString typeName() const;
    DeviceParamSpec *clone(QObject *parent = nullptr) const;
    Q_INVOKABLE QString invalidReason(const QVariant &value = QVariant()) const;

    static QString typeName(ValueType valueType);
    static DeviceParamSpec *createForKey(const QString &deviceKey);

private:
    static QVariant normalizedValue(ValueType valueType, const QVariant &value);
};


Q_DECLARE_METATYPE(DeviceParamSpec *)
