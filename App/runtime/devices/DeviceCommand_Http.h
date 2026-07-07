#pragma once

#include "devices/DeviceCommand.h"

namespace TimelineControl {

//! HTTP 协议指令，提供请求方法、路径、请求体等强类型参数。
class DeviceCommand_Http : public DeviceCommand
{
    Q_OBJECT
public:
    explicit DeviceCommand_Http(QObject *parent = nullptr);

	DeviceParamSpec* ipField() const { return getField(DeviceKey::Ip); }
	DeviceParamSpec* portField() const { return getField(DeviceKey::IpPort); }
	DeviceParamSpec* methodField() const { return getField(DeviceKey::HttpMethod); }
	DeviceParamSpec* pathField() const { return getField(DeviceKey::ApiPath); }
	DeviceParamSpec* bodyField() const { return getField(DeviceKey::HttpBody); }

    QString protocol() const override;

    static QString protocolName();
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand_Http *)

