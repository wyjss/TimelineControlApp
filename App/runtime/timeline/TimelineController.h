#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QTimer>


class TimelineController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state WRITE setState NOTIFY stateChanged FINAL)
    Q_PROPERTY(qint64 currentTimeMs READ currentTimeMs WRITE setCurrentTimeMs NOTIFY currentTimeMsChanged FINAL)
    Q_PROPERTY(qint64 durationMs READ durationMs WRITE setDurationMs NOTIFY durationMsChanged FINAL)
    Q_PROPERTY(int tickIntervalMs READ tickIntervalMs WRITE setTickIntervalMs NOTIFY tickIntervalMsChanged FINAL)

public:
    enum State
    {
        Stopped,
        Running,
        Paused,
        Completed
    };
    Q_ENUM(State)

    explicit TimelineController(QObject *parent = nullptr);

    State state() const;
    void setState(State state);

    qint64 currentTimeMs() const;
    void setCurrentTimeMs(qint64 currentTimeMs);

    qint64 durationMs() const;
    void setDurationMs(qint64 durationMs);

    int tickIntervalMs() const;
    void setTickIntervalMs(int tickIntervalMs);

    Q_INVOKABLE void start();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(qint64 currentTimeMs);

signals:
    void stateChanged();
    void finished();
    void currentTimeMsChanged();
    void durationMsChanged();
    void tickIntervalMsChanged();

private:
    void updateCurrentTime();

    QTimer m_tickTimer;
    QElapsedTimer m_elapsedTimer;
    State m_state = Stopped;
    qint64 m_currentTimeMs = 0;
    qint64 m_durationMs = 24 * 60 * 60 * 1000;
    qint64 m_runBaseTimeMs = 0;
    int m_tickIntervalMs = 16;
};


Q_DECLARE_METATYPE(TimelineController *)
