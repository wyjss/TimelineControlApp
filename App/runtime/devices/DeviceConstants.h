#pragma once

#include <QString>

namespace TimelineControl {


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
inline const QString Address = QStringLiteral("address");
inline const QString BaudRate = QStringLiteral("baudRate");
inline const QString Dmx512AdapterDeviceId = QStringLiteral("dmx512AdapterDeviceId");
inline const QString Ip = QStringLiteral("ip");
inline const QString Payload = QStringLiteral("payload");
inline const QString Port = QStringLiteral("port");
inline const QString Resolution = QStringLiteral("resolution");
inline const QString ScreenLayout = QStringLiteral("screenLayout");
inline const QString ScreenSize = QStringLiteral("screenSize");
inline const QString SerialPort = QStringLiteral("serialPort");
} // namespace DeviceKey

//! Device transport/protocol names.
namespace DeviceProtocol {
inline const QString Null = QStringLiteral("null");
inline const QString Dmx512 = QStringLiteral("DMX512");
inline const QString Http = QStringLiteral("HTTP");
inline const QString Serial = QStringLiteral("Serial");
inline const QString Osc = QStringLiteral("OSC");
inline const QString Pc = QStringLiteral("pc");
} // namespace DeviceProtocol

//! Common validation patterns.
namespace DevicePattern {
inline const QString Ip = QStringLiteral("^\\d{1,3}(?:\\.\\d{1,3}){3}$");
inline const QString HttpAddress = QStringLiteral("^(http://)?\\d{1,3}(?:\\.\\d{1,3}){3}(:\\d{1,5})?$");
} // namespace DevicePattern

} // namespace TimelineControl
