#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QTimer>
#include <QVariantMap>

namespace TimelineControl {

class Device;
class DeviceCommand;
class DeviceCommandExecutor;

class DeviceExecutorManager final : public QObject
{
    Q_OBJECT
public:
    explicit DeviceExecutorManager(QObject *parent = nullptr);
    ~DeviceExecutorManager() override;

    void bindDevice(Device *device);
    void unbindDevice(Device *device);
    void execute(Device *device, DeviceCommand *command);

signals:
    void executionFinished(TimelineControl::DeviceCommand *command,
                           bool success,
                           const QString &errorMessage);
    void onlineChecked(const QString &deviceId, bool online);

private:
    struct OnlineCheck
    {
        QString protocol;
        QVariantMap params;
        QString executorKey;
    };

    void checkOnline();
    void requestOnlineCheck();
    void unbindDeviceId(const QString &deviceId);
    DeviceCommandExecutor *executorFor(const QString &protocol,
                                       const QVariantMap &params,
                                       QString *executorKey = nullptr,
                                       bool *created = nullptr);

    QThread m_thread;
    QTimer m_onlineCheckTimer;
    QHash<QString, DeviceCommandExecutor *> m_executors;
    QHash<QString, OnlineCheck> m_onlineChecks;
    QHash<QString, QStringList> m_deviceIdsByExecutorKey;
    bool m_onlineCheckRequested = false;
};

} // namespace TimelineControl
