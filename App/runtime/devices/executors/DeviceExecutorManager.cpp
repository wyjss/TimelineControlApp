#include "devices/executors/DeviceExecutorManager.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "devices/executors/DeviceCommandExecutor.h"
#include "devices/executors/HttpCommandExecutor.h"
#include "devices/executors/NetworkPing.h"
#include "devices/executors/SerialCommandExecutor.h"
#include "devices/executors/UdpCommandExecutor.h"
#include "devices/executors/DmxCommandExecutor.h"

#include "LogMacros.h"
#include <QMetaObject>

namespace {

constexpr quint16 kPcOnlinePort = 11357;

}


DeviceExecutorManager::DeviceExecutorManager(QObject *parent)
    : QObject(parent)
    , m_networkPing(new NetworkPing)
{
    m_networkPing->moveToThread(&m_onlineCheckThread);
    connect(m_networkPing, &NetworkPing::onlineChecked,
            this, &DeviceExecutorManager::onlineChecked);
    connect(&m_onlineCheckThread, &QThread::finished,
            m_networkPing, &QObject::deleteLater);
    m_onlineCheckTimer.setInterval(15000);
    connect(&m_onlineCheckTimer, &QTimer::timeout, this, &DeviceExecutorManager::checkOnline);
    m_onlineCheckTimer.start();
    m_onlineCheckThread.start();
    m_thread.start();
}

DeviceExecutorManager::~DeviceExecutorManager()
{
    m_onlineCheckThread.quit();
    // 不wait，卡太久了
    //m_onlineCheckThread.wait();
    m_thread.quit();
    m_thread.wait();
}

void DeviceExecutorManager::bindDevice(Device *device)
{
    if (!device)
        return;

    unbindDevice(device);
    disconnect(this, &DeviceExecutorManager::onlineChecked, device, nullptr);
    disconnect(device, &QObject::destroyed, this, nullptr);

    QString executorKey;
    for (const QString &protocol : device->supportedProtocols()) {
        const QString protocolValue = protocol.trimmed();
        if (protocolValue != DeviceProtocol::Http
            && protocolValue != DeviceProtocol::Dmx512
            && protocolValue != DeviceProtocol::Udp
            && protocolValue != DeviceProtocol::Serial
            && protocolValue != DeviceProtocol::Pc)
            continue;

        DeviceCommand *command = device->createCommandDraft(protocolValue);
        const QVariantMap params = command ? command->resolvedParams() : device->configValues();
        delete command;

        if (executorFor(protocolValue, params, &executorKey))
            break;
    }

    const QString deviceId = device->id();
    const QString ip = device->configValues().value(DeviceKey::Ip).toString().trimmed();
    const quint16 tcpPort = device->supportsProtocol(DeviceProtocol::Pc)
        ? kPcOnlinePort
        : 0;
    m_onlineChecks.insert(deviceId, OnlineCheck{ip, tcpPort, executorKey});

    if (!executorKey.isEmpty()) {
        QStringList deviceIds = m_deviceIdsByExecutorKey.value(executorKey);
        if (!deviceIds.contains(deviceId)) {
            deviceIds.append(deviceId);
            m_deviceIdsByExecutorKey.insert(executorKey, deviceIds);
        }
    }

    connect(this, &DeviceExecutorManager::onlineChecked, device, [this, device, deviceId](const QString &checkedDeviceId, bool online) {
        // 定位器单独通过接收定位数据时间判断在线
        if (device->deviceType() == DeviceType::Locator) {
            return;
        }

        if (checkedDeviceId == deviceId)
            device->setOnline(online);
    });
    connect(device, &QObject::destroyed, this, [this, deviceId]() {
        unbindDeviceId(deviceId);
    });

    if (!ip.isEmpty())
        requestOnlineCheck();
}

void DeviceExecutorManager::unbindDevice(Device *device)
{
    if (device)
        unbindDeviceId(device->id());
}

void DeviceExecutorManager::execute(const QString &executionId,
                                    DeviceCommand *command,
                                    const QVariantMap &executionInputValues)
{
    if (executionId.isEmpty() || !command)
        return;

    const QVariantMap params = command->resolvedParams(executionInputValues);

    DeviceCommandExecutor *executor = executorFor(command->protocol(), params);
    if (executor) {
        QMetaObject::invokeMethod(executor, [executor, executionId, command, params]() {
            executor->execute(executionId, command, params);
        }, Qt::QueuedConnection);
        return;
    }

    emit executionFinished(executionId, command, false, tr("没有可用的执行器"));
}

