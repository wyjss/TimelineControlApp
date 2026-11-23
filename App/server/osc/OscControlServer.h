#pragma once

#include <QHostAddress>
#include <QObject>
#include <QUdpSocket>

class TimelineManager;

class OscControlServer final : public QObject
{
public:
    explicit OscControlServer(TimelineManager &timelineManager);
    void start(const QHostAddress &address, quint16 port);

private:
    void readPendingDatagrams();

    TimelineManager &m_timelineManager;
    QUdpSocket m_socket;
};
