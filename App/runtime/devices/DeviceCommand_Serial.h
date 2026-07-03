#pragma once

#include "devices/DeviceCommand.h"

namespace TimelineControl {

//! 串口协议指令，提供载荷内容和十六进制解释开关。
class DeviceCommand_Serial : public DeviceCommand
{
    Q_OBJECT

    Q_PROPERTY(QString serialPort READ serialPort WRITE setSerialPort NOTIFY serialPortChanged FINAL)
    Q_PROPERTY(QString payload READ payload WRITE setPayload NOTIFY payloadChanged FINAL)

public:
    explicit DeviceCommand_Serial(QObject *parent = nullptr);
    DeviceCommand_Serial(const QString &name,
                         const QString &payload,
                         QObject *parent = nullptr);

    Q_INVOKABLE DeviceParamSpec *serialPortField() const { return getField(DeviceKey::SerialPort); }
    Q_INVOKABLE DeviceParamSpec *payloadField() const { return getField(DeviceKey::Payload); }

    QString serialPort() const;
    void setSerialPort(const QString& serialPort);

    QString payload() const;
    void setPayload(const QString &payload);

    QString protocol() const override;
    void execute() override;

    static QString protocolName();

signals:
    void serialPortChanged();
    void payloadChanged();
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand_Serial *)

