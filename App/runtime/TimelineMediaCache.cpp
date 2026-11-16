#include "TimelineMediaCache.h"

#include "audio/AudioWaveformExtractor.h"
#include "avreader/avreader.h"
#include "utils.h"
#include "video/TimelineThumbnailProvider.h"

#include <QCache>
#include <QCryptographicHash>
#include <QDataStream>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QHash>
#include <QImageReader>
#include <QMap>
#include <QQueue>
#include <QSaveFile>
#include <QTemporaryFile>
#include <QTimer>
#include <QUrl>
#include <QUuid>

#include <algorithm>
#include <cmath>
#include <memory>

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <Windows.h>

namespace {

constexpr int readChunkBytes = 1024 * 1024;
constexpr int memoryCacheKiB = 64 * 1024;
constexpr qint64 waveformDiskCacheBytes = 512LL * 1024 * 1024;
constexpr qint64 thumbnailDiskCacheBytes = 64LL * 1024 * 1024;
constexpr int thumbnailCacheBytes = 32 * 1024 * 1024;
constexpr quint32 thumbnailFormat = 1;
// 取帧规则有变化时更新缓存键，PNG 仍由同一目录统一淘汰。
constexpr quint32 thumbnailSamplingVersion = 2;
constexpr quint32 waveformMagic = 0x57415645;
// 修改分桶或文件编码时递增版本，旧文件自然失效。
constexpr quint32 waveformFormat = 2;
constexpr qint64 waveformHeaderBytes = 24;
constexpr qint64 waveformPeakBytes = 2 * sizeof(float) + sizeof(double) + sizeof(quint32);

using VideoFileHandle = std::unique_ptr<void, decltype(&CloseHandle)>;

VideoFileHandle openVideoFile(const QString &path, DWORD access, DWORD share)
{
    const QString nativePath = QDir::toNativeSeparators(path);
    HANDLE handle = CreateFileW(reinterpret_cast<LPCWSTR>(nativePath.utf16()), access, share,
                                nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    return VideoFileHandle(handle == INVALID_HANDLE_VALUE ? nullptr : handle, CloseHandle);
}

QByteArray videoFileRevision(HANDLE handle)
{
    BY_HANDLE_FILE_INFORMATION identity{};
    FILE_BASIC_INFO times{};
    if (!handle || !GetFileInformationByHandle(handle, &identity)
        || !GetFileInformationByHandleEx(handle, FileBasicInfo, &times, sizeof(times)))
        return {};

    // 文件身份识别同名替换，变更时间识别改写后恢复修改时间的情况。
    QByteArray revision;
    QDataStream(&revision, QIODevice::WriteOnly)
        << quint32(identity.dwVolumeSerialNumber) << quint32(identity.nFileIndexHigh)
        << quint32(identity.nFileIndexLow) << quint32(identity.nFileSizeHigh)
        << quint32(identity.nFileSizeLow) << qint64(times.ChangeTime.QuadPart)
        << qint64(times.LastWriteTime.QuadPart);
    return revision;
}

struct SourceJob
{
    QString path;
    quint64 generation = 0;
    qint64 size = -1;
    QDateTime modified;
    bool video = false;
    QByteArray videoRevision;

    bool matchesFile() const
    {
        if (video) {
            const auto file = openVideoFile(path, FILE_READ_ATTRIBUTES,
                                            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE);
            return !videoRevision.isEmpty() && videoRevision == videoFileRevision(file.get());
        }
        const QFileInfo info(path);
        return info.isFile() && info.size() == size && info.lastModified() == modified;
    }
};

struct SourceState
{
    quint64 generation = 0;
    QSet<quint64> requests;
    QString version;
    SourceJob verified;
    QByteArray digest;
    TimelineVideoInfo videoInfo;
};

struct VideoFrameSubscriber
{
    quint64 requestId;
    QString slotId;
    QString version;
};

struct VideoFrameJob
{
    qint64 timeMs;
    QSize pixelSize;
    QVector<VideoFrameSubscriber> subscribers;
};

struct FileScan
{
    explicit FileScan(const SourceJob &source)
        : job(source), file(source.path), hash(QCryptographicHash::Sha256)
    {
    }

    SourceJob job;
    QFile file;
    QCryptographicHash hash;
    QByteArray expectedDigest;
    std::unique_ptr<QTemporaryFile> snapshot;
};

} // namespace

class TimelineMediaCacheWorker final : public QObject
{
    Q_OBJECT

public:
    TimelineMediaCacheWorker(const QString &cacheDirectory, TimelineMediaCache *owner)
        : m_cacheDirectory(cacheDirectory.isEmpty() ? QString()
                           : QDir(cacheDirectory).filePath(QStringLiteral("waveform-v%1").arg(waveformFormat)))
        , m_thumbnailDirectory(cacheDirectory.isEmpty() ? QString()
                                : QDir(cacheDirectory).filePath(QStringLiteral("thumbnail-v%1").arg(thumbnailFormat)))
        , m_owner(owner)
        , m_timer(new QTimer(this))
        , m_videoIdleTimer(new QTimer(this))
    {
        m_timer->setSingleShot(true);
        connect(m_timer, &QTimer::timeout, this, &TimelineMediaCacheWorker::process);
        m_videoIdleTimer->setSingleShot(true);
        m_videoIdleTimer->setInterval(1000);
        connect(m_videoIdleTimer, &QTimer::timeout, this, [this]() {
            // Windows 打开的视频在空闲后释放，避免长期占用原文件。
            QMetaObject::invokeMethod(m_videoWorker, [this]() { m_videoReader.reset(); }, Qt::QueuedConnection);
        });
    }

    void requestWaveform(quint64 requestId, const QString &source);
    void requestColumns(quint64 requestId, const QString &version, qint64 startMs, qint64 endMs,
                        int width, bool loop, bool combineChannels, bool includeRms);
    void requestVideoSource(quint64 requestId, const QString &source);
    void requestVideoThumbnails(quint64 requestId, const QString &version, const QVariantList &samples,
                                const QSize &pixelSize);
    void cancel(quint64 requestId);
    void setPlaybackRunning(bool running);
    void shutdown();

signals:
    void waveformReady(quint64 requestId, const QString &version, qint64 durationMs, int channelCount);
    void waveformColumnsReady(quint64 requestId, const QString &version, const QVariantList &peaks);
    void waveformInvalidated(const QString &version);
    void videoSourceReady(quint64 requestId, const QString &version, qint64 durationMs);
    void videoSourceInvalidated(const QString &version);
    void thumbnailReady(quint64 requestId, const QString &slotId, const QUrl &imageUrl);
    void thumbnailsFinished(quint64 requestId);
    void failed(quint64 requestId, const QString &errorString);

private:
    void queueVerification(SourceState &source, const QFileInfo &info, bool video = false);
    void sourceChanged(const QString &path);
    void process();
    void readChunk();
    void finishExtraction();
    void invalidate(SourceState &source);
    SourceState *pending(const SourceJob &job);
    void failSource(const SourceJob &job, const QString &error);
    void publish(const SourceJob &job, const QByteArray &digest, const AudioWaveform &waveform);
    AudioWaveform cachedWaveform(const QByteArray &digest);
    bool storeWaveform(const QByteArray &digest, const AudioWaveform &waveform);

