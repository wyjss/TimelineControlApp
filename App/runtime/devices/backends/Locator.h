#pragma once

#include "devices/Device.h"
#include "devices/DeviceTemplate.h"

class QTcpSocket;
class QFile;

class TimelineModel;

class LocatorDeviceTemplate : public DeviceTemplate
{
public:
	LocatorDeviceTemplate(TimelineModel *timelineModel, QObject* parent);
	Device* createDevice(QObject* parent,
	                     const QVariantMap& configValues) override;
private:
	void bindLocator(Device*);
};

class LocationRecver : public QObject
{
	Q_OBJECT
private:
	friend class LocatorDeviceTemplate;

	LocationRecver();
	static LocationRecver* getInstance();

public slots:
	void addLocator(QObject* handle, const QString& name, const QString& ip);
	void removeLocator(QObject* handle);
private slots:
	void readData();
	void checkStatus();
private:
	void* mapSock2Handle(QTcpSocket* sock);
	bool parseRmcPosition(const QString& nmea, double&lon, double& lat, double& heading);
signals:
	void locationChanged(QString name, double lon, double lat, double heading, bool online);
private:
	struct Data {
		QString name;
		QString ip;
		bool online = false;
		qint64 lastTouch = 0;

		double lon = 0;
		double lat = 0;
		double heading = 0;

		QTcpSocket* sock = nullptr;
	};
	QMap<void*, Data> m_map;

	QFile* m_recordFile = nullptr;
	
};
