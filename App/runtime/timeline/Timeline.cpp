#include "timeline/Timeline.h"

#include <QDataStream>
#include <QtGlobal>

#include <algorithm>


Timeline::Timeline(const QString &id,
                   const QString &name,
                   QObject *parent)
    : QObject(parent)
    , m_id(id)
    , m_name(name)
    , m_commandModel(new TimelineCommandModel(this))
{
}

QString Timeline::id() const
{
    return m_id;
}

QString Timeline::name() const
{
    return m_name;
}

TimelineCommandModel *Timeline::commandModel() const
{
    return m_commandModel;
}

Timeline::State Timeline::state() const
{
    return m_state;
}

qint64 Timeline::currentTimeMs() const
{
    return m_currentTimeMs;
}

qint64 Timeline::durationMs() const
{
    return m_durationMs;
}

void Timeline::setDurationMs(qint64 durationMs)
{
    const qint64 normalizedDurationMs = qMax<qint64>(0, durationMs);
    if (m_durationMs == normalizedDurationMs)
        return;

    m_durationMs = normalizedDurationMs;
    emit durationMsChanged(m_durationMs);
}

qint64 Timeline::relativeStartTimeMs() const
{
    return m_relativeStartTimeMs;
}

void Timeline::waitForTrigger()
{
    if (m_state == Waiting || m_state == Running)
        return;

    m_state = Waiting;
    emit stateChanged(m_state);
}

void Timeline::start(qint64 masterTimeMs)
{
    if (m_state == Running)
        return;

    m_playCommands = m_commandModel->commands();
    std::stable_sort(m_playCommands.begin(), m_playCommands.end(),
                     [](TimelineCommand *left, TimelineCommand *right) {
        return left->startTimeMs() < right->startTimeMs();
    });
    m_nextCommandIndex = 0;

    // 重置指令并计算durationMs
    qint64 durationMs = 0;
    for (TimelineCommand *command : m_playCommands) {
        durationMs = qMax(durationMs,
                          command->startTimeMs() + command->durationMs());
        command->setErrorMessage(QString());
        command->setState(TimelineCommand::Idle);
    }
    setDurationMs(durationMs);

    const qint64 relativeStartTimeMs = qMax<qint64>(0, masterTimeMs);
    if (m_relativeStartTimeMs != relativeStartTimeMs) {
        m_relativeStartTimeMs = relativeStartTimeMs;
        emit relativeStartTimeMsChanged();
    }
    if (m_currentTimeMs != 0) {
        m_currentTimeMs = 0;
        emit currentTimeMsChanged(m_currentTimeMs);
    }
    m_state = Running;
    emit stateChanged(m_state);
}

void Timeline::stop()
{
    if (m_state == Stopped)
        return;

    m_state = Stopped;
    emit stateChanged(m_state);
}

QList<TimelineCommand *> Timeline::updateTime(qint64 masterTimeMs)
{
    QList<TimelineCommand *> triggeredCommands;
    if (m_state != Running)
        return triggeredCommands;

    qint64 currentTimeMs = qMax<qint64>(0,
        masterTimeMs - m_relativeStartTimeMs);
    currentTimeMs = qMin(currentTimeMs, m_durationMs);

    if (m_currentTimeMs != currentTimeMs) {
        m_currentTimeMs = currentTimeMs;
        emit currentTimeMsChanged(m_currentTimeMs);
    }
    while (m_nextCommandIndex < m_playCommands.size()) {
        TimelineCommand *command = m_playCommands.at(m_nextCommandIndex);
        if (command->startTimeMs() > m_currentTimeMs)
            break;

        ++m_nextCommandIndex;
        if (command->state() != TimelineCommand::Idle)
            continue;

        command->setState(TimelineCommand::Running);
        triggeredCommands.append(command);
    }
    if (m_currentTimeMs >= m_durationMs) {
        m_state = Completed;
        emit stateChanged(m_state);
    }
    return triggeredCommands;
}

void Timeline::writeToStream(QDataStream &stream) const
{
    stream << m_id << m_name;
    m_commandModel->writeToStream(stream);
}

Timeline *Timeline::readFromStream(QDataStream &stream, QObject *parent)
{
    QString id;
    QString name;
    stream >> id >> name;
    id = id.trimmed();
    name = name.trimmed();
    if (stream.status() != QDataStream::Ok || id.isEmpty() || name.isEmpty()) {
        stream.setStatus(QDataStream::ReadCorruptData);
        return nullptr;
    }

    auto *timeline = new Timeline(id, name, parent);
    timeline->commandModel()->readFromStream(stream);
    if (stream.status() == QDataStream::Ok)
        return timeline;

    delete timeline;
    return nullptr;
}
