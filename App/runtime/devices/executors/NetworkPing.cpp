#include "devices/executors/NetworkPing.h"

#include <LogMacros.h>

#include <QByteArray>
#include <QHostAddress>
#include <QHostInfo>
#include <QNetworkProxy>
#include <QTcpSocket>

#ifdef Q_OS_WIN

// winsock2.h 必须放在 windows.h 前面
#include <winsock2.h>
#include <windows.h>

#include <iphlpapi.h>
#include <icmpapi.h>

#endif

#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "ws2_32.lib")


NetworkPing::NetworkPing(QObject *parent)
    : QObject(parent)
{
}

void NetworkPing::checkOnline(const QStringList &deviceIds,
                              const QString &ip,
                              quint16 tcpPort)
{
    if (m_quit) {
        return;
    }
    bool online = false;
    if (tcpPort) {
        QTcpSocket socket;
        socket.setProxy(QNetworkProxy::NoProxy);
        socket.connectToHost(ip, tcpPort);
        online = socket.waitForConnected(1000);
        socket.abort();
    } else {
        online = ping(ip, 1000);
    }

    for (const QString& deviceId : deviceIds) {
		emit onlineChecked(deviceId, online);
    }
}

void NetworkPing::quit()
{
    m_quit = true;
}

QString NetworkPing::resolveIPv4(const QString& host)
{
    // ---------------------------------------------------------
    // 1. 本身就是 IPv4
    // ---------------------------------------------------------
    QHostAddress address;

    if (address.setAddress(host) &&
        address.protocol() == QAbstractSocket::IPv4Protocol)
    {
        return address.toString();
    }

    // ---------------------------------------------------------
    // 2. 主机名解析
    // ---------------------------------------------------------
    const QHostInfo info = QHostInfo::fromName(host);

    if (info.error() != QHostInfo::NoError)
        return {};

    for (const QHostAddress& addr : info.addresses())
    {
        if (addr.protocol() == QAbstractSocket::IPv4Protocol)
            return addr.toString();
    }

    return {};
}


bool NetworkPing::ping(const QString& host, quint32 timeoutMs)
{
#ifndef Q_OS_WIN
    Q_UNUSED(host)
    Q_UNUSED(timeoutMs)
    return false;
#else
    const QString ipv4 = resolveIPv4(host);
    if (ipv4.isEmpty())
        return false;

    bool ok = false;
    const quint32 ipv4Address = QHostAddress(ipv4).toIPv4Address(&ok);
    if (!ok)
        return false;

    const HANDLE icmpHandle = ::IcmpCreateFile();
    if (icmpHandle == INVALID_HANDLE_VALUE)
        return false;

    static constexpr char payload[] = "NetworkPing";
    constexpr WORD payloadSize = static_cast<WORD>(sizeof(payload) - 1);
    QByteArray replyBuffer;
    replyBuffer.resize(static_cast<int>(sizeof(ICMP_ECHO_REPLY) + payloadSize + 64));
    const DWORD replyCount = ::IcmpSendEcho(icmpHandle,
                                            static_cast<IPAddr>(htonl(ipv4Address)),
                                            const_cast<char *>(payload),
                                            payloadSize,
                                            nullptr,
                                            replyBuffer.data(),
                                            static_cast<DWORD>(replyBuffer.size()),
                                            timeoutMs);
    const bool success = replyCount > 0
        && reinterpret_cast<const ICMP_ECHO_REPLY *>(replyBuffer.constData())->Status == IP_SUCCESS;
    ::IcmpCloseHandle(icmpHandle);
    return success;
#endif
}
