#include "runtime/video/FfmpegVideoFrameItem.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/error.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

namespace TimelineControl {
namespace {

QString avErrorText(int errorCode)
{
    char buffer[AV_ERROR_MAX_STRING_SIZE] = {};
    av_strerror(errorCode, buffer, sizeof(buffer));
    return QString::fromLocal8Bit(buffer);
}

qint64 toMilliseconds(qint64 timestamp, AVRational timeBase)
{
    if (timestamp == AV_NOPTS_VALUE)
        return 0;

    return static_cast<qint64>(av_q2d(timeBase) * static_cast<double>(timestamp) * 1000.0);
}

} // namespace

FfmpegVideoFrameItem::FfmpegVideoFrameItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(false);
    setFillColor(Qt::black);
    connect(&m_timer, &QTimer::timeout, this, &FfmpegVideoFrameItem::advanceFrame);
    m_timer.setInterval(10);
}

FfmpegVideoFrameItem::~FfmpegVideoFrameItem()
{
    closeDecoder();
}

QUrl FfmpegVideoFrameItem::source() const
{
    return m_source;
}

void FfmpegVideoFrameItem::setSource(const QUrl &source)
{
    if (m_source == source)
        return;

    m_source = source;
    emit sourceChanged();
    closeDecoder();
    setPositionValue(0);
    setDurationValue(0);
    setVideoSizeValue(QSize());
    setErrorString(QString());
    setHasFrame(false);
    update();

    if (!m_source.isEmpty())
        openCurrentSource();
}

bool FfmpegVideoFrameItem::isPlaying() const
{
    return m_playing;
}

qint64 FfmpegVideoFrameItem::position() const
{
    return m_positionMs;
}

qint64 FfmpegVideoFrameItem::duration() const
{
    return m_durationMs;
}

QSize FfmpegVideoFrameItem::videoSize() const
{
    return m_videoSize;
}

QString FfmpegVideoFrameItem::errorString() const
{
    return m_errorString;
}

bool FfmpegVideoFrameItem::hasFrame() const
{
    return m_hasFrame;
}

void FfmpegVideoFrameItem::play()
{
    if (m_source.isEmpty())
        return;

    if (!m_formatContext && !openCurrentSource())
        return;

    if (m_endOfFile && m_durationMs > 0 && m_positionMs >= m_durationMs)
        seek(0);

    m_playStartPositionMs = m_positionMs;
    m_playClock.restart();
    setPlaying(true);
    m_timer.start();
    advanceFrame();
}

void FfmpegVideoFrameItem::pause()
{
    setPlaying(false);
    m_timer.stop();
}

void FfmpegVideoFrameItem::stop()
{
    pause();
    seek(0);
}

void FfmpegVideoFrameItem::seek(qint64 positionMs)
{
    if (!m_formatContext || m_videoStreamIndex < 0)
        return;

    const qint64 clampedPosition = qBound<qint64>(0, positionMs, m_durationMs > 0 ? m_durationMs : positionMs);
    AVStream *stream = m_formatContext->streams[m_videoStreamIndex];
    const qint64 timestamp = static_cast<qint64>(
        static_cast<double>(clampedPosition) / 1000.0 / av_q2d(stream->time_base));
    const int result = av_seek_frame(m_formatContext, m_videoStreamIndex, timestamp, AVSEEK_FLAG_BACKWARD);
    if (result < 0) {
        setErrorString(avErrorText(result));
        return;
    }

    avcodec_flush_buffers(m_codecContext);
    m_endOfFile = false;
    setPositionValue(clampedPosition);
    m_playStartPositionMs = clampedPosition;
    m_playClock.restart();

    decodeNextFrame();
}

void FfmpegVideoFrameItem::paint(QPainter *painter)
{
    painter->fillRect(boundingRect(), Qt::black);

    if (m_frameImage.isNull())
        return;

    painter->drawImage(boundingRect(), m_frameImage);
}

void FfmpegVideoFrameItem::advanceFrame()
{
    if (!m_formatContext)
        return;

    const qint64 targetPosition = m_playing
        ? m_playStartPositionMs + m_playClock.elapsed()
        : m_positionMs;

    bool decoded = false;
    while (!m_endOfFile && (m_positionMs <= targetPosition || !m_hasFrame)) {
        decoded = decodeNextFrame() || decoded;
        if (!decoded && m_endOfFile)
            break;
    }

    if (m_durationMs > 0 && targetPosition >= m_durationMs && m_endOfFile) {
        setPositionValue(m_durationMs);
        pause();
    }
}

