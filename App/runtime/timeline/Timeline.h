#pragma once

#include "timeline/TimelineCommand.h"

#include <QList>
#include <QObject>
#include <QString>


class QDataStream;
class CrossConditionModel;


// 对应一条时间线
class Timeline final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT FINAL)
    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(TimelineCommandModel *commandModel READ commandModel CONSTANT FINAL)
    Q_PROPERTY(CrossConditionModel *crossConditionModel READ crossConditionModel CONSTANT FINAL)
    Q_PROPERTY(State state READ state NOTIFY stateChanged FINAL)
    Q_PROPERTY(qint64 currentTimeMs READ currentTimeMs NOTIFY currentTimeMsChanged FINAL)
    Q_PROPERTY(qint64 durationMs READ durationMs WRITE setDurationMs NOTIFY durationMsChanged FINAL)
    Q_PROPERTY(qint64 relativeStartTimeMs READ relativeStartTimeMs NOTIFY relativeStartTimeMsChanged FINAL)

public:
    enum State
    {
        Stopped,
        Waiting,
        Running,
        Completed
    };
    Q_ENUM(State)

    explicit Timeline(const QString &id,
                      const QString &name,
                      QObject *parent = nullptr);

    QString id() const;
    QString name() const;
    TimelineCommandModel *commandModel() const;
    CrossConditionModel *crossConditionModel() const;
    State state() const;
    qint64 currentTimeMs() const;
    qint64 durationMs() const;
    void setDurationMs(qint64 durationMs);
    qint64 relativeStartTimeMs() const;

    // mgr驱动
    void waitForTrigger();
    void start(qint64 masterTimeMs);
    void stop();
    QList<TimelineCommand *> updateTime(qint64 masterTimeMs);

    void writeToStream(QDataStream &stream) const;
    static Timeline *readFromStream(QDataStream &stream,
                                    int streamVersion,
                                    QObject *parent = nullptr);

signals:
    void stateChanged(State state);
    void currentTimeMsChanged(qint64 timeMs);
    void durationMsChanged(qint64 timeMs);
    void relativeStartTimeMsChanged();

private:
    QString m_id;
    QString m_name;
    TimelineCommandModel *m_commandModel = nullptr;
    CrossConditionModel *m_crossConditionModel = nullptr;
    QList<TimelineCommand *> m_playCommands;
    int m_nextCommandIndex = 0;
    State m_state = Stopped;
    qint64 m_currentTimeMs = 0;
    qint64 m_durationMs = 0;
    qint64 m_relativeStartTimeMs = 0;
};


Q_DECLARE_METATYPE(Timeline *)
