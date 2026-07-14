#pragma once

#include <QJsonObject>
#include <QObject>
#include <QString>


class DeviceCommand;

namespace DeviceCommandFactory {
using Creator = DeviceCommand *(*)(QObject *);

void registerCommand(Creator creator);
DeviceCommand *create(const QString &protocol,
                      const QString &commandType,
                      QObject *parent = nullptr);
DeviceCommand *createForProtocol(const QString &protocol, QObject *parent = nullptr);
DeviceCommand *createFromJson(const QJsonObject &json, QObject *parent = nullptr);
}