bool FfmpegVideoFrameItem::openCurrentSource()
{
    closeDecoder();
    setErrorString(QString());

    const QString path = sourcePath();
    if (path.isEmpty()) {
        setErrorString(tr("Video source is empty."));
        return false;
    }

    QByteArray encodedPath = QFile::encodeName(path);
    AVFormatContext *formatContext = nullptr;
    int result = avformat_open_input(&formatContext, encodedPath.constData(), nullptr, nullptr);
    if (result < 0) {
        setErrorString(avErrorText(result));
        return false;
    }

    m_formatContext = formatContext;
    result = avformat_find_stream_info(m_formatContext, nullptr);
    if (result < 0) {
        setErrorString(avErrorText(result));
        closeDecoder();
        return false;
    }

    result = av_find_best_stream(m_formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, nullptr, 0);
    if (result < 0) {
        setErrorString(tr("No video stream found."));
        closeDecoder();
        return false;
    }

    m_videoStreamIndex = result;
    AVStream *stream = m_formatContext->streams[m_videoStreamIndex];
    const AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec) {
        setErrorString(tr("No decoder found for this video stream."));
        closeDecoder();
        return false;
    }

    m_codecContext = avcodec_alloc_context3(codec);
    if (!m_codecContext) {
        setErrorString(tr("Failed to allocate video decoder."));
        closeDecoder();
        return false;
    }

    result = avcodec_parameters_to_context(m_codecContext, stream->codecpar);
    if (result < 0) {
        setErrorString(avErrorText(result));
        closeDecoder();
        return false;
    }

    result = avcodec_open2(m_codecContext, codec, nullptr);
    if (result < 0) {
        setErrorString(avErrorText(result));
        closeDecoder();
        return false;
    }

    m_frame = av_frame_alloc();
    m_packet = av_packet_alloc();
    if (!m_frame || !m_packet) {
        setErrorString(tr("Failed to allocate video frame buffers."));
        closeDecoder();
        return false;
    }

    setVideoSizeValue(QSize(m_codecContext->width, m_codecContext->height));
    setDurationValue(streamDurationMs());
    setPositionValue(0);
    m_endOfFile = false;

    decodeNextFrame();
    return true;
}

void FfmpegVideoFrameItem::closeDecoder()
{
    m_timer.stop();
    setPlaying(false);

    if (m_swsContext) {
        sws_freeContext(m_swsContext);
        m_swsContext = nullptr;
    }

    if (m_packet) {
        av_packet_free(&m_packet);
        m_packet = nullptr;
    }

    if (m_frame) {
        av_frame_free(&m_frame);
        m_frame = nullptr;
    }

    if (m_codecContext) {
        avcodec_free_context(&m_codecContext);
        m_codecContext = nullptr;
    }

    if (m_formatContext) {
        avformat_close_input(&m_formatContext);
        m_formatContext = nullptr;
    }

    m_videoStreamIndex = -1;
    m_endOfFile = false;
    m_frameImage = QImage();
}

void FfmpegVideoFrameItem::setPlaying(bool playing)
{
    if (m_playing == playing)
        return;

    m_playing = playing;
    emit playingChanged();
}

void FfmpegVideoFrameItem::setPositionValue(qint64 positionMs)
{
    const qint64 normalizedPosition = qMax<qint64>(0, positionMs);
    if (m_positionMs == normalizedPosition)
        return;

    m_positionMs = normalizedPosition;
    emit positionChanged();
}

void FfmpegVideoFrameItem::setDurationValue(qint64 durationMs)
{
    const qint64 normalizedDuration = qMax<qint64>(0, durationMs);
    if (m_durationMs == normalizedDuration)
        return;

    m_durationMs = normalizedDuration;
    emit durationChanged();
}

void FfmpegVideoFrameItem::setVideoSizeValue(const QSize &size)
{
    if (m_videoSize == size)
        return;

    m_videoSize = size;
    emit videoSizeChanged();
}

void FfmpegVideoFrameItem::setErrorString(const QString &errorString)
{
    if (m_errorString == errorString)
        return;

    m_errorString = errorString;
    emit errorStringChanged();
}

void FfmpegVideoFrameItem::setHasFrame(bool hasFrame)
{
    if (m_hasFrame == hasFrame)
        return;

    m_hasFrame = hasFrame;
    emit hasFrameChanged();
}

