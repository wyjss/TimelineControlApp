#pragma once

#include "devices/DeviceTemplate.h"

// LMI水幕设备模板
// 文档：LMI水秀软件远程控制命令20211211.xlsx
class LMIDeviceTemplate : public DeviceTemplate
{
public:
    explicit LMIDeviceTemplate(QObject *parent = nullptr);
    Device* createDevice(QObject* parent, const QVariantMap& configValues) override;
};
