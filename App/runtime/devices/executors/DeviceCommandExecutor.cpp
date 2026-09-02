#include "devices/executors/DeviceCommandExecutor.h"

#include "devices/DeviceCommand.h"


DeviceCommandExecutor::DeviceCommandExecutor(QObject *parent)
    : QObject(parent)
{
}

void DeviceCommandExecutor::execute(const QString &executionId,
                                    DeviceCommand *command,
                                    const QVariantMap &params)
{
    if (executionId.isEmpty() || !command)
        return;

    if (m_failed && m_time.elapsed() > 2000) {
        m_failed = false;
    }
    if (m_failed) {
        emit executionFinished(executionId, command, false, m_errorMessage);
        return;
    }

    executeImpl(executionId, command, params);
}

void DeviceCommandExecutor::markFailed(const QString &errorMessage)
{
    m_time.restart();
    m_failed = true;
    m_errorMessage = errorMessage;
}