bool FfmpegVideoFrameItem::decodeNextFrame()
{
    if (!m_formatContext || !m_codecContext || !m_frame || !m_packet || m_endOfFile)
        return false;

    while (true) {
        int result = av_read_frame(m_formatContext, m_packet);
        if (result == AVERROR_EOF) {
            avcodec_send_packet(m_codecContext, nullptr);
            m_endOfFile = true;
        } else if (result < 0) {
            setErrorString(avErrorText(result));
            return false;
        } else if (m_packet->stream_index == m_videoStreamIndex) {
            result = avcodec_send_packet(m_codecContext, m_packet);
            av_packet_unref(m_packet);
            if (result < 0 && result != AVERROR(EAGAIN)) {
                setErrorString(avErrorText(result));
                return false;
            }
        } else {
            av_packet_unref(m_packet);
            continue;
        }

        while (true) {
            result = avcodec_receive_frame(m_codecContext, m_frame);
            if (result == AVERROR(EAGAIN))
                break;
            if (result == AVERROR_EOF) {
                m_endOfFile = true;
                return false;
            }
            if (result < 0) {
                setErrorString(avErrorText(result));
                return false;
            }

            const qint64 currentFramePosition = framePositionMs();
            if (convertCurrentFrame(currentFramePosition))
                return true;
        }

        if (m_endOfFile)
            return false;
    }
}

bool FfmpegVideoFrameItem::convertCurrentFrame(qint64 framePositionMs)
{
    if (!m_frame || !m_codecContext || m_codecContext->width <= 0 || m_codecContext->height <= 0)
        return false;

    QImage image(m_codecContext->width, m_codecContext->height, QImage::Format_RGB32);
    if (image.isNull()) {
        setErrorString(tr("Failed to allocate image buffer."));
        return false;
    }

    m_swsContext = sws_getCachedContext(m_swsContext,
                                        m_codecContext->width,
                                        m_codecContext->height,
                                        m_codecContext->pix_fmt,
                                        image.width(),
                                        image.height(),
                                        AV_PIX_FMT_BGRA,
                                        SWS_BILINEAR,
                                        nullptr,
                                        nullptr,
                                        nullptr);
    if (!m_swsContext) {
        setErrorString(tr("Failed to create video converter."));
        return false;
    }

    uint8_t *destinationData[4] = { image.bits(), nullptr, nullptr, nullptr };
    int destinationLineSize[4] = { image.bytesPerLine(), 0, 0, 0 };
    sws_scale(m_swsContext,
              m_frame->data,
              m_frame->linesize,
              0,
              m_codecContext->height,
              destinationData,
              destinationLineSize);

    m_frameImage = image;
    setVideoSizeValue(QSize(image.width(), image.height()));
    setPositionValue(framePositionMs);
    setHasFrame(true);
    update();
    return true;
}

qint64 FfmpegVideoFrameItem::framePositionMs() const
{
    if (!m_formatContext || m_videoStreamIndex < 0 || !m_frame)
        return m_positionMs;

    AVStream *stream = m_formatContext->streams[m_videoStreamIndex];
    const qint64 timestamp = m_frame->best_effort_timestamp;
    if (timestamp != AV_NOPTS_VALUE)
        return toMilliseconds(timestamp, stream->time_base);

    if (m_frame->pts != AV_NOPTS_VALUE)
        return toMilliseconds(m_frame->pts, stream->time_base);

    return m_positionMs;
}

qint64 FfmpegVideoFrameItem::streamDurationMs() const
{
    if (!m_formatContext || m_videoStreamIndex < 0)
        return 0;

    AVStream *stream = m_formatContext->streams[m_videoStreamIndex];
    if (stream->duration != AV_NOPTS_VALUE && stream->duration > 0)
        return toMilliseconds(stream->duration, stream->time_base);

    if (m_formatContext->duration != AV_NOPTS_VALUE && m_formatContext->duration > 0)
        return m_formatContext->duration / (AV_TIME_BASE / 1000);

    return 0;
}

QString FfmpegVideoFrameItem::sourcePath() const
{
    if (m_source.isLocalFile())
        return QFileInfo(m_source.toLocalFile()).absoluteFilePath();

    if (m_source.scheme().size() == 1 && !m_source.path().isEmpty()) {
        const QString drivePath = m_source.scheme().toUpper() + QStringLiteral(":") + QDir::toNativeSeparators(m_source.path());
        return QFileInfo(drivePath).absoluteFilePath();
    }

    return m_source.toString(QUrl::PreferLocalFile);
}

} // namespace TimelineControl
