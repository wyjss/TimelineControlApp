#pragma once

#include <QAbstractListModel>
#include <QList>
#include <QObject>
#include <QString>
#include <QVariant>
#include <QVariantList>
#include <QVariantMap>

namespace TimelineControl {

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

    TimelineCommand(const QString &id,
                    qint64 startTimeMs,
                    const QString &targetDeviceId,
                    const QString &commandName,
                    const QVariantMap &commandParams,
                    QObject *parent = nullptr);

    QString id() const;

    qint64 startTimeMs() const;
    void setStartTimeMs(qint64 startTimeMs);

    QString targetDeviceId() const;

    QString commandName() const;

    QVariantMap commandParams() const;
    void setCommandParams(const QVariantMap &commandParams);

    qint64 durationMs() const;

    State state() const;
    void setState(State state);

    QString errorMessage() const;
    void setErrorMessage(const QString &errorMessage);

signals:
    void startTimeMsChanged();
    void commandParamsChanged();
    void stateChanged();
    void errorMessageChanged();

private:
    QString m_id;
    qint64 m_startTimeMs = 0;
    QString m_targetDeviceId;
    QString m_commandName;
    QVariantMap m_commandParams;
    State m_state = Idle;
    QString m_errorMessage;
};

class TimelineCommandModel final : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(QString selectedCommandId READ selectedCommandId WRITE setSelectedCommandId NOTIFY selectedCommandIdChanged FINAL)

public:
    enum Role
    {
        CommandRole = Qt::UserRole + 1
    };
    Q_ENUM(Role)

    explicit TimelineCommandModel(QObject *parent = nullptr);
    ~TimelineCommandModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QList<TimelineCommand *> commands() const;
    TimelineCommand *commandAt(int row) const;
    TimelineCommand *commandById(const QString &id) const;
    int indexOfCommand(TimelineCommand *command) const;

    QString selectedCommandId() const;
    void setSelectedCommandId(const QString &selectedCommandId);

    void appendCommand(TimelineCommand *command);
    void resetCommands(const QList<TimelineCommand *> &commands);
    void removeCommandAt(int row);
    void clear();

signals:
    void selectedCommandIdChanged();

private:
    void prepareCommand(TimelineCommand *command);
    void emitCommandChanged(TimelineCommand *command);

    QList<TimelineCommand *> m_commands;
    QString m_selectedCommandId;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::TimelineCommand *)
Q_DECLARE_METATYPE(TimelineControl::TimelineCommandModel *)
