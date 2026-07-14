#include "devices/executors/DeviceCommandExecutor.h"

#include "devices/DeviceCommand.h"


DeviceCommandExecutor::DeviceCommandExecutor(QObject *parent)
    : QObject(parent)
{
}

void DeviceCommandExecutor::execute(DeviceCommand *command, const QVariantMap &params)
{
    if (!command)
        return;

    if (m_failed) {
        emit executionFinished(command, false, m_errorMessage);
        return;
    }

    executeImpl(command, params);
}

void DeviceCommandExecutor::checkOnline(const QStringList &requestIds, const QVariantMap &params)
{
    const bool online = checkOnlineImpl(params);
    for (const QString &requestId : requestIds)
        emit onlineChecked(requestId, online);
}

void DeviceCommandExecutor::markFailed(const QString &errorMessage)
{
    m_failed = true;
    m_errorMessage = errorMessage;
}
