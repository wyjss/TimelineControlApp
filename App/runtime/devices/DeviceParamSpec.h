#pragma once

#include <QVariant>
#include <QVariantMap>

#include "runtime/fields/BaseField.h"

namespace TimelineControl {
    static const QString Key_Ip = "ip";
    static const QString Key_BaudRate = "比特率";
    static const QString Key_Payload = "载荷";
class DeviceParamSpec final : public EarthUI::BaseField
{
    Q_OBJECT

    //! 兼容旧 QML 展示用的字段类型名称。
    Q_PROPERTY(QString type READ typeName CONSTANT FINAL)

public:
    using ValueType = EarthUI::BaseField::ValueType;

    static constexpr ValueType InvalidType = EarthUI::BaseField::InvalidType;
    static constexpr ValueType BoolType = EarthUI::BaseField::BoolType;
    static constexpr ValueType IntType = EarthUI::BaseField::IntType;
    static constexpr ValueType DoubleType = EarthUI::BaseField::DoubleType;
    static constexpr ValueType StringType = EarthUI::BaseField::StringType;
    static constexpr ValueType SelectType = EarthUI::BaseField::EnumType;
    static constexpr ValueType ColorType = EarthUI::BaseField::ColorType;
    static constexpr ValueType SizeType = EarthUI::BaseField::SizeType;
    static constexpr ValueType VariantType = EarthUI::BaseField::VariantType;

    explicit DeviceParamSpec(QObject *parent = nullptr);
    DeviceParamSpec(const QString &key,
                    const QString &label,
                    ValueType valueType,
                    const QVariant &defaultValue,
                    bool required = false,
                    const QVariantMap &constraints = QVariantMap(),
                    QObject *parent = nullptr);

    QString typeName() const;
    DeviceParamSpec *clone(QObject *parent = nullptr) const;

    static QString typeName(ValueType valueType);

private:
    void applyConstraints(const QVariantMap &constraints);
    static QVariant normalizedDefaultValue(ValueType valueType, const QVariant &value);
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceParamSpec *)
