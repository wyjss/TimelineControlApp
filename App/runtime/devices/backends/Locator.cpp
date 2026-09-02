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

	quint16 port = 11578;
	QUdpSocket* sock = new QUdpSocket(this);
	bool ok = sock->bind(
		QHostAddress::AnyIPv4,
		port,
		QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint
	);
	if (!ok) {
		LOG_FATAL("绑定定位器共享地址失败，端口" << port);
	}

	connect(sock, &QUdpSocket::readyRead,
			this, [this, sock]() {
				while (sock->hasPendingDatagrams()) {
					QByteArray data = sock->receiveDatagram().data();

					auto doc = QJsonDocument::fromJson(data);
					if (doc.isObject()) {
						auto o = doc.object();
						auto address = o["address"].toString();
						double lon = o["lon"].toDouble();
						double lat = o["lat"].toDouble();
						double heading = o["heading"].toDouble();

						LOG_DEBUG("recv location " << address << lon << lat);
						emit this->locationChanged(address, lon, lat, heading, true);
					}
				}
			});
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

	auto handle = mapSock2Handle(sock);
	m_map[handle].online = true;
	m_map[handle].lastTouch = QDateTime::currentMSecsSinceEpoch();

	LOG_DEBUG("解析nmea协议" << data);

	double lon, lat, heading;
	if (parseRmcPosition(data, lon, lat, heading)) {
		m_map[handle].lon = lon;
		m_map[handle].lat = lat;
		m_map[handle].heading = heading;
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
			sock->connectToHost(QHostAddress(itr->ip), 12333);
		}

		// 5s无数据判定离线
		if (QDateTime::currentMSecsSinceEpoch() - itr->lastTouch > 5000) {
			emit locationChanged(itr->ip, itr->lon, itr->lat, itr->heading, false);
		}
#else// debug
		//bool online = rand() % 2 == 0;
		bool online = true;
		double lon = 109.0 + rand() % 1000 / 1000'000.0;
		double lat = 32.7 + rand() % 1000 / 1000'000.0;
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
	if (!nmea.startsWith('$'))
		return false;

	const QStringList fields = nmea.split(',');

	// RMC至少需要到heading字段
	if (fields.size() < 9)
		return false;

	// 兼容 $GPRMC / $GNRMC / $BDRMC 等
	if (!fields[0].endsWith("RMC"))
		return false;

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

	if (fields[2] != "A")
		return false;

	if (fields[3].isEmpty() || fields[5].isEmpty())
		return false;

	bool latOk = false;
	bool lonOk = false;

	fields[3].toDouble(&latOk);
	fields[5].toDouble(&lonOk);

	if (!latOk || !lonOk)
		return false;

	lat = nmeaCoordinateToDegree(fields[3]);
	lon = nmeaCoordinateToDegree(fields[5]);

	if (fields[4] == "S")
		lat = -lat;

	if (fields[6] == "W")
		lon = -lon;

	bool headingOk = false;
	heading = fields[8].toDouble(&headingOk);
	if (headingOk == false) {
		heading = 0;
	}

	return true;
}