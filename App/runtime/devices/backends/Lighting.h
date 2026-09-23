#pragma once

#include "devices/DeviceTemplate.h"

// 灯控（控台）设备模板
// 文档：安康中控触发灯光代码.txt
class LightingDeviceTemplate : public DeviceTemplate
{
public:
    explicit LightingDeviceTemplate(QObject *parent = nullptr);
    Device* createDevice(QObject* parent, const QVariantMap& configValues) override;
};
