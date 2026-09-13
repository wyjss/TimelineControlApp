#include "devices/backends/Locator.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceModel.h"
#include "runtime/TimelineRuntime.h"

#include "LocatorViewer.h"

#include "LogMacros.h"

#include <QUdpSocket>
#include <QNetworkDatagram>
#include <QJsonDocument>
#include <QJsonObject>
#include <QThread>
#include <QTcpSocket>
#include <QDateTime>
#include <QTimer>
#include <QVector3D>
#include <QFile>
#include <QDir>
#include <QDateTime>

namespace {

QList<DeviceCommand *> createLocatorCommands(TimelineModel *timelineModel)
{
	auto *command = new DeviceCommand_Internal;
	command->setName(QStringLiteral("节目触发"));
	command->addExecutionInputField(
		DeviceParamSpec::createForKey(DeviceKey::Timeline, timelineModel));
	return {command};
}

} // namespace

LocatorDeviceTemplate::LocatorDeviceTemplate(TimelineModel *timelineModel,
	                                         QObject* parent)
	: DeviceTemplate("定位器", 
					 DeviceType::Locator, 
					 {DeviceProtocol::Internal},
					 "自动接收/更新动态gps数据",
					 {DeviceParamSpec::createForKey(DeviceKey::Location)},
					 createLocatorCommands(timelineModel),
					 parent)
{
	// 绑定
	connect(TimelineRuntime::getInstance()->deviceModel(),
			&DeviceModel::deviceAdded,
			this,
			[this](Device* device) {
				if (device->deviceType() == DeviceType::Locator) {
					bindLocator(device);

				}
			}
	);
}

Device* LocatorDeviceTemplate::createDevice(
	QObject* parent, const QVariantMap& configValues)
{
	auto device = DeviceTemplate::createDevice(parent, configValues);

	connect(LocationRecver::getInstance(),
			&LocationRecver::locationChanged,
			device,
			[device](QString address, double lon, double lat, double heading, bool online) {
				auto *ip = device->getParam(DeviceKey::Ip);
				if (ip && ip->value().toString() == address) {
					
					QVariantMap vm;
					vm["lon"] = lon;
					vm["lat"] = lat;
					vm["heading"] = heading;
					device->setParamValue(DeviceKey::Location,
										  vm);
					device->setOnline(online);

					LocatorViewer::getInstance()->updateTarget(
						device->name(),
						lon,
						lat,
						heading,
						online
					);
				}
			});

	
	return device;
}

void LocatorDeviceTemplate::bindLocator(Device* device)
{
	LocationRecver::getInstance()->addLocator(device, device->name(), device->getParam(DeviceKey::Ip)->value().toString());
	connect(device, &QObject::destroyed, [device]() {
		LocationRecver::getInstance()->removeLocator(device);
		if (LocatorViewer::getInstance()) {
			auto name = device->name();
			LocatorViewer::getInstance()->removeTarget(name);
		}
			});
}
//////////////////////////////////////////////////////////////////////////

LocationRecver::LocationRecver()
{

	QThread* thread = new QThread;
	this->moveToThread(thread);
	thread->start();

	QMetaObject::invokeMethod(this, [this]() {
		QTimer* timer = new QTimer;
		connect(timer, &QTimer::timeout, this, &LocationRecver::checkStatus);
		timer->start(500);
							  }, Qt::QueuedConnection);
}

LocationRecver* LocationRecver::getInstance()
{
	static LocationRecver* s_LocationRecver = new LocationRecver;
	return s_LocationRecver;
}


void LocationRecver::addLocator(QObject* handle, const QString& name, const QString& ip)
{
	if (QThread::currentThread() != this->thread()) {
		QMetaObject::invokeMethod(this, "addLocator", Qt::QueuedConnection,
								  Q_ARG(QObject*, handle),
								  Q_ARG(QString, name),
								  Q_ARG(QString, ip)
		);
		return;
	}

	QTcpSocket* sock = new QTcpSocket;
	connect(sock, &QTcpSocket::readyRead, this, &LocationRecver::readData);
	connect(sock, &QTcpSocket::stateChanged, this, [name, sock](QTcpSocket::SocketState state) {
		LOG_DEBUG("locator state changed " << name << state);
			});

	Data d;
	d.name = name;
	d.ip = ip;
	d.sock = sock;
	m_map[handle] = d;
}

void LocationRecver::removeLocator(QObject* handle)
{
	if (QThread::currentThread() != this->thread()) {
		QMetaObject::invokeMethod(this, "removeLocator", Qt::QueuedConnection,
								  Q_ARG(QObject*, handle)
		);
		return;
	}

	if (m_map.contains(handle)) {
		auto sock = m_map[handle].sock;
		disconnect(sock, 0, this, 0);
		sock->deleteLater();

		m_map.remove(handle);
	}
}