    SourceState *videoSource(const QString &version);
    void invalidateVideo(SourceState &state);
    void processVideoJobs();
    void startVideoWorker(std::function<void()> work);
    void discardUnusedVideoFrames();
    void deliverThumbnail(quint64 requestId, const QString &slotId, const QUrl &imageUrl);
    void finishVideoFrame(const QString &key, const QImage &image);
    QImage cachedThumbnail(const QString &key, const QSize &pixelSize);
    void storeThumbnail(const QString &key, const QImage &image, bool persist);

    const QString m_cacheDirectory;
    const QString m_thumbnailDirectory;
    TimelineMediaCache *m_owner;
    QTimer *m_timer;
    QTimer *m_videoIdleTimer;
    QFileSystemWatcher *m_watcher = nullptr;
    bool m_playbackRunning = false;
    bool m_shuttingDown = false;
    quint64 m_generation = 0;
    QHash<QString, SourceState> m_sources;
    QQueue<SourceJob> m_hashQueue;
    QHash<QByteArray, QVector<SourceJob>> m_decodeJobs;
    QQueue<QByteArray> m_decodeQueue;
    QCache<QByteArray, AudioWaveform> m_waveforms{memoryCacheKiB};
    std::unique_ptr<FileScan> m_scan;

    AudioWaveformExtractor *m_extractor = nullptr;
    std::unique_ptr<QTemporaryFile> m_snapshot;
    QByteArray m_extractingDigest;
    AudioWaveform m_extracted;
    QString m_extractionError;
    bool m_retryExtraction = false;