void DeviceExecutorManager::checkOnline()
{
    m_onlineCheckRequested = false;
    QHash<QString, QStringList> requestIdsByTarget;
    QHash<QString, OnlineCheck> checksByTarget;
    for (auto it = m_onlineChecks.cbegin(); it != m_onlineChecks.cend(); ++it) {
        const OnlineCheck &check = it.value();
        if (check.ip.isEmpty())
            continue;

        const QString targetKey = QStringLiteral("%1:%2")
                                      .arg(check.tcpPort)
                                      .arg(check.ip);
        requestIdsByTarget[targetKey].append(it.key());
        if (!checksByTarget.contains(targetKey))
            checksByTarget.insert(targetKey, check);
    }

    for (auto it = requestIdsByTarget.cbegin(); it != requestIdsByTarget.cend(); ++it) {
        NetworkPing *networkPing = m_networkPing;
        const QStringList deviceIds = it.value();
        const OnlineCheck check = checksByTarget.value(it.key());
        QMetaObject::invokeMethod(networkPing, [networkPing, deviceIds, check]() {
            networkPing->checkOnline(deviceIds, check.ip, check.tcpPort);
        }, Qt::QueuedConnection);
    }
}

void DeviceExecutorManager::unbindDeviceId(const QString &deviceId)
{
    const OnlineCheck onlineCheck = m_onlineChecks.take(deviceId);
    if (onlineCheck.executorKey.isEmpty())
        return;

    QStringList deviceIds = m_deviceIdsByExecutorKey.value(onlineCheck.executorKey);
    deviceIds.removeAll(deviceId);
    if (!deviceIds.isEmpty()) {
        m_deviceIdsByExecutorKey.insert(onlineCheck.executorKey, deviceIds);
        return;
    }

    m_deviceIdsByExecutorKey.remove(onlineCheck.executorKey);
    DeviceCommandExecutor *executor = m_executors.take(onlineCheck.executorKey);
    if (executor)
        executor->deleteLater();
}

void DeviceExecutorManager::requestOnlineCheck()
{
    if (m_onlineCheckRequested)
        return;

    m_onlineCheckRequested = true;
    QTimer::singleShot(0, this, &DeviceExecutorManager::checkOnline);
}

DeviceCommandExecutor *DeviceExecutorManager::executorFor(const QString &protocol,
                                                          const QVariantMap &params,
                                                          QString *executorKey)
{
    const QString protocolValue = protocol.trimmed();
    QString key;
    DeviceCommandExecutor *executor = nullptr;
    if (protocolValue == DeviceProtocol::Serial) {
        const QString ip = params.value(DeviceKey::Ip).toString().trimmed();
        const QString portName = params.value(DeviceKey::SerialPort).toString().trimmed();
        if (ip.isEmpty() || portName.isEmpty())
            return nullptr;

        key = QStringLiteral("serial:%1:%2").arg(ip, portName);
        if (executorKey)
            *executorKey = key;
        executor = m_executors.value(key);
        if (!executor)
            executor = new SerialCommandExecutor(ip, portName);
    } else if (protocolValue == DeviceProtocol::Http || protocolValue == DeviceProtocol::Pc) {
        const QString ip = params.value(DeviceKey::Ip).toString().trimmed();
        const int port = params.value(DeviceKey::Port).toInt();
        if (ip.isEmpty() || port <= 0)
            return nullptr;

        key = QStringLiteral("http:%1:%2").arg(ip).arg(port);
        if (executorKey)
            *executorKey = key;
        executor = m_executors.value(key);
        if (!executor)
            executor = new HttpCommandExecutor(ip, port);
    } else if (protocolValue == DeviceProtocol::Udp) {
        const QString ip = params.value(DeviceKey::Ip).toString().trimmed();
        const int port = params.value(DeviceKey::Port).toInt();
        if (ip.isEmpty() || port <= 0)
            return nullptr;

        key = QStringLiteral("udp:%1:%2").arg(ip).arg(port);
        if (executorKey)
            *executorKey = key;
        executor = m_executors.value(key);
        if (!executor)
            executor = new UdpCommandExecutor(ip, port);
    } else if (protocolValue == DeviceProtocol::Dmx512) {
        const QString ip = params.value(DeviceKey::Ip).toString().trimmed();
        const int port = params.value(DeviceKey::Port, 80).toInt();
        if (ip.isEmpty() || port <= 0)
            return nullptr;

        key = QStringLiteral("dmx512:%1:%2").arg(ip).arg(port);
        if (executorKey)
            *executorKey = key;
        executor = m_executors.value(key);
        if (!executor)
            executor = new DmxCommandExecutor(ip, port);
    }

    if (executor && !m_executors.contains(key)) {
        executor->moveToThread(&m_thread);
        m_executors.insert(key, executor);
        connect(executor, &DeviceCommandExecutor::executionFinished, this, &DeviceExecutorManager::executionFinished);
        connect(&m_thread, &QThread::finished, executor, &QObject::deleteLater);
    }
    return executor;
}
