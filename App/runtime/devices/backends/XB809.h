#pragma once

#include "devices/DeviceTemplate.h"

class XB809DeviceTemplate : public DeviceTemplate
{
public:
    explicit XB809DeviceTemplate(QObject *parent = nullptr);
    Device* createDevice(QObject* parent, const QVariantMap& configValues) override;
};
