#pragma once

#include "devices/DeviceCommand.h"

namespace TimelineControl {

//! 串口协议指令，提供载荷内容和十六进制解释开关。
class DeviceCommand_Serial : public DeviceCommand
{
    Q_OBJECT

    Q_PROPERTY(bool hex READ isHex WRITE setHex NOTIFY hexChanged FINAL)
    Q_PROPERTY(QString payload READ payload WRITE setPayload NOTIFY payloadChanged FINAL)

public:
    explicit DeviceCommand_Serial(QObject *parent = nullptr);
    DeviceCommand_Serial(const QString &name,
                         const QString &payload,
                         bool hex = true,
                         QObject *parent = nullptr);

    bool isHex() const;
    void setHex(bool hex);

    QString payload() const;
    void setPayload(const QString &payload);

    QString protocol() const override;

    static QString protocolName();

signals:
    void hexChanged();
    void payloadChanged();

protected:
    QJsonObject paramsToJson() const override;
    bool loadParamsFromJson(const QJsonObject &params) override;
    QString validateParams() const override;
    QList<DeviceParamSpec *> createCreationInputFields(QObject *parent) const override;

private:
    bool m_hex = true;
    QString m_payload;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand_Serial *)

