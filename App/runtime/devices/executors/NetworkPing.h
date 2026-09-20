#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QtGlobal>

class NetworkPing final : public QObject
{
    Q_OBJECT
public:
    explicit NetworkPing(QObject *parent = nullptr);

public slots:
    void checkOnline(const QStringList &deviceIds,
                     const QString &ip,
                     quint16 tcpPort = 0);
public:
    void quit();
signals:
    void onlineChecked(const QString &deviceId, bool online);

private:
    bool m_quit = false;
private:
    // 探测 IPv4 地址或主机名，timeoutMs 单位为毫秒
    static bool ping(const QString &host, quint32 timeoutMs = 1000);

    static QString resolveIPv4(const QString &host);
};
