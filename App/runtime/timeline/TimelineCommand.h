#pragma once

#include <QList>
#include <QObject>
#include <QPointer>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include "models/TypedListModel.h"

class QDataStream;


class DeviceCommand;

class TimelineCommand final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString id READ id CONSTANT FINAL)
    Q_PROPERTY(qint64 startTimeMs READ startTimeMs WRITE setStartTimeMs NOTIFY startTimeMsChanged FINAL)
    Q_PROPERTY(QString targetDeviceId READ targetDeviceId CONSTANT FINAL)
    Q_PROPERTY(QString commandName READ commandName CONSTANT FINAL)
    Q_PROPERTY(QVariantMap commandParams READ commandParams WRITE setCommandParams NOTIFY commandParamsChanged FINAL)
    Q_PROPERTY(qint64 durationMs READ durationMs NOTIFY commandParamsChanged FINAL)
    Q_PROPERTY(State state READ state WRITE setState NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString stateText READ stateText NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString stateColor READ stateColor NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString errorMessage READ errorMessage WRITE setErrorMessage NOTIFY errorMessageChanged FINAL)

public:
    enum State
    {
        Idle,
        Running,
        Succeeded,
        Failed
    };
    Q_ENUM(State)

    TimelineCommand(qint64 startTimeMs,
                    const QString &targetDeviceId,
                    const QString &commandName,
                    const QVariantMap &commandParams,
                    DeviceCommand *targetCommand,
                    QObject *parent = nullptr);

    QString id() const;

    qint64 startTimeMs() const;
    void setStartTimeMs(qint64 startTimeMs);

    QString targetDeviceId() const;

    QString commandName() const;

    QVariantMap commandParams() const;
    void setCommandParams(const QVariantMap &commandParams);

    DeviceCommand *targetCommand() const;

    qint64 durationMs() const;

    State state() const;
    void setState(State state);
    QString stateText() const;
    QString stateColor() const;

    QString errorMessage() const;
    void setErrorMessage(const QString &errorMessage);

    void writeToStream(QDataStream &stream) const;
    void readFromStream(QDataStream &stream);

signals:
    void startTimeMsChanged();
    void commandParamsChanged();
    void targetCommandDestroyed();
    void stateChanged();
    void errorMessageChanged();

private:
    QString m_id;
    qint64 m_startTimeMs = 0;
    QString m_targetDeviceId;
    QString m_commandName;
    QVariantMap m_commandParams;
    QPointer<DeviceCommand> m_targetCommand;
    State m_state = Idle;
    QString m_errorMessage;
};

class TimelineCommandModel final : public TypedListModel<TimelineCommand *>
{
    Q_OBJECT
    Q_PROPERTY(QVariantList commands READ commandVariants NOTIFY commandsChanged FINAL)
    //! 父轨 ID 到只读子轨投影列表的映射。
    Q_PROPERTY(QVariantMap childTracksByParentId READ childTracksByParentId NOTIFY commandsChanged FINAL)
    Q_PROPERTY(QString selectedCommandId READ selectedCommandId WRITE setSelectedCommandId NOTIFY selectedCommandIdChanged FINAL)

public:
    explicit TimelineCommandModel(QObject *parent = nullptr);
    ~TimelineCommandModel() override;

    QList<TimelineCommand *> commands() const;
    QVariantList commandVariants() const;
    QVariantMap childTracksByParentId() const;
    TimelineCommand *commandAt(int row) const;
    TimelineCommand *commandById(const QString &id) const;
    int indexOfCommand(TimelineCommand *command) const;

    QString selectedCommandId() const;
    void setSelectedCommandId(const QString &selectedCommandId);

    Q_INVOKABLE TimelineCommand *addDeviceCommand(qint64 startTimeMs,
                                                                   const QString &targetDeviceId,
                                                                   DeviceCommand *targetCommand,
                                                                   const QVariantMap &extraParams);
    TimelineCommand *addCommand(qint64 startTimeMs,
                                                 const QString &targetDeviceId,
                                                 const QString &commandName,
                                                 const QVariantMap &commandParams,
                                                 DeviceCommand *targetCommand);

    void resetCommands(const QList<TimelineCommand *> &commands);
    void removeCommandAt(int row);
    Q_INVOKABLE bool removeCommand(TimelineCommand *command);

    void writeToStream(QDataStream &stream) const;
    void readFromStream(QDataStream &stream);

    void removeCommandsForDevice(const QString &deviceId);

signals:
    void commandsChanged();
    void selectedCommandIdChanged();

protected:
    bool acceptsItem(TimelineCommand *command) const override;
    void itemInserted(TimelineCommand *command, int row) override;
    void itemRemoved(TimelineCommand *command, int row) override;

private:
    void prepareCommand(TimelineCommand *command);
    void disconnectCommand(TimelineCommand *command);
    void emitCommandChanged(TimelineCommand *command);

    QString m_selectedCommandId;
};


Q_DECLARE_METATYPE(TimelineCommand *)
Q_DECLARE_METATYPE(TimelineCommandModel *)
