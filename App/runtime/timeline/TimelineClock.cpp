#include "timeline/TimelineClock.h"
#include <QtGlobal>


TimelineClock::TimelineClock(QObject *parent)
    : QObject(parent)
{
    m_tickTimer.setInterval(16);
    m_tickTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_tickTimer, &QTimer::timeout, this, &TimelineClock::updateCurrentTime);
}

TimelineClock::State TimelineClock::state() const
{
    return m_state;
}

void TimelineClock::setState(State state)
{
    if (m_state == state)
        return;

    if (m_state == Running)
        setCurrentTimeMs(m_runBaseTimeMs + m_elapsedTimer.elapsed());

    if (state == Running) {
        m_runBaseTimeMs = m_currentTimeMs;
        m_elapsedTimer.restart();
        m_tickTimer.start();
    } else {
        m_tickTimer.stop();
    }

    m_state = state;
    emit stateChanged();
}

qint64 TimelineClock::currentTimeMs() const
{
    return m_currentTimeMs;
}

void TimelineClock::setCurrentTimeMs(qint64 currentTimeMs)
{
    const qint64 normalizedTimeMs = qMax<qint64>(0, currentTimeMs);

    if (m_currentTimeMs == normalizedTimeMs)
        return;

    m_currentTimeMs = normalizedTimeMs;
    if (m_state == Running) {
        m_runBaseTimeMs = m_currentTimeMs;
        m_elapsedTimer.restart();
    }
    emit currentTimeMsChanged();
}

void TimelineClock::start()
{
    if (m_state == Stopped || m_state == Completed)
        setCurrentTimeMs(0);

    setState(Running);
}

void TimelineClock::pause()
{
    setState(Paused);
}

void TimelineClock::stop()
{
    setState(Stopped);
}

void TimelineClock::updateCurrentTime()
{
    if (m_state != Running)
        return;

    setCurrentTimeMs(m_runBaseTimeMs + m_elapsedTimer.elapsed());
}
