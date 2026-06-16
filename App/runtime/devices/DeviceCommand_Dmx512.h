#pragma once

#include "devices/DeviceCommand.h"

namespace TimelineControl {

//! DMX512 协议指令，提供通道和值参数。
class DeviceCommand_Dmx512 : public DeviceCommand
{
    Q_OBJECT

    Q_PROPERTY(int channel READ channel WRITE setChannel NOTIFY channelChanged FINAL)
    Q_PROPERTY(int value READ value WRITE setValue NOTIFY valueChanged FINAL)

public:
    explicit DeviceCommand_Dmx512(QObject *parent = nullptr);
    DeviceCommand_Dmx512(const QString &name,
                         int channel,
                         int value,
                         QObject *parent = nullptr);

    int channel() const;
    void setChannel(int channel);

    int value() const;
    void setValue(int value);

    QString protocol() const override;

    static QString protocolName();

signals:
    void channelChanged();
    void valueChanged();

protected:
    QJsonObject paramsToJson() const override;
    bool loadParamsFromJson(const QJsonObject &params) override;
    QString validateParams() const override;
    QList<DeviceParamSpec *> createCreationInputFields(QObject *parent) const override;

private:
    int m_channel = 1;
    int m_value = 255;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand_Dmx512 *)

