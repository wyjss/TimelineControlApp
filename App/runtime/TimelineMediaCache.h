#pragma once

#include <QCache>
#include <QImage>
#include <QMutex>
#include <QObject>
#include <QSet>
#include <QThread>
#include <QUrl>
#include <QVariantList>

class TimelineMediaCacheWorker;

class TimelineMediaCache final : public QObject
{
    Q_OBJECT

public:
    explicit TimelineMediaCache(const QString &cacheDirectory, QObject *parent = nullptr);
    ~TimelineMediaCache() override;

    //! source 接受本地文件路径或现有的 $音频文件名。缓存命中也异步回传。
    Q_INVOKABLE quint64 requestWaveform(const QString &source);
    //! 返回 width 列，每列按声道排列，每声道为最小值、最大值，includeRms 时附加均方根。
    //! loop 为 true 时按素材时长回绕，查询范围使用含起播偏移的素材时间。
    //! combineChannels 为 true 时每列合并所有声道的极值和能量。
    Q_INVOKABLE quint64 requestWaveformColumns(const QString &version, qint64 startMs, qint64 endMs,
                                              int width, bool loop = false, bool combineChannels = false,
                                              bool includeRms = false);
    //! 素材校验成功后返回可供多个视口复用的版本。
    Q_INVOKABLE quint64 requestVideoSource(const QString &source);
    //! samples 的各项包含 slotId、sourceTimeMs 和可选的 loop。
    Q_INVOKABLE quint64 requestVideoThumbnails(const QString &version, const QVariantList &samples,
                                              const QSize &pixelSize);
    Q_INVOKABLE void cancel(quint64 requestId);
    QImage thumbnailImage(const QString &key) const;
    void setPlaybackRunning(bool running);

signals:
    void waveformReady(quint64 requestId, const QString &version, qint64 durationMs, int channelCount);
    void waveformColumnsReady(quint64 requestId, const QString &version, const QVariantList &peaks);
    void waveformInvalidated(const QString &version);
    void videoSourceReady(quint64 requestId, const QString &version, qint64 durationMs);
    void videoSourceInvalidated(const QString &version);
    //! 空 URL 表示对应时间点无法生成缩略图。
    void thumbnailReady(quint64 requestId, const QString &slotId, const QUrl &imageUrl);
    void failed(quint64 requestId, const QString &errorString);

private:
    friend class TimelineMediaCacheWorker;

    mutable QMutex m_thumbnailMutex;
    mutable QCache<QString, QImage> m_thumbnails;
    QThread m_thread;
    TimelineMediaCacheWorker *m_worker;
    quint64 m_nextRequestId = 0;
    QSet<quint64> m_pendingRequests;
};
