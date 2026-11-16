#include "runtime/video/TimelineThumbnailProvider.h"

#include <QElapsedTimer>
#include <QThread>

#include "avreader/avreader.h"
#include "pixeltool/avframefactory.h"
#include "runtime/LogMacros.h"
#include "runtime/TimelineMediaCache.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/mathematics.h>
}

bool probeTimelineVideo(const QString &path, TimelineVideoInfo &info, std::atomic_bool &interrupted)
{
    info = {};
    AVFormatContext *format = avformat_alloc_context();
    if (!format)
        return false;

    format->interrupt_callback.callback = [](void *opaque) -> int {
        return static_cast<std::atomic_bool *>(opaque)->load();
    };
    format->interrupt_callback.opaque = &interrupted;
    const QByteArray source = path.toUtf8();
    const AVCodec *codec = nullptr;
    const int streamIndex = avformat_open_input(&format, source.constData(), nullptr, nullptr) >= 0
        && avformat_find_stream_info(format, nullptr) >= 0
        ? av_find_best_stream(format, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0) : -1;
    if (streamIndex >= 0) {
        AVStream *stream = format->streams[streamIndex];
        constexpr AVRational millisecondsTimeBase{1, 1000};
        if (stream->duration > 0)
            info.durationMs = av_rescale_q(stream->duration, stream->time_base, millisecondsTimeBase);
        else if (format->duration > 0)
            info.durationMs = av_rescale_q(format->duration, AV_TIME_BASE_Q, millisecondsTimeBase);

        if (stream->start_time != AV_NOPTS_VALUE)
            info.videoStartSeconds = stream->start_time * av_q2d(stream->time_base);
        if (format->start_time != AV_NOPTS_VALUE) {
            info.readerStartSeconds = format->start_time * av_q2d(AV_TIME_BASE_Q);
            if (stream->start_time == AV_NOPTS_VALUE)
                info.videoStartSeconds = info.readerStartSeconds;
        } else {
            info.readerStartSeconds = info.videoStartSeconds;
        }
        const AVRational aspect = av_guess_sample_aspect_ratio(format, stream, nullptr);
        info.sampleAspectRatio = QSize(aspect.num, aspect.den);
    }
    avformat_close_input(&format);
    return streamIndex >= 0;
}

