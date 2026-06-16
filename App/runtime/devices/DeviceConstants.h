#pragma once

#include <QString>

namespace TimelineControl {

//! Stable keys used by device config specs and command params.
namespace DeviceKey {
inline const QString Address = QStringLiteral("address");
inline const QString BaudRate = QStringLiteral("baudRate");
inline const QString Ip = QStringLiteral("ip");
inline const QString Payload = QStringLiteral("payload");
inline const QString Port = QStringLiteral("port");
inline const QString Resolution = QStringLiteral("resolution");
inline const QString ScreenLayout = QStringLiteral("screenLayout");
inline const QString ScreenSize = QStringLiteral("screenSize");
inline const QString SerialPort = QStringLiteral("serialPort");
} // namespace DeviceKey

//! Device template ids persisted by device instances.
namespace DeviceTemplateId {
	inline const QString Pc = QStringLiteral("pc");
	inline const QString Dmx512 = QStringLiteral("dmx512");
	inline const QString Display = QStringLiteral("display");
	inline const QString Lighting = QStringLiteral("lighting");
	inline const QString AudioMixer = QStringLiteral("audio-mixer");
	inline const QString PtzCamera = QStringLiteral("ptz-camera");
	inline const QString RelayController = QStringLiteral("relay-controller");
} // namespace DeviceTemplateId

//! Device transport/protocol names.
namespace DeviceProtocol {
inline const QString Null = QStringLiteral("null");
inline const QString Dmx = QStringLiteral("DMX");
inline const QString Http = QStringLiteral("HTTP");
inline const QString Modbus = QStringLiteral("Modbus");
inline const QString Osc = QStringLiteral("OSC");
inline const QString Pc = QStringLiteral("pc");
inline const QString Visca = QStringLiteral("VISCA");
} // namespace DeviceProtocol

//! Common validation patterns.
namespace DevicePattern {
inline const QString Ip = QStringLiteral("^\\d{1,3}(?:\\.\\d{1,3}){3}$");
} // namespace DevicePattern

} // namespace TimelineControl