void LocationRecver::readData() 
{
	auto sock = dynamic_cast<QTcpSocket*>(sender());
	auto size = sock->bytesAvailable();
	QByteArray data;
	while (size) {
		data = sock->read(size);
		size = sock->bytesAvailable();
	}
	
	if (data.isEmpty()) {
		return;
	}
	//LOG_ERROR(data);
	auto i = data.lastIndexOf("$");
	if (i == -1) {
		return;
	}
	data = data.mid(i);

	auto handle = mapSock2Handle(sock);
	m_map[handle].online = true;
	m_map[handle].lastTouch = QDateTime::currentMSecsSinceEpoch();

	double lon, lat, heading;
	if (parseRmcPosition(data, lon, lat, heading)) {
		QVector3D dx((m_map[handle].lon - lon) * 1e7,
					 (m_map[handle].lat - lat) * 1e7, 
					 0);
// 		if (dx.length() < 10) {
// 			LOG_DEBUG("过滤");
// 			return;
// 		}
		m_map[handle].lon = lon;
		m_map[handle].lat = lat;
		m_map[handle].heading = heading;
		//LOG_DEBUG("recv location " << qSetRealNumberPrecision(10) << lon << lat);
		emit locationChanged(m_map[handle].ip, lon, lat, heading, true);
	}
}

void LocationRecver::checkStatus()
{

	for (auto itr = m_map.begin(); itr != m_map.end(); ++itr) {
		auto sock = itr->sock;
#if 0
		if (
			sock->state() != QTcpSocket::ConnectedState &&
			sock->state() != QTcpSocket::ConnectingState
			) {
			sock->connectToHost(QHostAddress(itr->ip), 1121);
			LOG_DEBUG("reconnect ti host " << itr->ip);
		}

		// 5s无数据判定离线
		if (QDateTime::currentMSecsSinceEpoch() - itr->lastTouch > 5000 && itr->lon != 0) {
			emit locationChanged(itr->ip, itr->lon, itr->lat, itr->heading, false);
		}
#else// debug

		static int s_i = 0;
		++s_i;
		if (s_i > 6) {
			return;
		}
		//bool online = rand() % 2 == 0;
		bool online = true;
		double lon = 109.022 + rand() % 1000 / 1000'000.0;
		double lat = 32.7056 + rand() % 1000 / 1000'000.0;
		double heading = rand() % 360;

		LOG_MARK_DEBUG_CODE("发送随机测试数据");
		emit locationChanged(itr->ip, lon, lat, heading, online);
		
#endif
	}



}
//////////////////////////////////////////////////////////////////////////


struct GnssPosition
{
	double latitude = 0.0;
	double longitude = 0.0;
	double heading = 0.0;   // 单位：度，0=北，90=东
	bool valid = false;
};

static double nmeaCoordinateToDegree(const QString& value)
{
	bool ok = false;
	const double v = value.toDouble(&ok);
	if (!ok)
		return 0.0;
	const int degree = static_cast<int>(v / 100.0);
	const double minute = v - degree * 100.0;

	return degree + minute / 60.0;
}

void* LocationRecver::mapSock2Handle(QTcpSocket* sock)
{
	for (auto itr = m_map.begin(); itr != m_map.end(); ++itr) {
		if (itr->sock == sock) {
			return itr.key();
		}
	}

	assert(false);
	return nullptr;
}

bool LocationRecver::parseRmcPosition(const QString& nmea, double& lon, double& lat, double& heading)
{
	LOG_DEBUG("parse:" << nmea);
	if (!nmea.startsWith('$'))
		return false;
	

	const QStringList fields = nmea.split(',');

	int iLon = -1, iLat = -1, iHeading = -1;
	bool vaild = false;
	if (fields[0].endsWith("RMC") == false) {
		return false;
		iLon = 1;
		iLat = 3;
	} else if (fields[0].endsWith("RMC")) {
		if (fields.size() < 9 || fields[2] != "A") {
			return false;
		}
		iLon = 5;
		iLat = 3;
		iHeading = 8;
	} else {
		LOG_ERROR("不支持的协议" << fields[0]);
		return false;
	}


	// RMC:
	// 0  $GNRMC
	// 1  UTC时间
	// 2  状态 A=有效 V=无效
	// 3  纬度 ddmm.mmmm
	// 4  N/S
	// 5  经度 dddmm.mmmm
	// 6  E/W
	// 7  地面速度 knots
	// 8  地面航向 degrees

// 	if (fields[2] != "A")
// 		return false;

	if (fields[iLon].isEmpty() || fields[iLat].isEmpty())
		return false;

	bool latOk = false;
	bool lonOk = false;

	fields[iLat].toDouble(&latOk);
	fields[iLon].toDouble(&lonOk);

	if (!latOk || !lonOk)
		return false;

	lon = nmeaCoordinateToDegree(fields[iLon]);
	lat = nmeaCoordinateToDegree(fields[iLat]);

	if (fields[iLat + 1] == "S")
		lat = -lat;

	if (fields[iLon + 1] == "W")
		lon = -lon;

	heading = 0;
	if (iHeading != -1) {
		bool ok;
		heading = fields[iHeading].toDouble(&ok);
		if (!ok) {
			heading = -1;
		}
	}
	
	if (!m_recordFile) {
		LOG_MARK_DEBUG_CODE("定位记录");
		QDir().mkpath("./temp_locationRecords");
		QString recordFilePath =
			QString("./temp_locationRecords/%1.txt").
			arg(QDateTime::currentDateTime().toString("yyyy-MM-dd-hh-mm-ss"));
		m_recordFile = new QFile(recordFilePath);
		m_recordFile->open(QIODevice::WriteOnly | QIODevice::Text);
	}


	{
		auto str = QString("%1,%2,%3").arg(QString::number(lon, 'g', 10))
			.arg(QString::number(lat, 'g', 10))
			.arg(QString::number(heading, 'g', 10)).toLatin1();
		m_recordFile->write(str);
		m_recordFile->write("\n");
		m_recordFile->flush();
	}
	
		return true;
}