void decodeTimelineThumbnails(const QString &path, const TimelineVideoInfo &info,
                              const QVector<qint64> &timesMs, const QSize &pixelSize,
                              std::unique_ptr<AVReader> &reader, const std::atomic_bool &interrupted,
                              const std::function<bool(qint64, const QImage &)> &frameReady)
{
    if (timesMs.isEmpty() || pixelSize.isEmpty() || interrupted)
        return;

    AVReaderOptions options;
    options.avPath = path.toUtf8().toStdString();
    options.hw = true;
    options.outputAudioFrame = false;

    PixelTool::PixelConvProcessor converter;
    for (qint64 timeMs : timesMs) {
        if (interrupted)
            return;
        if (timeMs < 0 || (info.durationMs > 0 && timeMs >= info.durationMs)) {
            if (!frameReady(timeMs, {}))
                return;
            continue;
        }

        // 跳转按容器起点计算，缩略图时间仍以视频流起点为准。
        const double targetSeconds = info.videoStartSeconds + timeMs / 1000.0;
        const double readerTime = qMax(0.0, targetSeconds - info.readerStartSeconds);
        std::unique_ptr<const PixelTool::PixelData> decoded;
        const AVFrame *frame = nullptr;
        // 复用的读线程可能已读到 EOF。在一次失败后重新打开，再定位同一帧。
        for (int attempts = reader ? 2 : 1; attempts > 0; --attempts) {
            if (interrupted)
                return;
            if (reader && reader->isStopped())
                reader.reset();
            if (!reader) {
                reader = std::make_unique<AVReader>();
                if (!reader->open(options)) {
                    reader.reset();
                    if (!interrupted)
                        LOG_ERROR("无法打开缩略图视频" << path);
                    return;
                }
            }
            AVReaderOutputInfo outputInfo;
            if (!reader->getOutputInfo(outputInfo) || !outputInfo.hasVideoData) {
                reader.reset();
                LOG_ERROR("无法读取缩略图视频流" << path);
                return;
            }
            (void)reader->takeVideoPixelData();
            if (reader->seek(readerTime)) {
                QElapsedTimer wait;
                wait.start();
                while (reader->isWorking()) {
                    if (interrupted)
                        return;
                    if (wait.hasExpired(15000)) {
                        reader.reset();
                        LOG_ERROR("等待缩略图视频帧超时" << path << "目标时间(ms)" << timeMs);
                        return;
                    }
                    QThread::msleep(1);
                }
                if (interrupted)
                    return;
                //LOG_INFO("wait working time " << wait.elapsed());
                decoded = reader->takeVideoPixelData();
                const auto *frameData = dynamic_cast<const PixelTool::AVFramePixelData *>(decoded.get());
                frame = frameData ? frameData->getAVFrame() : nullptr;
                if (frame && frame->time_base.num > 0 && frame->time_base.den > 0) {
                    const qint64 pts = frame->pts != AV_NOPTS_VALUE ? frame->pts : frame->best_effort_timestamp;
                    const double frameTime = pts * av_q2d(frame->time_base);
                    const double frameDuration = qMax(0.0, frame->duration * av_q2d(frame->time_base));
                    const double nominalDuration = outputInfo.fps > 0 ? 1.0 / outputInfo.fps : 0.0;
                    const double tolerance = qMax(frameDuration, nominalDuration) + 0.001;
                    if (pts != AV_NOPTS_VALUE && qAbs(frameTime - targetSeconds) <= tolerance)
                        break;
                    if (attempts == 1)
                        LOG_ERROR("缩略图视频帧时间不匹配" << path << "目标时间(ms)" << timeMs
                                  << "实际帧时间(ms)" << (frameTime - info.videoStartSeconds) * 1000);
                } else if (attempts == 1) {
                    LOG_ERROR("未取得缩略图视频帧" << path << "目标时间(ms)" << timeMs);
                }
            } else if (attempts == 1) {
                LOG_ERROR("缩略图视频跳转失败" << path << "目标时间(ms)" << timeMs);
            }
            frame = nullptr;
            decoded.reset();
            reader.reset();
        }
        if (!frame)
            return;

        QSize displaySize(frame->width, frame->height);
        const QSize aspect = info.sampleAspectRatio.isEmpty()
            ? QSize(frame->sample_aspect_ratio.num, frame->sample_aspect_ratio.den) : info.sampleAspectRatio;
        if (!aspect.isEmpty()) {
            const qint64 displayWidth = av_rescale(displaySize.width(), aspect.width(), aspect.height());
            if (displayWidth > 0 && displayWidth <= INT_MAX)
                displaySize.setWidth(static_cast<int>(displayWidth));
        }
        const QSize size = displaySize.scaled(pixelSize, Qt::KeepAspectRatio);
       
        const auto scaled = size.isEmpty() ? nullptr
            : converter.conv(frame, size.width(), size.height(), PixelTool::Pixel_RGBA, 1);
        if (!scaled || !scaled->hasData()) {
            LOG_ERROR("缩放缩略图视频帧失败" << path << "目标时间(ms)" << timeMs);
            return;
        }
        const AVFrame *pixels = scaled->getAVFrame();
        const QImage image(scaled->getYData(), pixels->width, pixels->height, pixels->linesize[0],
                           QImage::Format_RGBA8888);
        if (interrupted || !frameReady(timeMs, image.copy()))
            return;
    }
}

TimelineThumbnailProvider::TimelineThumbnailProvider(TimelineMediaCache *cache)
    : QQuickImageProvider(QQuickImageProvider::Image)
    , m_cache(cache)
{
}

QImage TimelineThumbnailProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    const QImage image = m_cache->thumbnailImage(id);
    if (size)
        *size = image.size();
    if (!image.isNull() && !requestedSize.isEmpty() && requestedSize != image.size())
        return image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    return image;
}
