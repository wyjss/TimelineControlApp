#pragma once

#include "devices/Device.h"
#include "devices/DeviceTemplate.h"

class TimelineModel;

class LocatorDeviceTemplate : public DeviceTemplate
{
public:
	LocatorDeviceTemplate(TimelineModel *timelineModel, QObject* parent);
	Device* createDevice(QObject* parent,
	                     const QVariantMap& configValues) override;
};

class LocationRecver : public QObject
{
	Q_OBJECT
private:
	friend class LocatorDeviceTemplate;

	LocationRecver();
	static LocationRecver* getInstance();

signals:
	void locationChanged(QString, double, double);
};