    QHash<QString, SourceState> m_videoSources;
    QQueue<SourceJob> m_videoProbes;
    QHash<quint64, int> m_videoRequests;
    QHash<QString, VideoFrameJob> m_videoFrames;
    QQueue<QString> m_videoQueue;
    QSet<QString> m_activeVideoFrames;
    QObject *m_videoWorker = nullptr;
    bool m_videoBusy = false;
    std::atomic_bool m_videoInterrupted{false};
    // 仅在视频线程访问，确保 AVReader 在同一线程创建和销毁。
    std::unique_ptr<AVReader> m_videoReader;
    SourceJob m_videoReaderSource;
    qint64 m_thumbnailDiskUsage = -1;
};

void TimelineMediaCacheWorker::requestWaveform(quint64 requestId, const QString &source)
{
    QString localPath = Utils::getAudioRealSource(source);
    if (localPath.startsWith(QStringLiteral("file:"), Qt::CaseInsensitive))
        localPath = QUrl(localPath).toLocalFile();
    const QFileInfo info(localPath);
    const QString path = info.isFile() ? info.absoluteFilePath() : QString();
    if (path.isEmpty()) {
        emit failed(requestId, tr("找不到本地音频文件：%1").arg(source));
        return;
    }

    auto &state = m_sources[path];
    if (!state.version.isEmpty() && !state.verified.matchesFile())
        invalidate(state);
    if (m_playbackRunning && !state.version.isEmpty() && m_watcher->files().contains(path)) {
        const AudioWaveform waveform = cachedWaveform(state.digest);
        if (waveform.channelCount > 0) {
            emit waveformReady(requestId, state.version, waveform.durationMs, waveform.channelCount);
            return;
        }
    }

    if (state.requests.isEmpty())
        queueVerification(state, info);
    state.requests.insert(requestId);
}

void TimelineMediaCacheWorker::queueVerification(SourceState &source, const QFileInfo &info, bool video)
{
    if (!m_watcher) {
        // Windows 的原生事件过滤器需要在同一线程注册和移除。
        m_watcher = new QFileSystemWatcher(this);
        connect(m_watcher, &QFileSystemWatcher::fileChanged, this, &TimelineMediaCacheWorker::sourceChanged);
    }
    const QString path = info.absoluteFilePath();
    source.generation = ++m_generation;
    if (!m_watcher->files().contains(path))
        m_watcher->addPath(path);
    if (video) {
        m_videoProbes.enqueue({path, source.generation, -1, {}, true});
        processVideoJobs();
    } else {
        m_hashQueue.enqueue({path, source.generation, info.size(), info.lastModified()});
        if (!m_playbackRunning && !m_timer->isActive())
            m_timer->start(0);
    }
}

void TimelineMediaCacheWorker::sourceChanged(const QString &path)
{
    auto video = m_videoSources.find(path);
    if (video != m_videoSources.end()) {
        invalidateVideo(video.value());
        if (!video->requests.isEmpty()) {
            const QFileInfo info(path);
            if (info.isFile())
                queueVerification(video.value(), info, true);
            else
                failSource({path, video->generation, -1, {}, true}, tr("视频文件已被移除。"));
        }
    }
    auto it = m_sources.find(path);
    if (it == m_sources.end())
        return;
    invalidate(it.value());
    if (it->requests.isEmpty())
        return;
    const QFileInfo info(path);
    if (info.isFile()) {
        // 监听事件可能晚于新请求。把现有请求转到新一轮校验，旧结果按代数丢弃。
        queueVerification(it.value(), info);
    } else {
        failSource({path, it->generation, -1, {}}, tr("音频文件已被移除。"));
    }
}

void TimelineMediaCacheWorker::requestColumns(quint64 requestId, const QString &version, qint64 startMs,
                                              qint64 endMs, int width, bool loop, bool combineChannels,
                                              bool includeRms)
{
    if (version.isEmpty() || startMs < 0 || endMs <= startMs || width <= 0) {
        emit failed(requestId, tr("波形查询范围无效。"));
        return;
    }
    const auto state = std::find_if(m_sources.begin(), m_sources.end(), [&version](const SourceState &entry) {
        return entry.version == version;
    });
    if (state == m_sources.end() || !state->verified.matchesFile()) {
        if (state != m_sources.end())
            sourceChanged(state.key());
        emit failed(requestId, tr("波形素材版本已失效，请重新请求。"));
        return;
    }

    const AudioWaveform waveform = cachedWaveform(state->digest);
    const int channels = waveform.channelCount;
    if (channels <= 0) {
        invalidate(state.value());
        emit failed(requestId, tr("波形已从缓存移除，请重新请求。"));
        return;
    }
    // 限制单次回传大小，避免错误的视口参数在界面线程堆积数据。
    if (qint64(width) * channels > 256 * 1024) {
        emit failed(requestId, tr("波形查询列数过多。"));
        return;
    }

    const int bucketCount = waveform.peaks.size() / channels;
    const int bucketMs = AudioWaveform::bucketDurationMs;
    const qint64 duration = waveform.durationMs;
    const qint64 span = endMs - startMs;
    const qint64 step = span / width;
    const qint64 stepRemainder = span % width;
    const qint64 fullCycles = loop ? step / duration : 0;
    const double loopRemainderMs = loop ? step % duration + double(stepRemainder) / width : 0.0;
    const int outputChannels = combineChannels ? 1 : channels;
    const auto mergePeaks = [&waveform, outputChannels](AudioWaveform::Peak &peak, int first, int afterLast) {
        // 合并时连续读取所有声道；独立显示时跨时间桶读取同一声道。
        for (int index = first; index < afterLast; index += outputChannels) {
            const auto &sample = waveform.peaks[index];
            peak.minimum = std::min(peak.minimum, sample.minimum);
            peak.maximum = std::max(peak.maximum, sample.maximum);
        }
    };

    struct Energy
    {
        double sumSquares = 0.0;
        double sampleCount = 0.0;
    };
    const auto mergeEnergy = [&](Energy &energy, int channel, double start, double end) {
        if (end <= start)
            return;
        const int first = int(start / bucketMs);
        const int afterLast = std::min(bucketCount, int(std::ceil(end / bucketMs)));
        for (int bucket = first; bucket < afterLast; ++bucket) {
            const double bucketStart = qint64(bucket) * bucketMs;
            const double bucketEnd = std::min(bucketStart + bucketMs, double(duration));
            // 部分重叠的时间桶按重叠比例计入方和及样本数。
            const double weight = (std::min(end, bucketEnd) - std::max(start, bucketStart))
                / (bucketEnd - bucketStart);
            const int bucketEndIndex = (bucket + 1) * channels;
            for (int index = bucket * channels + channel; index < bucketEndIndex; index += outputChannels) {
                const auto &peak = waveform.peaks[index];
                energy.sumSquares += peak.sumSquares * weight;
                energy.sampleCount += peak.sampleCount * weight;
            }
        }
    };

    QVector<AudioWaveform::Peak> wholeSource;
    QVector<Energy> wholeEnergy;
    if (fullCycles > 0) {
        // 完整周期共享同一组峰值和能量，逐列只需计算不足一周期的余量。
        wholeSource.resize(outputChannels);
        if (includeRms)
            wholeEnergy.resize(outputChannels);
        for (int channel = 0; channel < outputChannels; ++channel) {
            auto &peak = wholeSource[channel];
            peak = waveform.peaks[channel];
            mergePeaks(peak, channel + outputChannels, waveform.peaks.size());
            if (includeRms)
                mergeEnergy(wholeEnergy[channel], channel, 0.0, double(duration));
        }
    }

    qint64 left = startMs;
    qint64 remainder = 0;
    QVariantList peaks;
    peaks.reserve(width * outputChannels * (includeRms ? 3 : 2));
    for (int column = 0; column < width; ++column) {
        // 保留像素边界的亚毫秒余量，避免浮点舍入跨进相邻时间桶。
        const qint64 leftRemainder = remainder;
        remainder += stepRemainder;
        const qint64 right = left + step + remainder / width;
        remainder %= width;
        const bool wraps = loop && left / duration != right / duration;
        const qint64 sourceLeft = loop ? left % duration : left;
        const qint64 sourceRight = loop ? right % duration : std::min(right, duration);
        const bool partialBucket = sourceRight % bucketMs != 0
            || ((loop || right < duration) && remainder > 0);
        const int first = int(std::min<qint64>(bucketCount, sourceLeft / bucketMs));
        const int afterRight = int(std::min<qint64>(bucketCount, sourceRight / bucketMs + partialBucket));
        const int afterLast = wraps ? bucketCount : afterRight;
        for (int channel = 0; channel < outputChannels; ++channel) {
            AudioWaveform::Peak peak;
            if (fullCycles > 0) {
                peak = wholeSource[channel];
            } else if (sourceLeft < duration && first < afterLast) {
                const int firstPeak = first * channels + channel;
                peak = waveform.peaks[firstPeak];
                mergePeaks(peak, firstPeak + outputChannels, afterLast * channels);
                if (wraps)
                    mergePeaks(peak, channel, afterRight * channels);
            }
            peaks.append(peak.minimum);
            peaks.append(peak.maximum);
            if (includeRms) {
                Energy energy;
                if (fullCycles > 0) {
                    energy.sumSquares = wholeEnergy[channel].sumSquares * fullCycles;
                    energy.sampleCount = wholeEnergy[channel].sampleCount * fullCycles;
                }
                if (sourceLeft < duration) {
                    const double energyStart = sourceLeft + double(leftRemainder) / width;
                    const double energyEnd = loop ? energyStart + loopRemainderMs
                                                  : sourceRight + (right < duration ? double(remainder) / width : 0.0);
                    mergeEnergy(energy, channel, energyStart, std::min(energyEnd, double(duration)));
                    if (loop && energyEnd > duration)
                        mergeEnergy(energy, channel, 0.0, energyEnd - duration);
                }
                peaks.append(energy.sampleCount > 0.0 ? std::sqrt(energy.sumSquares / energy.sampleCount) : 0.0);
            }
        }
        left = right;
    }
    emit waveformColumnsReady(requestId, version, peaks);
}

void TimelineMediaCacheWorker::process()
{
    if (m_shuttingDown || m_playbackRunning)
        return;
    if (m_scan) {
        readChunk();
        return;
    }

    // 冷缓存才复制快照。哈希命中时只读取原文件，不生成临时副本。
    while (!m_extractor && !m_decodeQueue.isEmpty()) {
        const QByteArray digest = m_decodeQueue.dequeue();
        auto job = m_decodeJobs.find(digest);
        if (job == m_decodeJobs.end())
            continue;
        auto &sources = job.value();
        while (!sources.isEmpty()) {
            const SourceJob source = sources.first();
            if (!pending(source)) {
                sources.removeFirst();
                continue;
            }
            auto scan = std::make_unique<FileScan>(source);
            scan->snapshot = std::make_unique<QTemporaryFile>(QDir::temp().filePath(
                QStringLiteral("timeline-media-XXXXXX.") + QFileInfo(source.path).suffix()));
            if (!source.matchesFile()) {
                sourceChanged(source.path);
                sources.removeFirst();
                continue;
            }
            if (!scan->file.open(QIODevice::ReadOnly) || !scan->snapshot->open()) {
                failSource(source, tr("无法为音频创建解码快照：%1").arg(source.path));
                sources.removeFirst();
                continue;
            }
            scan->expectedDigest = digest;
            m_scan = std::move(scan);
            m_timer->start(0);
            return;
        }
        m_decodeJobs.erase(job);
    }

    while (!m_hashQueue.isEmpty()) {
        const SourceJob source = m_hashQueue.dequeue();
        if (!pending(source))
            continue;
        auto scan = std::make_unique<FileScan>(source);
        if (!source.matchesFile()) {
            sourceChanged(source.path);
            m_timer->start(0);
            return;
        }
        if (!scan->file.open(QIODevice::ReadOnly)) {
            failSource(source, tr("无法读取音频文件：%1").arg(source.path));
            continue;
        }
        m_scan = std::move(scan);
        m_timer->start(0);
        return;
    }
}

void TimelineMediaCacheWorker::readChunk()
{
    FileScan &scan = *m_scan;
    const SourceJob source = scan.job;
    const QByteArray expectedDigest = scan.expectedDigest;
    if (auto *state = pending(source)) {
        const QByteArray bytes = scan.file.read(readChunkBytes);
        const bool copied = !scan.snapshot || scan.snapshot->write(bytes) == bytes.size();
        if (scan.file.error() != QFileDevice::NoError || !copied) {
            failSource(source, tr("无法读取或复制音频文件：%1").arg(source.path));
        } else if (!bytes.isEmpty()) {
            scan.hash.addData(bytes);
            m_timer->start(0);
            return;
        } else {
            const QByteArray digest = scan.hash.result();
            if (!source.matchesFile() || (!expectedDigest.isEmpty() && expectedDigest != digest)) {
                sourceChanged(source.path);
            } else if (scan.snapshot) {
                if (!scan.snapshot->flush()) {
                    failSource(source, tr("无法保存音频解码快照：%1").arg(source.path));
                } else {
                    scan.snapshot->close();
                    m_snapshot = std::move(scan.snapshot);
                    m_extractingDigest = digest;
                    m_extracted = {};
                    m_extractionError.clear();
                    m_retryExtraction = false;
                    // 预览只需要峰值，尽快顺序解码。调度器一次只运行一个提取器。
                    m_extractor = new AudioWaveformExtractor(m_snapshot->fileName(), 1024.0, this);
                    connect(m_extractor, &AudioWaveformExtractor::resultReady, this,
                            [this](const AudioWaveform &waveform) { m_extracted = waveform; });
                    connect(m_extractor, &AudioWaveformExtractor::failed, this,
                            [this](const QString &error) { m_extractionError = error; });
                    connect(m_extractor, &QThread::finished, this, &TimelineMediaCacheWorker::finishExtraction);
                    m_extractor->start();
                }
            } else {
                if (state->digest != digest)
                    invalidate(*state);
                const AudioWaveform cached = cachedWaveform(digest);
                if (cached.channelCount > 0) {
                    publish(source, digest, cached);
                } else {
                    auto job = m_decodeJobs.find(digest);
                    if (job == m_decodeJobs.end()) {
                        m_decodeJobs.insert(digest, {source});
                        m_decodeQueue.enqueue(digest);
                    } else {
                        job->append(source);
                    }
                }
            }
        }
    }
    m_scan.reset();
    if (!expectedDigest.isEmpty() && !m_extractor)
        m_decodeQueue.prepend(expectedDigest);
    m_timer->start(0);
}

void TimelineMediaCacheWorker::finishExtraction()
{
    m_extractor->deleteLater();
    m_extractor = nullptr;
    const QString snapshotPath = m_snapshot->fileName();
    m_snapshot.reset();
    const QByteArray digest = std::move(m_extractingDigest);
    if (m_shuttingDown) {
        QThread::currentThread()->quit();
        return;
    }

    if (m_extracted.channelCount > 0 && storeWaveform(digest, m_extracted)) {
        const auto sources = m_decodeJobs.take(digest);
        for (const SourceJob &source : sources)
            publish(source, digest, m_extracted);
    } else if (m_retryExtraction && m_extracted.channelCount == 0 && m_extractionError.isEmpty()) {
        m_decodeQueue.prepend(digest);
    } else {
        const auto sources = m_decodeJobs.take(digest);
        for (const SourceJob &source : sources) {
            QString error = m_extractionError.isEmpty()
                ? tr("无法生成或保存音频波形：%1").arg(source.path) : m_extractionError;
            if (!snapshotPath.isEmpty())
                error.replace(snapshotPath, source.path);
            failSource(source, error);
        }
    }
    m_extracted = {};
    if (!m_playbackRunning)
        m_timer->start(0);
}

void TimelineMediaCacheWorker::invalidate(SourceState &source)
{
    if (source.version.isEmpty())
        return;
    const QString version = std::move(source.version);
    source.version.clear();
    source.digest.clear();
    emit waveformInvalidated(version);
}

SourceState *TimelineMediaCacheWorker::pending(const SourceJob &job)
{
    auto &sources = job.video ? m_videoSources : m_sources;
    const auto it = sources.find(job.path);
    return it != sources.end() && it->generation == job.generation && !it->requests.isEmpty()
        ? &it.value() : nullptr;
}

void TimelineMediaCacheWorker::failSource(const SourceJob &job, const QString &error)
{
    if (auto *source = pending(job)) {
        const auto requests = std::move(source->requests);
        source->requests.clear();
        for (quint64 request : requests)
            emit failed(request, error);
    }
}

void TimelineMediaCacheWorker::publish(const SourceJob &job, const QByteArray &digest, const AudioWaveform &waveform)
{
    auto *source = pending(job);
    if (!source)
        return;
    if (!job.matchesFile()) {
        sourceChanged(job.path);
        return;
    }
    if (source->digest != digest)
        invalidate(*source);
    if (source->version.isEmpty())
        source->version = QUuid::createUuid().toString(QUuid::WithoutBraces);
    source->verified = job;
    source->digest = digest;
    const auto requests = std::move(source->requests);
    source->requests.clear();
    for (quint64 request : requests)
        emit waveformReady(request, source->version, waveform.durationMs, waveform.channelCount);
}

AudioWaveform TimelineMediaCacheWorker::cachedWaveform(const QByteArray &digest)
{
    if (const auto *cached = m_waveforms.object(digest))
        return *cached;
    if (m_cacheDirectory.isEmpty())
        return {};

    QFile file(QDir(m_cacheDirectory).filePath(QString::fromLatin1(digest.toHex()) + QStringLiteral(".peaks")));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QDataStream in(&file);
    in.setByteOrder(QDataStream::LittleEndian);
    quint32 magic = 0, format = 0;
    qint64 duration = 0;
    qint32 channels = 0, count = 0;
    in >> magic >> format >> duration >> channels >> count;
    const qint64 bytes = qint64(count) * waveformPeakBytes;
    if (in.status() != QDataStream::Ok || magic != waveformMagic || format != waveformFormat
        || duration <= 0 || channels <= 0 || count <= 0 || count % channels != 0
        || bytes > waveformDiskCacheBytes || file.size() != waveformHeaderBytes + bytes
        || (count / channels - 1) != (duration - 1) / AudioWaveform::bucketDurationMs) {
        return {};
    }
    AudioWaveform waveform;
    waveform.durationMs = duration;
    waveform.channelCount = channels;
    waveform.peaks.resize(count);
    for (auto &peak : waveform.peaks) {
        in.setFloatingPointPrecision(QDataStream::SinglePrecision);
        in >> peak.minimum >> peak.maximum;
        in.setFloatingPointPrecision(QDataStream::DoublePrecision);
        in >> peak.sumSquares >> peak.sampleCount;
        if (!std::isfinite(peak.minimum) || !std::isfinite(peak.maximum) || peak.minimum > peak.maximum
            || !std::isfinite(peak.sumSquares) || peak.sumSquares < 0.0
            || (peak.sampleCount == 0 && peak.sumSquares != 0.0)) {
            return {};
        }
    }
    if (in.status() != QDataStream::Ok)
        return {};
    const qint64 memoryBytes = qint64(count) * sizeof(AudioWaveform::Peak);
    m_waveforms.insert(digest, new AudioWaveform(waveform), int((memoryBytes + 1023) / 1024));
    return waveform;
}

bool TimelineMediaCacheWorker::storeWaveform(const QByteArray &digest, const AudioWaveform &waveform)
{
    const qint64 bytes = qint64(waveform.peaks.size()) * waveformPeakBytes;
    const qint64 memoryBytes = qint64(waveform.peaks.size()) * sizeof(AudioWaveform::Peak);
    const bool inMemory = m_waveforms.insert(digest, new AudioWaveform(waveform), int((memoryBytes + 1023) / 1024));
    if (m_cacheDirectory.isEmpty() || bytes > waveformDiskCacheBytes || !QDir().mkpath(m_cacheDirectory))
        return inMemory;

    const QDir directory(m_cacheDirectory);
    const QString fileName = QString::fromLatin1(digest.toHex()) + QStringLiteral(".peaks");
    QSaveFile file(directory.filePath(fileName));
    if (!file.open(QIODevice::WriteOnly))
        return inMemory;
    QDataStream out(&file);
    out.setByteOrder(QDataStream::LittleEndian);
    out << waveformMagic << waveformFormat << waveform.durationMs
        << qint32(waveform.channelCount) << qint32(waveform.peaks.size());
    for (const auto &peak : waveform.peaks) {
        out.setFloatingPointPrecision(QDataStream::SinglePrecision);
        out << peak.minimum << peak.maximum;
        out.setFloatingPointPrecision(QDataStream::DoublePrecision);
        out << peak.sumSquares << peak.sampleCount;
    }
    if (out.status() != QDataStream::Ok || !file.commit())
        return inMemory;

    const auto entries = directory.entryInfoList({QStringLiteral("*.peaks")}, QDir::Files,
                                                  QDir::Time | QDir::Reversed);
    qint64 total = 0;
    for (const auto &entry : entries)
        total += entry.size();
    for (const auto &entry : entries) {
        if (total <= waveformDiskCacheBytes)
            break;
        if (entry.fileName() != fileName && QFile::remove(entry.absoluteFilePath()))
            total -= entry.size();
    }
    return true;
}

void TimelineMediaCacheWorker::requestVideoSource(quint64 requestId, const QString &source)
{
    QString localPath = Utils::getVideoRealSource(source);
    if (localPath.startsWith(QStringLiteral("file:"), Qt::CaseInsensitive))
        localPath = QUrl(localPath).toLocalFile();
    const QFileInfo provided(localPath);
    const QString path = provided.isFile() ? provided.canonicalFilePath() : QString();
    if (path.isEmpty()) {
        emit failed(requestId, tr("找不到本地视频文件：%1").arg(source));
        return;
    }

    auto &state = m_videoSources[path];
    if (!state.version.isEmpty()) {
        if (state.verified.matchesFile() && m_watcher->files().contains(path)) {
            emit videoSourceReady(requestId, state.version, state.videoInfo.durationMs);
            return;
        }
        invalidateVideo(state);
    }
    const bool needsVerification = state.requests.isEmpty();
    state.requests.insert(requestId);
    if (needsVerification)
        queueVerification(state, QFileInfo(path), true);
}

SourceState *TimelineMediaCacheWorker::videoSource(const QString &version)
{
    if (version.isEmpty())
        return nullptr;

    const auto it = std::find_if(m_videoSources.begin(), m_videoSources.end(), [&version](const SourceState &state) {
        return state.version == version;
    });
    return it == m_videoSources.end() ? nullptr : &it.value();
}

void TimelineMediaCacheWorker::invalidateVideo(SourceState &state)
{
    if (state.version.isEmpty())
        return;

    const QString version = std::move(state.version);
    state.version.clear();
    if (m_videoWorker) {
        QMetaObject::invokeMethod(m_videoWorker, [this, source = state.verified]() {
            if (m_videoReaderSource.path == source.path && m_videoReaderSource.videoRevision == source.videoRevision)
                m_videoReader.reset();
        }, Qt::QueuedConnection);
    }
    emit videoSourceInvalidated(version);
    QSet<quint64> invalidatedRequests;
    for (auto &frame : m_videoFrames) {
        auto &subscribers = frame.subscribers;
        subscribers.erase(std::remove_if(subscribers.begin(), subscribers.end(),
                                         [&version, &invalidatedRequests](const VideoFrameSubscriber &subscriber) {
            if (subscriber.version != version)
                return false;
            invalidatedRequests.insert(subscriber.requestId);
            return true;
        }), subscribers.end());
    }
    for (quint64 requestId : invalidatedRequests) {
        if (m_videoRequests.remove(requestId))
            emit failed(requestId, tr("视频素材版本已失效，请重新请求。"));
    }
    discardUnusedVideoFrames();
}

void TimelineMediaCacheWorker::requestVideoThumbnails(quint64 requestId, const QString &version,
                                                      const QVariantList &samples, const QSize &pixelSize)
{
    if (pixelSize.isEmpty() || qint64(pixelSize.width()) * pixelSize.height() > thumbnailCacheBytes / 4) {
        emit failed(requestId, tr("视频缩略图尺寸无效。"));
        return;
    }
    if (samples.isEmpty()) {
        emit thumbnailsFinished(requestId);
        return;
    }

    SourceState *state = videoSource(version);
    if (!state || !state->verified.matchesFile()) {
        if (state)
            sourceChanged(state->verified.path);
        emit failed(requestId, tr("视频素材版本已失效，请重新请求。"));
        return;
    }

    m_videoRequests.insert(requestId, samples.size());
    const qint64 durationMs = state->videoInfo.durationMs;
    for (const QVariant &entry : samples) {
        const QVariantMap sample = entry.toMap();
        const QString slotId = sample.value(QStringLiteral("slotId")).toString();
        bool validTime = false;
        qint64 timeMs = sample.value(QStringLiteral("sourceTimeMs")).toLongLong(&validTime);
        if (validTime && timeMs >= 0 && durationMs > 0 && sample.value(QStringLiteral("loop")).toBool())
            timeMs %= durationMs;
        if (slotId.isEmpty() || !validTime || timeMs < 0 || (durationMs > 0 && timeMs >= durationMs)) {
            deliverThumbnail(requestId, slotId, {});
            continue;
        }

        QByteArray data;
        QDataStream(&data, QIODevice::WriteOnly)
            << thumbnailFormat << thumbnailSamplingVersion << state->verified.videoRevision << timeMs << pixelSize;
        const QString key = QString::fromLatin1(QCryptographicHash::hash(data, QCryptographicHash::Sha256).toHex());
        auto frame = m_videoFrames.find(key);
        if (frame == m_videoFrames.end()) {
            if (!cachedThumbnail(key, pixelSize).isNull()) {
                deliverThumbnail(requestId, slotId, QUrl(QStringLiteral("image://timeline-thumbnails/") + key));
                continue;
            }
            frame = m_videoFrames.insert(key, {timeMs, pixelSize, {}});
            m_videoQueue.enqueue(key);
        }
        frame->subscribers.append({requestId, slotId, version});
    }
    processVideoJobs();
}

void TimelineMediaCacheWorker::processVideoJobs()
{
    if (m_shuttingDown || m_playbackRunning || m_videoBusy)
        return;

    while (!m_videoProbes.isEmpty()) {
        SourceJob source = m_videoProbes.dequeue();
        if (!pending(source))
            continue;
        startVideoWorker([this, source]() mutable {
            if (m_videoReaderSource.path != source.path)
                m_videoReader.reset();
            TimelineVideoInfo videoInfo;
            auto file = openVideoFile(source.path, GENERIC_READ, FILE_SHARE_READ);
            source.videoRevision = videoFileRevision(file.get());
            const bool ok = !source.videoRevision.isEmpty()
                && probeTimelineVideo(source.path, videoInfo, m_videoInterrupted);
            file.reset();
            QMetaObject::invokeMethod(this, [this, source, ok, videoInfo]() {
                auto *state = pending(source);
                if (!state || m_shuttingDown)
                    return;
                if (m_videoInterrupted) {
                    m_videoProbes.prepend(source);
                } else if (source.videoRevision.isEmpty()) {
                    failSource(source, tr("无法核对视频文件版本：%1").arg(source.path));
                } else if (!source.matchesFile()) {
                    sourceChanged(source.path);
                } else if (!ok) {
                    failSource(source, tr("无法读取视频：%1").arg(source.path));
                } else {
                    state->version = QUuid::createUuid().toString(QUuid::WithoutBraces);
                    state->verified = source;
                    state->videoInfo = videoInfo;
                    const auto requests = std::move(state->requests);
                    state->requests.clear();
                    for (quint64 id : requests)
                        emit videoSourceReady(id, state->version, videoInfo.durationMs);
                }
            }, Qt::QueuedConnection);
        });
        return;
    }

    QMap<qint64, QString> times;
    QSize pixelSize;
    SourceJob video;
    TimelineVideoInfo videoInfo;
    // 同批帧共用输出尺寸，解码器可以跨批复用。
    const int queued = m_videoQueue.size();
    for (int i = 0; i < queued && !m_videoQueue.isEmpty(); ++i) {
        const QString key = m_videoQueue.dequeue();
        const auto frame = m_videoFrames.constFind(key);
        if (frame == m_videoFrames.constEnd())
            continue;
        const auto subscriber = std::find_if(frame->subscribers.cbegin(), frame->subscribers.cend(),
                                             [this](const VideoFrameSubscriber &candidate) {
            const auto *state = videoSource(candidate.version);
            return state && state->verified.matchesFile();
        });
        if (subscriber == frame->subscribers.cend()) {
            finishVideoFrame(key, {});
            continue;
        }
        const auto *state = videoSource(subscriber->version);
        const auto &verified = state->verified;
        if (times.isEmpty()) {
            video = verified;
            videoInfo = state->videoInfo;
            pixelSize = frame->pixelSize;
        } else if (verified.path != video.path || verified.videoRevision != video.videoRevision
                   || frame->pixelSize != pixelSize) {
            m_videoQueue.enqueue(key);
            continue;
        }

        times.insert(frame->timeMs, key);
        m_activeVideoFrames.insert(key);
    }
    if (times.isEmpty())
        return;

    const QVector<qint64> timestamps = times.keys().toVector();
    startVideoWorker([this, video, videoInfo, times, timestamps, pixelSize]() {
        // 抽帧持有原文件的只读共享句柄，查过版本的路径在解码期间始终指向同一份内容。
        const auto file = openVideoFile(video.path, GENERIC_READ, FILE_SHARE_READ);
        if (video.videoRevision != videoFileRevision(file.get())) {
            QMetaObject::invokeMethod(this, [this, video]() {
                if (!m_shuttingDown && !video.matchesFile()) {
                    sourceChanged(video.path);
                    // 同一缓存键可能还有别的素材路径在等待，从有效路径重新取帧。
                    m_videoInterrupted = true;
                }
            }, Qt::QueuedConnection);
            return;
        }
        if (m_videoReaderSource.path != video.path || m_videoReaderSource.videoRevision != video.videoRevision) {
            m_videoReader.reset();
            m_videoReaderSource = video;
        }
        decodeTimelineThumbnails(video.path, videoInfo, timestamps, pixelSize, m_videoReader, m_videoInterrupted,
                                 [this, &times](qint64 timeMs, const QImage &image) {
            const QString key = times.value(timeMs);
            QMetaObject::invokeMethod(this, [this, key, image]() {
                if (!m_shuttingDown && (!m_videoInterrupted || !image.isNull()))
                    finishVideoFrame(key, image);
            }, Qt::QueuedConnection);
            return !m_videoInterrupted;
        });
    });
}

void TimelineMediaCacheWorker::startVideoWorker(std::function<void()> work)
{
    if (!m_videoWorker) {
        auto *thread = new QThread(this);
        m_videoWorker = new QObject;
        m_videoWorker->moveToThread(thread);
        connect(thread, &QThread::finished, m_videoWorker, &QObject::deleteLater);
        thread->start();
    }
    m_videoIdleTimer->stop();
    m_videoInterrupted = false;
    m_videoBusy = true;
    const auto finished = [this]() {
        if (m_shuttingDown)
            return;
        m_videoBusy = false;
        const auto remaining = std::move(m_activeVideoFrames);
        m_activeVideoFrames.clear();
        for (const QString &key : remaining) {
            if (m_videoInterrupted)
                m_videoQueue.prepend(key);
            else
                finishVideoFrame(key, {});
        }

        if (!m_thumbnailDirectory.isEmpty()
            && (m_thumbnailDiskUsage < 0 || m_thumbnailDiskUsage > thumbnailDiskCacheBytes)) {
            const auto entries = QDir(m_thumbnailDirectory).entryInfoList({QStringLiteral("*.png")}, QDir::Files,
                                                                        QDir::Time | QDir::Reversed);
            qint64 total = 0;
            for (const auto &entry : entries)
                total += entry.size();
            for (const auto &entry : entries) {
                if (total <= thumbnailDiskCacheBytes)
                    break;
                if (QFile::remove(entry.absoluteFilePath()))
                    total -= entry.size();
            }
            m_thumbnailDiskUsage = total;
        }
        processVideoJobs();
        if (!m_videoBusy && !m_playbackRunning)
            m_videoIdleTimer->start();
    };
    QMetaObject::invokeMethod(m_videoWorker, [this, work = std::move(work), finished]() {
        work();
        QMetaObject::invokeMethod(this, finished, Qt::QueuedConnection);
    }, Qt::QueuedConnection);
}

void TimelineMediaCacheWorker::discardUnusedVideoFrames()
{
    bool activeNeeded = false;
    auto frame = m_videoFrames.begin();
    while (frame != m_videoFrames.end()) {
        if (m_activeVideoFrames.contains(frame.key())) {
            activeNeeded = activeNeeded || !frame->subscribers.isEmpty();
        } else if (frame->subscribers.isEmpty()) {
            m_videoQueue.removeAll(frame.key());
            frame = m_videoFrames.erase(frame);
            continue;
        }
        ++frame;
    }
    // 撤销当前批次后，下一批可以在同一读端提交新的 seek。
    if (m_videoBusy && !m_activeVideoFrames.isEmpty() && !activeNeeded)
        m_videoInterrupted = true;
}

void TimelineMediaCacheWorker::deliverThumbnail(quint64 requestId, const QString &slotId, const QUrl &imageUrl)
{
    const auto request = m_videoRequests.find(requestId);
    if (request == m_videoRequests.end())
        return;
    emit thumbnailReady(requestId, slotId, imageUrl);
    if (--request.value() == 0) {
        m_videoRequests.erase(request);
        emit thumbnailsFinished(requestId);
    }
}

void TimelineMediaCacheWorker::finishVideoFrame(const QString &key, const QImage &image)
{
    m_activeVideoFrames.remove(key);
    const auto job = m_videoFrames.take(key);
    QUrl url;
    for (const auto &subscriber : job.subscribers) {
        const auto *state = videoSource(subscriber.version);
        const bool verified = state && state->verified.matchesFile();
        if (state && !verified)
            sourceChanged(state->verified.path);
        if (!verified || image.isNull()) {
            deliverThumbnail(subscriber.requestId, subscriber.slotId, {});
            continue;
        }
        if (url.isEmpty()) {
            storeThumbnail(key, image, true);
            url = QUrl(QStringLiteral("image://timeline-thumbnails/") + key);
        }
        deliverThumbnail(subscriber.requestId, subscriber.slotId, url);
    }
}

QImage TimelineMediaCacheWorker::cachedThumbnail(const QString &key, const QSize &pixelSize)
{
    const QImage cached = m_owner->thumbnailImage(key);
    if (!cached.isNull() || m_thumbnailDirectory.isEmpty())
        return cached;

    QFile file(QDir(m_thumbnailDirectory).filePath(key + QStringLiteral(".png")));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    QImageReader reader(&file, "png");
    reader.setAutoDetectImageFormat(false);
    const QSize size = reader.size();
    if (size.isEmpty() || size.width() > pixelSize.width() || size.height() > pixelSize.height())
        return {};

    const QImage image = reader.read().convertToFormat(QImage::Format_RGBA8888);
    if (!image.isNull())
        storeThumbnail(key, image, false);
    return image;
}

void TimelineMediaCacheWorker::storeThumbnail(const QString &key, const QImage &image, bool persist)
{
    {
        QMutexLocker lock(&m_owner->m_thumbnailMutex);
        m_owner->m_thumbnails.insert(key, new QImage(image), int(image.sizeInBytes()));
    }
    if (!persist || m_thumbnailDirectory.isEmpty() || !QDir().mkpath(m_thumbnailDirectory))
        return;

    const QString path = QDir(m_thumbnailDirectory).filePath(key + QStringLiteral(".png"));
    const qint64 previousSize = QFileInfo(path).size();
    QSaveFile file(path);
    if (file.open(QIODevice::WriteOnly) && image.save(&file, "PNG") && file.commit()
        && m_thumbnailDiskUsage >= 0) {
        m_thumbnailDiskUsage += QFileInfo(path).size() - previousSize;
    }
}

void TimelineMediaCacheWorker::cancel(quint64 requestId)
{
    for (auto &source : m_sources) {
        if (source.requests.remove(requestId))
            break;
    }
    for (auto &source : m_videoSources) {
        if (source.requests.remove(requestId))
            break;
    }
    if (m_videoRequests.remove(requestId)) {
        for (auto &frame : m_videoFrames) {
            auto &subscribers = frame.subscribers;
            subscribers.erase(std::remove_if(subscribers.begin(), subscribers.end(),
                                             [requestId](const VideoFrameSubscriber &subscriber) {
                return subscriber.requestId == requestId;
            }), subscribers.end());
        }
        discardUnusedVideoFrames();
    }
    if (m_extractor) {
        const auto &jobs = m_decodeJobs[m_extractingDigest];
        if (std::none_of(jobs.cbegin(), jobs.cend(), [this](const SourceJob &job) { return pending(job); })) {
            m_retryExtraction = true;
            m_extractor->requestInterruption();
        }
    }
}

void TimelineMediaCacheWorker::setPlaybackRunning(bool running)
{
    m_playbackRunning = running;
    if (running) {
        m_timer->stop();
        m_videoIdleTimer->stop();
        if (m_videoWorker) {
            m_videoInterrupted = true;
            QMetaObject::invokeMethod(m_videoWorker, [this]() { m_videoReader.reset(); }, Qt::QueuedConnection);
        }
        if (m_extractor) {
            m_retryExtraction = true;
            m_extractor->requestInterruption();
        }
    } else {
        m_timer->start(0);
        processVideoJobs();
    }
}

void TimelineMediaCacheWorker::shutdown()
{
    m_shuttingDown = true;
    m_timer->stop();
    m_videoIdleTimer->stop();
    m_scan.reset();
    if (m_videoWorker) {
        m_videoInterrupted = true;
        QThread *thread = m_videoWorker->thread();
        QMetaObject::invokeMethod(m_videoWorker, [this]() { m_videoReader.reset(); }, Qt::BlockingQueuedConnection);
        thread->quit();
        thread->wait();
        m_videoWorker = nullptr;
    }
    if (m_extractor)
        m_extractor->requestInterruption();
    else
        QThread::currentThread()->quit();
}

TimelineMediaCache::TimelineMediaCache(const QString &cacheDirectory, QObject *parent)
    : QObject(parent)
    , m_thumbnails(thumbnailCacheBytes)
    , m_worker(new TimelineMediaCacheWorker(cacheDirectory, this))
{
    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_worker, &TimelineMediaCacheWorker::waveformReady, this,
            [this](quint64 id, const QString &version, qint64 duration, int channels) {
        if (m_pendingRequests.remove(id))
            emit waveformReady(id, version, duration, channels);
    });
    connect(m_worker, &TimelineMediaCacheWorker::waveformColumnsReady, this,
            [this](quint64 id, const QString &version, const QVariantList &peaks) {
        if (m_pendingRequests.remove(id))
            emit waveformColumnsReady(id, version, peaks);
    });
    connect(m_worker, &TimelineMediaCacheWorker::videoSourceReady, this,
            [this](quint64 id, const QString &version, qint64 duration) {
        if (m_pendingRequests.remove(id))
            emit videoSourceReady(id, version, duration);
    });
    connect(m_worker, &TimelineMediaCacheWorker::videoSourceInvalidated,
            this, &TimelineMediaCache::videoSourceInvalidated);
    connect(m_worker, &TimelineMediaCacheWorker::thumbnailReady, this,
            [this](quint64 id, const QString &slotId, const QUrl &url) {
        if (m_pendingRequests.contains(id))
            emit thumbnailReady(id, slotId, url);
    });
    connect(m_worker, &TimelineMediaCacheWorker::thumbnailsFinished,
            this, [this](quint64 id) { m_pendingRequests.remove(id); });
    connect(m_worker, &TimelineMediaCacheWorker::failed, this, [this](quint64 id, const QString &error) {
        if (m_pendingRequests.remove(id))
            emit failed(id, error);
    });
    connect(m_worker, &TimelineMediaCacheWorker::waveformInvalidated, this, &TimelineMediaCache::waveformInvalidated);
    m_thread.start();
}

