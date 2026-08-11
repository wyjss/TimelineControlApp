#pragma once

#include "devices/executors/DeviceCommandExecutor.h"

#include <QString>

class QNetworkAccessManager;


class SerialCommandExecutor final : public DeviceCommandExecutor
{
    Q_OBJECT
public:
    SerialCommandExecutor(const QString &ip, const QString &portName, QObject *parent = nullptr);

protected:
    void executeImpl(DeviceCommand *command, const QVariantMap &params) override;
    bool checkOnlineImpl(const QVariantMap &params) override;

private:
    QString m_ip;
    QString m_portName;
    QNetworkAccessManager *m_manager = nullptr;
};
