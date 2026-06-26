#include "runtime/video/FfmpegVideoFrameItem.h"

#include <cmath>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QPainter>

#include "avreader/avreader.h"
#include "pixeltool/avframefactory.h"

namespace TimelineControl {
namespace {

qint64 secondsToMilliseconds(double seconds)
{
    if (!std::isfinite(seconds) || seconds <= 0.0)
        return 0;

    return static_cast<qint64>(std::llround(seconds * 1000.0));
}

std::string readerPathFromQString(const QString &path)
{
    const QByteArray encodedPath = QFile::encodeName(path);
    return std::string(encodedPath.constData(), static_cast<size_t>(encodedPath.size()));
}

} // namespace

FfmpegVideoFrameItem::FfmpegVideoFrameItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
    , m_converter(std::make_unique<PixelTool::PixelConvProcessor>())
{
    setAntialiasing(false);
    setFillColor(Qt::black);
    connect(&m_timer, &QTimer::timeout, this, &FfmpegVideoFrameItem::advanceFrame);
    m_timer.setInterval(16);
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

    if ((!m_reader || !m_reader->isRunning()) && !openCurrentSource())
        return;

    if (m_durationMs > 0 && m_positionMs >= m_durationMs)
        seek(0);

    if (!m_reader || !m_reader->play()) {
        setErrorString(tr("Failed to start AVReader playback."));
        return;
    }

    setPlaying(true);
    m_timer.start();
    advanceFrame();
}

void FfmpegVideoFrameItem::pause()
{
    if (m_reader)
        m_reader->pause();

    setPlaying(false);
    if (!m_pendingFrame)
        m_timer.stop();
}

void FfmpegVideoFrameItem::stop()
{
    pause();
    seek(0);
}

void FfmpegVideoFrameItem::seek(qint64 positionMs)
{
    if (m_source.isEmpty())
        return;

    if ((!m_reader || !m_reader->isRunning()) && !openCurrentSource())
        return;

    const qint64 upperBound = m_durationMs > 0 ? m_durationMs : positionMs;
    const qint64 clampedPosition = qBound<qint64>(0, positionMs, upperBound);
    if (!m_reader->seek(static_cast<double>(clampedPosition) / 1000.0)) {
        setErrorString(tr("Failed to seek AVReader playback."));
        return;
    }

    setPositionValue(clampedPosition);
    m_pendingFrame = true;
    m_timer.start();
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
    if (!m_reader)
        return;

    updateOutputInfo();
    const bool frameUpdated = takeAndConvertFrame();
    updateOutputInfo();

    if (frameUpdated)
        m_pendingFrame = false;

    if (!m_reader->isRunning()) {
        if (m_playing) {
            if (m_durationMs > 0)
                setPositionValue(m_durationMs);
            pause();
        } else if (!m_pendingFrame) {
            m_timer.stop();
        }
        return;
    }

    if (!m_playing && !m_pendingFrame)
        m_timer.stop();
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

    auto reader = std::make_unique<AVReader>();
    AVReaderOptions options;
    options.avPath = readerPathFromQString(path);
    options.hw = true;
    options.loop = false;
    options.outputVideoFrame = true;
    options.outputAudioFrame = false;

    if (!reader->open(options)) {
        setErrorString(tr("Failed to open video source with AVReader."));
        return false;
    }

    m_reader = std::move(reader);
    updateOutputInfo();
    m_pendingFrame = false;
    return true;
}

void FfmpegVideoFrameItem::closeDecoder()
{
    m_timer.stop();
    setPlaying(false);
    m_pendingFrame = false;

    if (m_reader) {
        m_reader->quit();
        m_reader.reset();
    }

    if (m_converter)
        m_converter->clear();

    m_frameImage = QImage();
}

bool FfmpegVideoFrameItem::updateOutputInfo()
{
    if (!m_reader)
        return false;

    AVReaderOutputInfo info;
    if (!m_reader->getOutputInfo(info))
        return false;

    setPositionValue(secondsToMilliseconds(info.currentTime));
    setDurationValue(secondsToMilliseconds(info.duration));

    if (info.hasVideoData && info.w > 0 && info.h > 0)
        setVideoSizeValue(QSize(info.w, info.h));

    return true;
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

bool FfmpegVideoFrameItem::takeAndConvertFrame()
{
    if (!m_reader)
        return false;

    PixelTool::AVFramePixelDataPtr frameData = m_reader->takeVideoFrame();
    if (!frameData || !frameData->hasData())
        return false;

    return convertFrame(*frameData, m_positionMs);
}

bool FfmpegVideoFrameItem::convertFrame(const PixelTool::AVFramePixelData &frameData, qint64 framePositionMs)
{
    if (!m_converter || !frameData.hasData())
        return false;

    PixelTool::AVFramePixelDataPtr convertedFrame = m_converter->conv(frameData.getAVFrame(), PixelTool::Pixel_BGRA, 1);
    if (!convertedFrame || !convertedFrame->hasData()) {
        setErrorString(tr("Failed to create video converter."));
        return false;
    }

    const QSize frameSize = convertedFrame->getSize();
    if (frameSize.width() <= 0 || frameSize.height() <= 0)
        return false;

    const QImage image(convertedFrame->getYData(),
                       frameSize.width(),
                       frameSize.height(),
                       frameSize.width() * 4,
                       QImage::Format_RGB32);
    if (image.isNull()) {
        setErrorString(tr("Failed to allocate image buffer."));
        return false;
    }

    m_frameImage = image.copy();
    setVideoSizeValue(frameSize);
    setPositionValue(framePositionMs);
    setHasFrame(true);
    update();
    return true;
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
