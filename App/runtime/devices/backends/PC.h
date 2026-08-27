#pragma once
#include "devices/DeviceTemplate.h"

class PcDeviceTemplate : public DeviceTemplate
{
public:
	PcDeviceTemplate(QObject* parent);

	Device* createDevice(QObject* parent, const QVariantMap& configValues) override;
	DeviceCommand *createCommand(const QString &commandType,
	                             QObject *parent = nullptr) const override;
};
