#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantMap>

namespace TimelineControl {

class DeviceParamSpec
{
    Q_GADGET

    Q_PROPERTY(QString key MEMBER key CONSTANT)
    Q_PROPERTY(QString label MEMBER label CONSTANT)
    Q_PROPERTY(QString type MEMBER type CONSTANT)
    Q_PROPERTY(QVariant defaultValue MEMBER defaultValue CONSTANT)
    Q_PROPERTY(bool required MEMBER required CONSTANT)
    Q_PROPERTY(QVariantMap constraints MEMBER constraints CONSTANT)

public:
    DeviceParamSpec() = default;
    DeviceParamSpec(const QString &key,
                    const QString &label,
                    const QString &type,
                    const QVariant &defaultValue,
                    bool required = false,
                    const QVariantMap &constraints = QVariantMap())
        : key(key)
        , label(label)
        , type(type)
        , defaultValue(defaultValue)
        , required(required)
        , constraints(constraints)
    {
    }

    QString key;
    QString label;
    QString type;
    QVariant defaultValue;
    bool required = false;
    QVariantMap constraints;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceParamSpec)
