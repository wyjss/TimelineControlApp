#pragma once

#include "devices/Device.h"
#include "devices/DeviceTemplate.h"

class LocatorDeviceTemplate : public DeviceTemplate
{
public:
	virtual Device* createDevice(QObject* parent, const QVariantMap& configValues) override;
};