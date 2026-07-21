#pragma once

#include <QString>
#include <QVariant>
#include <QVector>
#include <QVector2D>



	//! 通用的设备类型
	namespace DeviceType {
		inline const QString PC = "电脑";
		inline const QString Dmx512Adapter = "Dmx512适配器";
		inline const QString Projector = "投影机";
		inline const QString Light = "灯光";
		inline const QString Sound = "音响";
	};
//! Stable keys used by device config specs and command params.
namespace DeviceKey {
inline const QString Name = QStringLiteral("name");
inline const QString CommandType = QStringLiteral("commandType");
inline const QString Protocol = QStringLiteral("protocol");
inline const QString BaudRate = QStringLiteral("baudRate");
inline const QString Dmx512AdapterDeviceId = QStringLiteral("dmx512AdapterDeviceId");
inline const QString Ip = QStringLiteral("ip");
inline const QString HttpMethod = QStringLiteral("httpMethod");
//inline const QString HttpQueryParams = QStringLiteral("httpQueryParams");
inline const QString HttpBody = QStringLiteral("httpBody");
inline const QString ApiPath = QStringLiteral("apiPath");
inline const QString OscTransProtocol = QStringLiteral("oscTransProtocol");
inline const QString OscMessage = QStringLiteral("oscMessage");
inline const QString KeystoneCorrection = QStringLiteral("keystoneCorrection");
inline const QString SerialPayload = QStringLiteral("serialPayload");
inline const QString Port = QStringLiteral("port");
inline const QString VirtualScreenWidth = QStringLiteral("virtualScreenWidth");
inline const QString VirtualScreenHeight = QStringLiteral("virtualScreenHeight");
inline const QString ScreenColumns = QStringLiteral("screenColumns");
inline const QString ScreenHeight = QStringLiteral("screenHeight");
inline const QString ScreenRows = QStringLiteral("screenRows");
inline const QString ScreenWidth = QStringLiteral("screenWidth");
inline const QString SerialPort = QStringLiteral("serialPort");
inline const QString Videos = QStringLiteral("videos");
inline const QString VideoFile = QStringLiteral("videoFile");
inline const QString Rect = QStringLiteral("rect");

// 特殊指令
inline const QString PowerOn = QStringLiteral("powerOn");
inline const QString PowerOff = QStringLiteral("powerOff");
inline const QString Pause = QStringLiteral("pause");
} // namespace DeviceKey

namespace DeviceConstants {
	inline const QString LocalVideoPrefix = "D:/video/";
}

//! Device transport/protocol names.
namespace DeviceProtocol {
inline const QString Null = QStringLiteral("null");
inline const QString Dmx512 = QStringLiteral("dmx512");
inline const QString Http = QStringLiteral("http");
inline const QString Serial = QStringLiteral("serial");
inline const QString Osc = QStringLiteral("osc");
inline const QString Pc = QStringLiteral("pc");
} // namespace DeviceProtocol

//! Common validation patterns.
namespace DevicePattern {
inline const QString Ip = QStringLiteral("^\\d{1,3}(?:\\.\\d{1,3}){3}$");
inline const QString Rect = QStringLiteral("^\\d+(,\\d+){3}$");
} // namespace DevicePattern

struct DeviceKeystoneCorrectionItem {
	// 屏幕 layout 的索引，从左到右、从上到下。
	// -1 表示整个 PC 总画布。
	// >= 0 表示某一块屏幕
	int screenIndex = -1;
	QVector2D topLeft;
	QVector2D topRight;
	QVector2D bottomRight;
	QVector2D bottomLeft;
};

namespace DeviceKeystoneCorrectionCodec {

inline QVariantMap pointToVariantMap(const QVector2D &point)
{
	return QVariantMap{
		{QStringLiteral("x"), point.x()},
		{QStringLiteral("y"), point.y()}
	};
}

inline QVector2D pointFromVariantMap(const QVariantMap &map, const QVector2D &defaultValue = QVector2D())
{
	return QVector2D(map.value(QStringLiteral("x"), defaultValue.x()).toFloat(),
	                 map.value(QStringLiteral("y"), defaultValue.y()).toFloat());
}

inline QVariantMap toVariantMap(const DeviceKeystoneCorrectionItem &item)
{
	return QVariantMap{
		{QStringLiteral("screenIndex"), item.screenIndex},
		{QStringLiteral("topLeft"), pointToVariantMap(item.topLeft)},
		{QStringLiteral("topRight"), pointToVariantMap(item.topRight)},
		{QStringLiteral("bottomRight"), pointToVariantMap(item.bottomRight)},
		{QStringLiteral("bottomLeft"), pointToVariantMap(item.bottomLeft)}
	};
}

inline DeviceKeystoneCorrectionItem fromVariantMap(const QVariantMap &map)
{
	DeviceKeystoneCorrectionItem item;
	item.screenIndex = map.value(QStringLiteral("screenIndex"), item.screenIndex).toInt();
	item.topLeft = pointFromVariantMap(map.value(QStringLiteral("topLeft")).toMap(), item.topLeft);
	item.topRight = pointFromVariantMap(map.value(QStringLiteral("topRight")).toMap(), item.topRight);
	item.bottomRight = pointFromVariantMap(map.value(QStringLiteral("bottomRight")).toMap(), item.bottomRight);
	item.bottomLeft = pointFromVariantMap(map.value(QStringLiteral("bottomLeft")).toMap(), item.bottomLeft);
	return item;
}

inline QVariant toVariant(const DeviceKeystoneCorrectionItem &item)
{
	return toVariantMap(item);
}

inline DeviceKeystoneCorrectionItem fromVariant(const QVariant &value)
{
	return fromVariantMap(value.toMap());
}

inline QVariantList toVariantList(const QVector<DeviceKeystoneCorrectionItem> &items)
{
	QVariantList values;
	values.reserve(items.size());
	for (const DeviceKeystoneCorrectionItem &item : items)
		values.append(toVariantMap(item));
	return values;
}

inline QVector<DeviceKeystoneCorrectionItem> fromVariantList(const QVariantList &values)
{
	QVector<DeviceKeystoneCorrectionItem> items;
	items.reserve(values.size());
	for (const QVariant &value : values)
		items.append(fromVariantMap(value.toMap()));
	return items;
}

inline QVariant toVariant(const QVector<DeviceKeystoneCorrectionItem> &items)
{
	return toVariantList(items);
}

inline QVector<DeviceKeystoneCorrectionItem> listFromVariant(const QVariant &value)
{
	return fromVariantList(value.toList());
}

} // namespace DeviceKeystoneCorrectionCodec