TimelineMediaCache::~TimelineMediaCache()
{
    QMetaObject::invokeMethod(m_worker, [worker = m_worker]() { worker->shutdown(); }, Qt::QueuedConnection);
    m_thread.wait();
}

quint64 TimelineMediaCache::requestWaveform(const QString &source)
{
    const quint64 requestId = ++m_nextRequestId;
    m_pendingRequests.insert(requestId);
    QMetaObject::invokeMethod(m_worker, [worker = m_worker, requestId, source]() {
        worker->requestWaveform(requestId, source);
    }, Qt::QueuedConnection);
    return requestId;
}

quint64 TimelineMediaCache::requestWaveformColumns(const QString &version, qint64 startMs, qint64 endMs,
                                                  int width, bool loop, bool combineChannels, bool includeRms)
{
    const quint64 requestId = ++m_nextRequestId;
    m_pendingRequests.insert(requestId);
    QMetaObject::invokeMethod(m_worker, [worker = m_worker, requestId, version, startMs, endMs, width,
                                         loop, combineChannels, includeRms]() {
        worker->requestColumns(requestId, version, startMs, endMs, width, loop, combineChannels, includeRms);
    }, Qt::QueuedConnection);
    return requestId;
}

quint64 TimelineMediaCache::requestVideoSource(const QString &source)
{
    const quint64 requestId = ++m_nextRequestId;
    m_pendingRequests.insert(requestId);
    QMetaObject::invokeMethod(m_worker, [worker = m_worker, requestId, source]() {
        worker->requestVideoSource(requestId, source);
    }, Qt::QueuedConnection);
    return requestId;
}

