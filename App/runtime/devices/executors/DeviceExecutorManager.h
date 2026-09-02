#pragma once

#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QThread>
#include <QTimer>
#include <QVariantMap>


class Device;
class DeviceCommand;
class DeviceCommandExecutor;
class NetworkPing;

//! 实例由 TimelineRuntime 创建并管理。
class DeviceExecutorManager final : public QObject
{
    Q_OBJECT
public:
    explicit DeviceExecutorManager(QObject *parent = nullptr);
    ~DeviceExecutorManager() override;

    void bindDevice(Device *device);
    void unbindDevice(Device *device);
    void execute(const QString &executionId,
                 DeviceCommand *command,
                 const QVariantMap &executionInputValues = QVariantMap());

signals:
    void executionFinished(const QString &executionId,
                           DeviceCommand *command,
                           bool success,
                           const QString &errorMessage);
    void onlineChecked(const QString &deviceId, bool online);

private:
    struct OnlineCheck
    {
        QString ip;
        quint16 tcpPort = 0;
        QString executorKey;
    };

    void checkOnline();
    void requestOnlineCheck();
    void unbindDeviceId(const QString &deviceId);
    DeviceCommandExecutor *executorFor(const QString &protocol,
                                       const QVariantMap &params,
                                       QString *executorKey = nullptr);

    QThread m_thread;
    QThread m_onlineCheckThread;
    QTimer m_onlineCheckTimer;
    NetworkPing *m_networkPing = nullptr;
    QHash<QString, DeviceCommandExecutor *> m_executors;
    QHash<QString, OnlineCheck> m_onlineChecks;
    QHash<QString, QStringList> m_deviceIdsByExecutorKey;
    bool m_onlineCheckRequested = false;
};
