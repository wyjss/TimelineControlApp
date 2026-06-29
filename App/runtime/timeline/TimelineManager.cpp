#include "timeline/TimelineManager.h"

namespace TimelineControl {

TimelineManager::TimelineManager(TimelineCommandModel *commandModel, QObject *parent)
    : QObject(parent)
    , m_commandModel(commandModel)
{
    if (m_commandModel) {
        connect(m_commandModel, &TimelineCommandModel::commandAboutToBeRemoved, this, [this](TimelineCommand *command) {
            if (m_lastCommand != command)
                return;

            m_lastCommand = nullptr;
            emit lastCommandChanged();
        });
    }
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
    return addCommand(startTimeMs, targetDeviceId, commandName, commandParams, nullptr);
}

TimelineCommand *TimelineManager::addCommand(qint64 startTimeMs,
                                             const QString &targetDeviceId,
                                             const QString &commandName,
                                             const QVariantMap &commandParams,
                                             DeviceCommand *targetCommand)
{
    if (!m_commandModel)
        return nullptr;

    auto *command = new TimelineCommand(startTimeMs,
                                        targetDeviceId,
                                        commandName,
                                        commandParams,
                                        targetCommand);
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

} // namespace TimelineControl
