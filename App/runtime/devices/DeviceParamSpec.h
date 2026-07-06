#pragma once

#include <QVariant>

#include "runtime/fields/BaseField.h"

namespace TimelineControl {

class DeviceParamSpec final : public EarthUI::BaseField
{
    Q_OBJECT

    //! 兼容旧 QML 展示用的字段类型名称。
    Q_PROPERTY(QString type READ typeName CONSTANT FINAL)

public:
    using ValueType = EarthUI::BaseField::ValueType;
    using EditorHint = EarthUI::BaseField::EditorHint;

    static constexpr ValueType InvalidType = EarthUI::BaseField::InvalidType;
    static constexpr ValueType BoolType = EarthUI::BaseField::BoolType;
    static constexpr ValueType IntType = EarthUI::BaseField::IntType;
    static constexpr ValueType DoubleType = EarthUI::BaseField::DoubleType;
    static constexpr ValueType StringType = EarthUI::BaseField::StringType;
    static constexpr ValueType SelectType = EarthUI::BaseField::EnumType;
    static constexpr ValueType ColorType = EarthUI::BaseField::ColorType;
    static constexpr ValueType VariantType = EarthUI::BaseField::VariantType;

    static constexpr EditorHint AutoEditor = EarthUI::BaseField::AutoEditor;
    static constexpr EditorHint TextEditor = EarthUI::BaseField::TextEditor;
    static constexpr EditorHint SliderEditor = EarthUI::BaseField::SliderEditor;
    static constexpr EditorHint ToggleEditor = EarthUI::BaseField::ToggleEditor;
    static constexpr EditorHint SelectEditor = EarthUI::BaseField::SelectEditor;
    static constexpr EditorHint ChoiceEditor = EarthUI::BaseField::ChoiceEditor;
    static constexpr EditorHint SegmentedEditor = EarthUI::BaseField::SegmentedEditor;
    static constexpr EditorHint ColorEditor = EarthUI::BaseField::ColorEditor;
    static constexpr EditorHint CustomEditor = EarthUI::BaseField::CustomEditor;

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

private:
    static QVariant normalizedValue(ValueType valueType, const QVariant &value);
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceParamSpec *)
