#pragma once

#include "devices/DeviceTemplate.h"

// 光峰T系列投影机
// 文档：光峰工程机控制代码 (20260525).xlsx （G、T系列）
class GFTDeviceTemplate : public DeviceTemplate
{
public:
    explicit GFTDeviceTemplate(QObject *parent = nullptr);
    Device* createDevice(QObject* parent, const QVariantMap& configValues) override;
};
