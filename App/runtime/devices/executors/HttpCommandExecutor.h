#pragma once

#include "devices/executors/DeviceCommandExecutor.h"

#include <QString>

class QNetworkAccessManager;


class HttpCommandExecutor final : public DeviceCommandExecutor
{
    Q_OBJECT
public:
    HttpCommandExecutor(const QString &ip, int port, QObject *parent = nullptr);

protected:
    void executeImpl(DeviceCommand *command, const QVariantMap &params) override;
    bool checkOnlineImpl(const QVariantMap &params) override;

private:
    QString m_ip;
    int m_port = 80;
    QNetworkAccessManager *m_manager = nullptr;
};
