#pragma once

#include <atomic>
#include <functional>
#include <memory>

#include <QImage>
#include <QQuickImageProvider>
#include <QSize>
#include <QVector>

class AVReader;
class TimelineMediaCache;

struct TimelineVideoInfo
{
    qint64 durationMs = 0;
    double videoStartSeconds = 0;
    double readerStartSeconds = 0;
    QSize sampleAspectRatio;
};

//! 在解码线程探测时长和时间原点。时长未知时 durationMs 为 0。
bool probeTimelineVideo(const QString &path, TimelineVideoInfo &info, std::atomic_bool &interrupted);

//! 同一素材共用一个解码器。回调返回 false 时结束当前批次。
void decodeTimelineThumbnails(const QString &path, const TimelineVideoInfo &info,
                              const QVector<qint64> &timesMs, const QSize &pixelSize,
                              std::unique_ptr<AVReader> &reader, const std::atomic_bool &interrupted,
                              const std::function<bool(qint64, const QImage &)> &frameReady);

class TimelineThumbnailProvider final : public QQuickImageProvider
{
public:
    explicit TimelineThumbnailProvider(TimelineMediaCache *cache);
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    TimelineMediaCache *const m_cache;
};
