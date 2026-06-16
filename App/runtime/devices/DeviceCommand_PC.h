#pragma once

#include "devices/DeviceCommand_Http.h"

namespace TimelineControl {

//! PC 设备指令。封装快捷可视指令，内部复用 HTTP 执行语义。
class DeviceCommand_PC : public DeviceCommand_Http
{
    Q_OBJECT

public:
    explicit DeviceCommand_PC(QObject *parent = nullptr);
    DeviceCommand_PC(const QString &name,
                     const QString &path,
                     QObject *parent = nullptr);

    QString protocol() const override;

    static QString protocolName();

protected:
    QJsonObject paramsToJson() const override;
    bool loadParamsFromJson(const QJsonObject &params) override;
    QString validateParams() const override;
    QList<DeviceParamSpec *> createCreationInputFields(QObject *parent) const override;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommand_PC *)
