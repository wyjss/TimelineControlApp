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
    /**
     * @brief Ping 一个 IPv4 地址或主机名
     *
     * @param host      例如 "192.168.1.10" / "localhost" / "device.local"
     * @param timeoutMs 超时时间，单位 ms
     */
    static bool ping(const QString& host,
                     quint32 timeoutMs = 1000);

    static QString resolveIPv4(const QString& host);
};
