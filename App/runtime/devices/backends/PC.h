#pragma once
#include "devices/DeviceTemplate.h"

class PcDeviceTemplate : public DeviceTemplate
{
public:
	PcDeviceTemplate(QObject* parent);

	virtual Device* createDevice(QObject* parent, const QVariantMap& configValues) override;
};