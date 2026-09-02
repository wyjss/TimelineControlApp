#pragma once

#include "devices/executors/DeviceCommandExecutor.h"

#include <QString>


class DmxCommandExecutor final : public DeviceCommandExecutor
{
    Q_OBJECT
public:
    DmxCommandExecutor(const QString &ip, int port, QObject *parent = nullptr);

protected:
    void executeImpl(const QString &executionId,
                     DeviceCommand *command,
                     const QVariantMap &params) override;

private:
    QString m_ip;
    int m_port = 80;
};
