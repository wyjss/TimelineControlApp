#pragma once

#include "devices/DeviceCommand_Http.h"

namespace TimelineControl {

//! PC 设备指令。封装快捷可视指令，内部复用 HTTP 执行语义。
class DeviceCommand_PC : public DeviceCommand_Http
{
    Q_OBJECT

public:
    explicit DeviceCommand_PC(QObject *parent = nullptr);

    QString protocol() const override;

    static QString protocolName();
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand_PC *)
