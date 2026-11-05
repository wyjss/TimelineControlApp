#pragma once

#include <QRunnable>
#include <QString>
#include <QtGlobal>
#include <functional>

class NetworkPing final : public QRunnable
{
public:
    NetworkPing(const QString &ip, quint16 tcpPort, std::function<void(bool)> finished);
    void run() override;

private:
    QString m_ip;
    quint16 m_tcpPort = 0;
    std::function<void(bool)> m_finished;

    // 探测 IPv4 地址或主机名，timeoutMs 单位为毫秒
    static bool ping(const QString &host, quint32 timeoutMs = 1000);

    static QString resolveIPv4(const QString &host);
};
