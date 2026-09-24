#include "timeline/Timeline.h"

#include "devices/CrossConditionModel.h"

#include <QDataStream>
#include <QtGlobal>

#include <QtAlgorithms>


Timeline::Timeline(const QString &id,
                   const QString &name,
                   QObject *parent)
    : QObject(parent)
    , m_id(id)
    , m_name(name)
    , m_commandModel(new TimelineCommandModel(this))
    , m_crossConditionModel(new CrossConditionModel(this, this))
{
    connect(m_commandModel, &TimelineCommandModel::commandScheduleChanged, this, [this](TimelineCommand *retimedCommand) {
        const QList<TimelineCommand *> commands = m_commandModel->commands();
        for (int index = m_playCommands.size() - 1; index >= 0; --index) {
            if (!commands.contains(m_playCommands.at(index))
                || (index < m_nextCommandIndex && m_playCommands.at(index) == retimedCommand)) {
                m_playCommands.removeAt(index);
                if (index < m_nextCommandIndex)
                    --m_nextCommandIndex;
            }
        }
        if (m_state != Running)
            return;

        // 保留本轮未改时的已处理部分，改时指令按模型中的新顺序重新进入待执行部分。
        QList<TimelineCommand *> pendingCommands = commands;
        for (int index = 0; index < m_nextCommandIndex; ++index)
            pendingCommands.removeOne(m_playCommands.at(index));
        m_playCommands = m_playCommands.mid(0, m_nextCommandIndex) + pendingCommands;
        for (TimelineCommand *command : pendingCommands) {
            command->setState(command->startTimeMs() < m_currentTimeMs
                                  ? TimelineCommand::Skipped : TimelineCommand::Idle);
        }

        qint64 durationMs = m_currentTimeMs;
        for (TimelineCommand *command : commands)
            durationMs = qMax(durationMs, command->startTimeMs());
        setDurationMs(durationMs);
    });
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

CrossConditionModel *Timeline::crossConditionModel() const
{
    return m_crossConditionModel;
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

void Timeline::start(qint64 masterTimeMs, qint64 startTimeMs)
{
    if (m_state == Running)
        return;

    seek(masterTimeMs, startTimeMs);
    m_state = Running;
    emit stateChanged(m_state);
}

void Timeline::seek(qint64 masterTimeMs, qint64 startTimeMs)
{
    const QList<TimelineCommand *> processedCommands = m_playCommands.mid(0, m_nextCommandIndex);
    m_playCommands = m_commandModel->commands();
    qSort(m_playCommands.begin(), m_playCommands.end(),
                     [](TimelineCommand *left, TimelineCommand *right) {
        return left->startTimeMs() < right->startTimeMs();
    });
    startTimeMs = qMax<qint64>(0, startTimeMs);
    const qint64 rangeStartMs = qMin(m_currentTimeMs, startTimeMs);
    const qint64 rangeEndMs = qMax(m_currentTimeMs, startTimeMs);
    QList<TimelineCommand *> pendingCommands;

    // 启动时全量初始化；定位时仅重置跨越区间内的指令，包含两端。
    qint64 durationMs = 0;
    for (TimelineCommand *command : m_playCommands) {
        durationMs = qMax(durationMs,
                          command->startTimeMs());
        const bool resetState = m_state != Running
            || (startTimeMs != m_currentTimeMs
                && command->startTimeMs() >= rangeStartMs
                && command->startTimeMs() <= rangeEndMs);
        if (resetState) {
            command->setErrorMessage(QString());
            command->setState(command->startTimeMs() < startTimeMs
                                  ? TimelineCommand::Skipped : TimelineCommand::Idle);
        }
        if (command->startTimeMs() >= startTimeMs
            && (resetState || !processedCommands.contains(command)))
            pendingCommands.append(command);
    }
    // 区间外已处理的指令仍留在已处理部分，防止其他指令的编辑重新将其加入待执行队列。
    for (TimelineCommand *command : pendingCommands)
        m_playCommands.removeOne(command);
    m_nextCommandIndex = m_playCommands.size();
    m_playCommands.append(pendingCommands);
    setDurationMs(durationMs);
    startTimeMs = qMin(startTimeMs, m_durationMs);

    const qint64 relativeStartTimeMs = qMax<qint64>(0, masterTimeMs) - startTimeMs;
    if (m_relativeStartTimeMs != relativeStartTimeMs) {
        m_relativeStartTimeMs = relativeStartTimeMs;
        emit relativeStartTimeMsChanged();
    }
    if (m_currentTimeMs != startTimeMs) {
        m_currentTimeMs = startTimeMs;
        emit currentTimeMsChanged(m_currentTimeMs);
    }
}

void Timeline::stop()
{
    if (m_state == Stopped)
        return;


    m_state = Stopped;
    emit stateChanged(m_state);

    m_currentTimeMs = 0;
    emit currentTimeMsChanged(m_currentTimeMs);

    for (auto cmd : m_playCommands) {
        cmd->setState(TimelineCommand::Idle);
    }
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
    m_crossConditionModel->writeToStream(stream);
}

Timeline *Timeline::readFromStream(QDataStream &stream,
                                   int streamVersion,
                                   QObject *parent)
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
    if (stream.status() == QDataStream::Ok && streamVersion >= 2)
        timeline->crossConditionModel()->readFromStream(stream);
    if (stream.status() == QDataStream::Ok)
        return timeline;

    delete timeline;
    return nullptr;
}
