#pragma once

#include <QObject>
#include <QStringList>
#include <QVariantList>

class DeviceModel;
class QNetworkAccessManager;
class QNetworkReply;

//! 管理本地资源清单和向 PC 上传的任务，由 TimelineRuntime 持有。
class ResourceSyncManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList resources READ resources NOTIFY resourcesChanged FINAL)
    Q_PROPERTY(QVariantList jobs READ jobs NOTIFY jobsChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged FINAL)

public:
    explicit ResourceSyncManager(DeviceModel *deviceModel, QObject *parent = nullptr);

    QVariantList resources() const;
    QVariantList jobs() const;
    bool busy() const;
    QString errorMessage() const;
    //! 打开同步窗口时重新读取文件大小和可读状态。
    Q_INVOKABLE void refreshResources();
    //! 每个目标接收同一组资源，目标目录沿用现有音视频路径，同名文件覆盖。
    Q_INVOKABLE bool startSync(const QStringList &resourceKeys, const QStringList &deviceIds);
    //! 停止当前上传并取消待执行项，不回滚服务器已经收到的内容。
    Q_INVOKABLE void stopSync();
    Q_INVOKABLE void retryFailed();

signals:
    void resourcesChanged();
    void jobsChanged();
    void busyChanged();
    void errorMessageChanged();

private:
    //! 首次启动、单项结束及重试共用的顺序上传调度。
    void startNextUpload();

    DeviceModel *m_deviceModel = nullptr;
    QNetworkAccessManager *m_network = nullptr;
    QNetworkReply *m_reply = nullptr;
    QVariantList m_resources;
    QVariantList m_jobs;
    int m_currentJobIndex = -1;
    bool m_busy = false;
    QString m_errorMessage;
};

Q_DECLARE_METATYPE(ResourceSyncManager *)
