#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QPointer>
#include <QString>

#include <atomic>
#include <functional>
#include <memory>
#include <thread>


class TimelineRuntime;

namespace httplib {
class Request;
class Response;
class Server;
}


// 提供节目查看与播控 HTTP 接口，并托管网页静态资源。
class WebControlServer final
{
public:
    WebControlServer(TimelineRuntime *runtime, const QString &webRoot);
    ~WebControlServer();

    bool start(const QString &host = QStringLiteral("127.0.0.1"), quint16 port = 8080);
    void stop();
    bool isRunning() const;

    void setAccessToken(const QString &accessToken);

private:
    bool authorize(const httplib::Request &request, httplib::Response &response) const;
    bool invokeRuntime(const std::function<void(TimelineRuntime *)> &operation) const;
    bool serveAsset(const QString &relativePath,
                    const char *contentType,
                    httplib::Response &response) const;
    QJsonObject statusSnapshot() const;
    int updateQueue(const QJsonArray &timelineIds, QJsonObject &response) const;
    int updatePlaybackDevices(const QJsonArray &deviceIds, QJsonObject &response) const;
    int control(const QJsonObject &request, QJsonObject &response) const;

    QPointer<TimelineRuntime> m_runtime;
    QString m_webRoot;
    QString m_accessToken;
    std::unique_ptr<httplib::Server> m_server;
    std::thread m_thread;
    std::atomic_bool m_running{false};
};
