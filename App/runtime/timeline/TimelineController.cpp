#include "timeline/TimelineController.h"

#include <QtGlobal>

using namespace TimelineControl;

TimelineController::TimelineController(QObject *parent)
    : QObject(parent)
{
    m_tickTimer.setInterval(m_tickIntervalMs);
    m_tickTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_tickTimer, &QTimer::timeout, this, &TimelineController::updateCurrentTime);
}

TimelineController::State TimelineController::state() const
{
    return m_state;
}

void TimelineController::setState(State state)
{
    if (m_state == state)
        return;

    if (m_state == Running)
        setCurrentTimeMs(m_runBaseTimeMs + m_elapsedTimer.elapsed());

    if (state == Running) {
        if (m_durationMs > 0 && m_currentTimeMs >= m_durationMs)
            setCurrentTimeMs(0);
        m_runBaseTimeMs = m_currentTimeMs;
        m_elapsedTimer.restart();
        m_tickTimer.start();
    } else {
        m_tickTimer.stop();
    }

    m_state = state;
    emit stateChanged();
}

qint64 TimelineController::currentTimeMs() const
{
    return m_currentTimeMs;
}

void TimelineController::setCurrentTimeMs(qint64 currentTimeMs)
{
    qint64 normalizedTimeMs = qMax<qint64>(0, currentTimeMs);
    if (m_durationMs > 0)
        normalizedTimeMs = qMin(normalizedTimeMs, m_durationMs);

    if (m_currentTimeMs == normalizedTimeMs)
        return;

    m_currentTimeMs = normalizedTimeMs;
    if (m_state == Running) {
        m_runBaseTimeMs = m_currentTimeMs;
        m_elapsedTimer.restart();
    }
    emit currentTimeMsChanged();
}

qint64 TimelineController::durationMs() const
{
    return m_durationMs;
}

void TimelineController::setDurationMs(qint64 durationMs)
{
    const qint64 normalizedDurationMs = qMax<qint64>(0, durationMs);
    if (m_durationMs == normalizedDurationMs)
        return;

    m_durationMs = normalizedDurationMs;
    if (m_durationMs > 0 && m_currentTimeMs > m_durationMs)
        setCurrentTimeMs(m_durationMs);
    emit durationMsChanged();
}

int TimelineController::tickIntervalMs() const
{
    return m_tickIntervalMs;
}

void TimelineController::setTickIntervalMs(int tickIntervalMs)
{
    const int normalizedTickIntervalMs = qMax(1, tickIntervalMs);
    if (m_tickIntervalMs == normalizedTickIntervalMs)
        return;

    m_tickIntervalMs = normalizedTickIntervalMs;
    m_tickTimer.setInterval(m_tickIntervalMs);
    emit tickIntervalMsChanged();
}

void TimelineController::start()
{
    if (m_state == Stopped)
        setCurrentTimeMs(0);

    setState(Running);
}

void TimelineController::pause()
{
    setState(Paused);
}

void TimelineController::stop()
{
    setState(Stopped);
}

void TimelineController::seek(qint64 currentTimeMs)
{
    setCurrentTimeMs(currentTimeMs);
}

void TimelineController::updateCurrentTime()
{
    if (m_state != Running)
        return;

    const qint64 nextTimeMs = m_runBaseTimeMs + m_elapsedTimer.elapsed();
    if (m_durationMs > 0 && nextTimeMs >= m_durationMs) {
        setCurrentTimeMs(m_durationMs);
        m_tickTimer.stop();
        m_state = Stopped;
        emit stateChanged();
        return;
    }

    setCurrentTimeMs(nextTimeMs);
}
