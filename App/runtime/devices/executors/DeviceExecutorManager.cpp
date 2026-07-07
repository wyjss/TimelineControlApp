#include "devices/executors/DeviceExecutorManager.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceParamSpec.h"
#include "devices/executors/DeviceCommandExecutor.h"
#include "devices/executors/HttpCommandExecutor.h"
#include "devices/executors/SerialCommandExecutor.h"

#include <QMetaObject>

using namespace TimelineControl;

DeviceExecutorManager::DeviceExecutorManager(QObject *parent)
    : QObject(parent)
{
    m_onlineCheckTimer.setInterval(15000);
    connect(&m_onlineCheckTimer, &QTimer::timeout, this, &DeviceExecutorManager::checkOnline);
    m_onlineCheckTimer.start();
    m_thread.start();
}

DeviceExecutorManager::~DeviceExecutorManager()
{
    m_thread.quit();
    m_thread.wait();
}

void DeviceExecutorManager::bindDevice(Device *device)
{
    if (!device)
        return;

    unbindDevice(device);

    for (const QString &protocol : device->supportedProtocols()) {
        const QString protocolValue = protocol.trimmed();
        if (protocolValue != DeviceProtocol::Http
            && protocolValue != DeviceProtocol::Serial
            && protocolValue != DeviceProtocol::Pc)
            continue;

        QVariantMap params = device->configValues();
        DeviceCommand *command = DeviceCommand::createForProtocol(protocolValue);
        if (command) {
            command->updateConfigMap(params);
            const QVariantList creationFields = command->creationInputFields();
            for (const QVariant &fieldValue : creationFields) {
                DeviceParamSpec *field = fieldValue.value<DeviceParamSpec *>();
                if (field)
                    params.insert(field->key(), field->value());
            }
            const QVariantList executionFields = command->executionInputFields();
            for (const QVariant &fieldValue : executionFields) {
                DeviceParamSpec *field = fieldValue.value<DeviceParamSpec *>();
                if (field)
                    params.insert(field->key(), field->value());
            }
            delete command;
        }

        QString executorKey;
        bool created = false;
        DeviceCommandExecutor *executor = executorFor(protocolValue, params, &executorKey, &created);
        if (!executor)
            return;

        const QString deviceId = device->id();
        m_onlineChecks.insert(deviceId, OnlineCheck{params, executorKey});
        QStringList deviceIds = m_deviceIdsByExecutorKey.value(executorKey);
        if (!deviceIds.contains(deviceId)) {
            deviceIds.append(deviceId);
            m_deviceIdsByExecutorKey.insert(executorKey, deviceIds);
        }

        connect(this, &DeviceExecutorManager::onlineChecked, device, [this, device, deviceId](const QString &checkedDeviceId, bool online) {
            if (checkedDeviceId == deviceId)
                device->setStatus(online ? tr("在线") : tr("离线"));
        });
        connect(device, &QObject::destroyed, this, [this, deviceId]() {
            unbindDeviceId(deviceId);
        });

        if (created)
            requestOnlineCheck();
        return;
    }
}

void DeviceExecutorManager::unbindDevice(Device *device)
{
    if (device)
        unbindDeviceId(device->id());
}

void DeviceExecutorManager::execute(Device *device, DeviceCommand *command)
{
    if (!command)
        return;

    if (device)
        command->updateConfigMap(device->configValues());

    QVariantMap params;
    const QVariantList creationFields = command->creationInputFields();
    for (const QVariant &fieldValue : creationFields) {
        DeviceParamSpec *field = fieldValue.value<DeviceParamSpec *>();
        if (field)
            params.insert(field->key(), field->value());
    }
    const QVariantList executionFields = command->executionInputFields();
    for (const QVariant &fieldValue : executionFields) {
        DeviceParamSpec *field = fieldValue.value<DeviceParamSpec *>();
        if (field)
            params.insert(field->key(), field->value());
    }

    DeviceCommandExecutor *executor = executorFor(command->protocol(), params);
    if (executor) {
        QMetaObject::invokeMethod(executor, [executor, command, params]() {
            executor->execute(command, params);
        }, Qt::QueuedConnection);
        return;
    }

    emit executionFinished(command, false, tr("没有可用的执行器"));
}

void DeviceExecutorManager::checkOnline()
{
    m_onlineCheckRequested = false;
    QHash<DeviceCommandExecutor *, QStringList> requestIdsByExecutor;
    QHash<DeviceCommandExecutor *, QVariantMap> paramsByExecutor;
    for (auto it = m_onlineChecks.cbegin(); it != m_onlineChecks.cend(); ++it) {
        DeviceCommandExecutor *executor = m_executors.value(it.value().executorKey);
        if (!executor) {
            emit onlineChecked(it.key(), false);
            continue;
        }

        requestIdsByExecutor[executor].append(it.key());
        if (!paramsByExecutor.contains(executor))
            paramsByExecutor.insert(executor, it.value().params);
    }

    for (auto it = requestIdsByExecutor.cbegin(); it != requestIdsByExecutor.cend(); ++it) {
        DeviceCommandExecutor *executor = it.key();
        const QStringList requestIds = it.value();
        const QVariantMap params = paramsByExecutor.value(executor);
        QMetaObject::invokeMethod(executor, [executor, requestIds, params]() {
            executor->checkOnline(requestIds, params);
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
                                                          QString *executorKey,
                                                          bool *created)
{
    if (created)
        *created = false;

    const QString protocolValue = protocol.trimmed();
    if (protocolValue == DeviceProtocol::Serial) {
        const QString portName = params.value(DeviceKey::SerialPort).toString().trimmed();
        const QString key = QStringLiteral("serial:%1").arg(portName);
        if (executorKey)
            *executorKey = key;
        DeviceCommandExecutor *executor = m_executors.value(key);
        if (!executor && !portName.isEmpty()) {
            executor = new SerialCommandExecutor(portName);
            executor->moveToThread(&m_thread);
            m_executors.insert(key, executor);
            connect(executor, &DeviceCommandExecutor::executionFinished, this, &DeviceExecutorManager::executionFinished);
            connect(executor, &DeviceCommandExecutor::onlineChecked, this, &DeviceExecutorManager::onlineChecked);
            connect(&m_thread, &QThread::finished, executor, &QObject::deleteLater);
            if (created)
                *created = true;
        }
        return executor;
    }

    if (protocolValue == DeviceProtocol::Http || protocolValue == DeviceProtocol::Pc) {
        const QString ip = params.value(DeviceKey::Ip).toString().trimmed();
        const int port = params.value(DeviceKey::IpPort).toInt();
        if (ip.isEmpty() || port <= 0)
            return nullptr;

        const QString key = QStringLiteral("%1:%2:%3").arg(protocolValue, ip).arg(port);
        if (executorKey)
            *executorKey = key;
        DeviceCommandExecutor *executor = m_executors.value(key);
        if (!executor) {
            executor = new HttpCommandExecutor(ip, port);
            executor->moveToThread(&m_thread);
            m_executors.insert(key, executor);
            connect(executor, &DeviceCommandExecutor::executionFinished, this, &DeviceExecutorManager::executionFinished);
            connect(executor, &DeviceCommandExecutor::onlineChecked, this, &DeviceExecutorManager::onlineChecked);
            connect(&m_thread, &QThread::finished, executor, &QObject::deleteLater);
            if (created)
                *created = true;
        }
        return executor;
    }

    return nullptr;
}
