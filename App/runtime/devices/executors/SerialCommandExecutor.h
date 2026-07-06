#pragma once

#include "devices/executors/DeviceCommandExecutor.h"

#include <QString>

class QSerialPort;

namespace TimelineControl {

class SerialCommandExecutor final : public DeviceCommandExecutor
{
    Q_OBJECT
public:
    explicit SerialCommandExecutor(const QString &portName, QObject *parent = nullptr);

protected:
    void executeImpl(DeviceCommand *command, const QVariantMap &params) override;
    bool checkOnlineImpl(const QVariantMap &params) override;

private:
    QString m_portName;
    QSerialPort *m_port = nullptr;
};

} // namespace TimelineControl
