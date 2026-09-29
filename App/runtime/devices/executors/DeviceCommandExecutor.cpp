#include "devices/executors/DeviceCommandExecutor.h"

#include "devices/DeviceCommand.h"
#define LC "[DeviceCommandExecutor] "
#include "runtime/LogMacros.h"

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

#if 0 // 禁用，避免多设备密集指令错判
    if (m_failed && m_time.elapsed() > 2000) {
        m_failed = false;
    }

    if (m_failed && m_time.elapsed() < 2000) {
		LOG_ERROR("超时错误未恢复");
    }
#else
    m_failed = false;
#endif
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
