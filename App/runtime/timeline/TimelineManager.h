#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

#include "timeline/TimelineCommand.h"

namespace TimelineControl {

class TimelineManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int durationMs READ durationMs WRITE setDurationMs NOTIFY durationMsChanged FINAL)
    Q_PROPERTY(TimelineControl::TimelineCommand *lastCommand READ lastCommand NOTIFY lastCommandChanged FINAL)

public:
    explicit TimelineManager(TimelineCommandModel *commandModel, QObject *parent = nullptr);

    int durationMs() const;
    void setDurationMs(int durationMs);

    TimelineCommand *lastCommand() const;

    Q_INVOKABLE TimelineControl::TimelineCommand *addCommand(qint64 startTimeMs,
                                                             const QString &targetDeviceId,
                                                             const QString &commandName,
                                                             const QVariantMap &commandParams);
    Q_INVOKABLE void clearCommands();

public slots:
    void removeCommandsForDevice(const QString &deviceId);

signals:
    void durationMsChanged();
    void lastCommandChanged();

private:
    QString nextCommandId();

    int m_durationMs = 1800000;
    int m_nextCommandNumber = 1;
    TimelineCommandModel *m_commandModel = nullptr;
    TimelineCommand *m_lastCommand = nullptr;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::TimelineManager *)
