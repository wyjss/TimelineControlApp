#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>

namespace TimelineControl {

class DeviceCommand;

namespace DeviceCommandFactory {
DeviceCommand *createForProtocol(const QString &protocol, QObject *parent = nullptr);
DeviceCommand *createFromJson(const QJsonObject &json, QObject *parent = nullptr);
}

} // namespace TimelineControl
