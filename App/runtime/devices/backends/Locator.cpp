#include "devices/backends/Locator.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "LogMacros.h"

#include <QUdpSocket>
#include <QNetworkDatagram>
#include <QJsonDocument>
#include <QJsonObject>

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

}

Device* LocatorDeviceTemplate::createDevice(
	QObject* parent, const QVariantMap& configValues)
{
	auto device = DeviceTemplate::createDevice(parent, configValues);
	connect(LocationRecver::getInstance(),
			&LocationRecver::locationChanged,
			device,
			[device](QString address, double lon, double lat) {
				auto *ip = device->getParam(DeviceKey::Ip);
				if (ip && ip->value().toString() == address) {
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

//////////////////////////////////////////////////////////////////////////


#include <cmath>
#include <algorithm>

struct Vec2
{
	double x = 0.0;
	double y = 0.0;

	Vec2 operator+(const Vec2& v) const {
		return {x + v.x, y + v.y};
	}

	Vec2 operator-(const Vec2& v) const {
		return {x - v.x, y - v.y};
	}

	Vec2 operator*(double s) const {
		return {x * s, y * s};
	}
};

inline double dot(const Vec2& a, const Vec2& b)
{
	return a.x * b.x + a.y * b.y;
}

inline double cross(const Vec2& a, const Vec2& b)
{
	return a.x * b.y - a.y * b.x;
}

inline double length(const Vec2& v)
{
	return std::sqrt(dot(v, v));
}

struct LineResult
{
	// 两条有限线段是否相交
	bool segmentIntersect = false;

	// 两条无限直线是否存在唯一交点
	bool hasLineIntersection = false;

	// 无限直线交点
	Vec2 intersection;

	// 从 AB 转到 CD 的有向角 [-180, 180]
	double angleDegree = 0.0;

	// P = A + t * (B-A)
	double t = 0.0;

	// P = C + u * (D-C)
	double u = 0.0;

	// 从 C 沿 C->D 方向到无限直线交点的有符号距离
	double signedDistance = 0.0;

	// 普通距离
	double distance = 0.0;
};

LineResult calculate(
	const Vec2& A,
	const Vec2& B,
	const Vec2& C,
	const Vec2& D)
{
	constexpr double EPS = 1e-10;
	constexpr double PI = 3.14159265358979323846;

	LineResult result;

	const Vec2 r = B - A;
	const Vec2 s = D - C;

	const double rLength = length(r);
	const double sLength = length(s);

	// 无效线段
	if (rLength < EPS || sLength < EPS)
		return result;

	// -----------------------------
	// 1. 有向夹角 AB -> CD
	// -----------------------------
	result.angleDegree =
		std::atan2(cross(r, s), dot(r, s))
		* 180.0 / PI;

	// -----------------------------
	// 2. 无限直线交点
	// -----------------------------
	const double denominator = cross(r, s);

	// 平行
	if (std::abs(denominator) < EPS)
	{
		return result;
	}

	const Vec2 CA = C - A;

	result.t = cross(CA, s) / denominator;
	result.u = cross(CA, r) / denominator;

	result.hasLineIntersection = true;

	result.intersection =
		A + r * result.t;

	// -----------------------------
	// 3. 有限线段是否相交
	// -----------------------------
	result.segmentIntersect =
		result.t >= -EPS &&
		result.t <= 1.0 + EPS &&
		result.u >= -EPS &&
		result.u <= 1.0 + EPS;

	// -----------------------------
	// 4. C -> 交点的距离
	// -----------------------------
	result.signedDistance =
		result.u * sLength;

	result.distance =
		std::abs(result.signedDistance);

	return result;
}