quint64 TimelineMediaCache::requestVideoThumbnails(const QString &version, const QVariantList &samples,
                                                  const QSize &pixelSize)
{
    const quint64 requestId = ++m_nextRequestId;
    m_pendingRequests.insert(requestId);
    QMetaObject::invokeMethod(m_worker, [worker = m_worker, requestId, version, samples, pixelSize]() {
        worker->requestVideoThumbnails(requestId, version, samples, pixelSize);
    }, Qt::QueuedConnection);
    return requestId;
}

QImage TimelineMediaCache::thumbnailImage(const QString &key) const
{
    QMutexLocker lock(&m_thumbnailMutex);
    const auto *image = m_thumbnails.object(key);
    return image ? *image : QImage();
}

void TimelineMediaCache::cancel(quint64 requestId)
{
    if (m_pendingRequests.remove(requestId)) {
        QMetaObject::invokeMethod(m_worker, [worker = m_worker, requestId]() { worker->cancel(requestId); },
                                  Qt::QueuedConnection);
    }
}

void TimelineMediaCache::setPlaybackRunning(bool running)
{
    QMetaObject::invokeMethod(m_worker, [worker = m_worker, running]() { worker->setPlaybackRunning(running); },
                              Qt::QueuedConnection);
}

#include "TimelineMediaCache.moc"
