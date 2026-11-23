#include "server/osc/OscControlServer.h"

#include "runtime/timeline/TimelineManager.h"

#define LC "[OSC] "
#include "LogMacros.h"

#include <QNetworkDatagram>
#include <QtEndian>

#include <algorithm>
#include <array>

OscControlServer::OscControlServer(TimelineManager &timelineManager)
    : m_timelineManager(timelineManager)
{
    connect(&m_socket, &QUdpSocket::readyRead, this, &OscControlServer::readPendingDatagrams);
}

void OscControlServer::start(const QHostAddress &address, quint16 port)
{
    if (!m_socket.bind(address, port, QUdpSocket::DontShareAddress)) {
        LOG_WARN("监听失败" << address.toString() << port << m_socket.errorString());
        return;
    }
    LOG_INFO("已监听 UDP" << address.toString() << port);
}

void OscControlServer::readPendingDatagrams()
{
    // 地址和类型标签都是以零结尾并按四字节对齐的 OSC 字符串。
    const QByteArray header = QByteArrayLiteral("/video/cue\0\0,si\0");
    using Action = TimelineManager::PlaybackAction;
    constexpr std::array actions{Action::Stop, Action::Play, Action::Pause, Action::Resume};

    while (m_socket.hasPendingDatagrams()) {
        const QByteArray packet = m_socket.receiveDatagram().data();
        LOG_INFO("recv osc pkt:" << packet);
        if (!packet.startsWith(header))
            continue;

        const int cueEnd = packet.indexOf('\0', header.size());
        if (cueEnd <= header.size())
            continue;

        const int cmdOffset = cueEnd + (4 - cueEnd % 4);
        if (packet.size() != cmdOffset + 4)
            continue;

        const char *data = packet.constData();
        if (!std::all_of(data + cueEnd, data + cmdOffset, [](char byte) { return byte == '\0'; }))
            continue;

        const qint32 cmd = qFromBigEndian<qint32>(data + cmdOffset);
        if (cmd < 0 || cmd >= static_cast<qint32>(actions.size()))
            continue;

        const QByteArray cueBytes = packet.mid(header.size(), cueEnd - header.size());
        const QString cue = QString::fromUtf8(cueBytes);
        if (cue.toUtf8() != cueBytes)
            continue;

        if (!m_timelineManager.controlSinglePlayback(cue, actions[cmd])) {
            LOG_DEBUG("节目名无唯一匹配，或当前状态不接受该指令" << cue << cmd);
        }
    }
}
