#include "devices/backends/Locator.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "LogMacros.h"

#include <QUdpSocket>
#include <QNetworkDatagram>
#include <QJsonDocument>
#include <QJsonObject>

static const QString LocatorTemplateName = "LocatorTemplate";
static const QString LocatorLocationKey = "LocatorLocation";

LocatorDeviceTemplate::LocatorDeviceTemplate(QObject* parent)
	: DeviceTemplate("定位器", 
					 DeviceType::Locator, 
					 {DeviceProtocol::Internal},
					 "自动接收/更新动态gps数据",
					 {DeviceParamSpec::createForKey(DeviceKey::Location)},
					 {},
					 parent)
{

}

Device* LocatorDeviceTemplate::createDevice(
	QObject* parent, const QVariantMap& configValues)
{
	auto device = DeviceTemplate::createDevice(parent, configValues);
	device->addParam(DeviceParamSpec::createForKey(DeviceType::Locator));
	connect(LocationRecver::getInstance(),
			&LocationRecver::locationChanged,
			device,
			[device](QString address, double lon, double lat) {
				if (device->getParam(DeviceKey::Ip)->value().toString() == address) {
					QVariantMap vm;
					vm["lon"] = lon;
					vm["lat"] = lat;
					device->setParamValue(DeviceKey::Location,
										  vm);
				}
			});
	return device;
}

//////////////////////////////////////////////////////////////////////////

LocationRecver::LocationRecver()
{
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

						LOG_DEBUG("recv location " << address << lon << lat);
						emit this->locationChanged(address, lon, lat);
					}
				}
			});
}

LocationRecver* LocationRecver::getInstance()
{
	static LocationRecver* s_LocationRecver = new LocationRecver;
	return s_LocationRecver;
}