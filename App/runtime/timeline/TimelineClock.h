#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>


class TimelineClock final : public QObject
{
    Q_OBJECT

public:
    enum State
    {
        Stopped,
        Running,
        Paused,
        Completed
    };
    explicit TimelineClock(QObject *parent = nullptr);

    State state() const;
    void setState(State state);

    qint64 currentTimeMs() const;
    void start();
    void pause();
    void stop();

signals:
    void stateChanged();
    void currentTimeMsChanged();

private:
    void setCurrentTimeMs(qint64 currentTimeMs);
    void updateCurrentTime();

    QTimer m_tickTimer;
    QElapsedTimer m_elapsedTimer;
    State m_state = Stopped;
    qint64 m_currentTimeMs = 0;
    qint64 m_runBaseTimeMs = 0;
};
