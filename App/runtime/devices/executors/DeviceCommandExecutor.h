#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>


class DeviceCommand;

class DeviceCommandExecutor : public QObject
{
    Q_OBJECT
public:
    explicit DeviceCommandExecutor(QObject *parent = nullptr);

    void execute(DeviceCommand *command, const QVariantMap &params);
    void checkOnline(const QStringList &requestIds, const QVariantMap &params);

signals:
    void executionFinished(DeviceCommand *command,
                           bool success,
                           const QString &errorMessage);
    void onlineChecked(const QString &requestId, bool online);

protected:
    void markFailed(const QString &errorMessage);
    virtual void executeImpl(DeviceCommand *command, const QVariantMap &params) = 0;
    virtual bool checkOnlineImpl(const QVariantMap &params) = 0;

private:
    bool m_failed = false;
    QString m_errorMessage;
};
