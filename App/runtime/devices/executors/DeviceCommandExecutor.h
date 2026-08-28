#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QTime>


class DeviceCommand;

class DeviceCommandExecutor : public QObject
{
    Q_OBJECT
public:
    explicit DeviceCommandExecutor(QObject *parent = nullptr);

    void execute(DeviceCommand *command, const QVariantMap &params);

signals:
    void executionFinished(DeviceCommand *command,
                           bool success,
                           const QString &errorMessage);

protected:
    void markFailed(const QString &errorMessage);
    virtual void executeImpl(DeviceCommand *command, const QVariantMap &params) = 0;

private:
    QTime m_time;
    bool m_failed = false;
    QString m_errorMessage;
};
