#include "timeline/TimelineManager.h"

namespace TimelineControl {

TimelineManager::TimelineManager(TimelineCommandModel *commandModel, QObject *parent)
    : QObject(parent)
    , m_commandModel(commandModel)
{
}

int TimelineManager::durationMs() const
{
    return m_durationMs;
}

void TimelineManager::setDurationMs(int durationMs)
{
    const int normalizedDuration = qMax(0, durationMs);
    if (m_durationMs == normalizedDuration)
        return;

    m_durationMs = normalizedDuration;
    emit durationMsChanged();
}

TimelineCommand *TimelineManager::lastCommand() const
{
    return m_lastCommand;
}

TimelineCommand *TimelineManager::addCommand(qint64 startTimeMs,
                                             const QString &targetDeviceId,
                                             const QString &commandName,
                                             const QVariantMap &commandParams)
{
    if (!m_commandModel)
        return nullptr;

    auto *command = new TimelineCommand(nextCommandId(),
                                        startTimeMs,
                                        targetDeviceId,
                                        commandName,
                                        commandParams);
    if (m_commandModel)
        m_commandModel->appendCommand(command);
    m_lastCommand = command;
    emit lastCommandChanged();
    return command;
}

void TimelineManager::clearCommands()
{
    if ((!m_commandModel || m_commandModel->rowCount() == 0) && !m_lastCommand)
        return;

    m_lastCommand = nullptr;
    if (m_commandModel)
        m_commandModel->clear();
    emit lastCommandChanged();
}

void TimelineManager::removeCommandsForDevice(const QString &deviceId)
{
    if (!m_commandModel)
        return;

    const QString normalizedDeviceId = deviceId.trimmed();
    if (normalizedDeviceId.isEmpty())
        return;

    bool lastCommandRemoved = false;
    for (int row = m_commandModel->rowCount() - 1; row >= 0; --row) {
        TimelineCommand *command = m_commandModel->commandAt(row);
        if (!command || command->targetDeviceId() != normalizedDeviceId)
            continue;

        if (command == m_lastCommand)
            lastCommandRemoved = true;
        m_commandModel->removeCommandAt(row);
    }

    if (lastCommandRemoved) {
        m_lastCommand = nullptr;
        emit lastCommandChanged();
    }
}

QString TimelineManager::nextCommandId()
{
    return QStringLiteral("command-%1").arg(m_nextCommandNumber++);
}

} // namespace TimelineControl
