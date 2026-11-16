#include "audio/AudioWaveformExtractor.h"

#include <QElapsedTimer>
#include <QFileInfo>
#include <QScopeGuard>

#include <algorithm>
#include <cmath>
#include <limits>
#include <type_traits>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/samplefmt.h>
}

namespace {

constexpr float infinity = std::numeric_limits<float>::infinity();

class AudioPeakAccumulator final
{
public:
    void appendFrame(const AVFrame &frame);

    AudioWaveform waveform;
    qint64 sampleCount = 0;
    int sampleRate = 0;
    bool invalidFrame = false;

private:
    template<typename Sample>
    void appendSamples(const AVFrame &frame, bool planar, double scale, double offset = 0.0);
};

void AudioPeakAccumulator::appendFrame(const AVFrame &frame)
{
    if (frame.nb_samples <= 0)
        return;

    const int channels = frame.ch_layout.nb_channels;
    if (frame.sample_rate <= 0 || channels <= 0 || !frame.extended_data
        || (sampleRate > 0 && (frame.sample_rate != sampleRate || channels != waveform.channelCount))) {
        invalidFrame = true;
        return;
    }
    sampleRate = frame.sample_rate;
    waveform.channelCount = channels;

    const auto format = static_cast<AVSampleFormat>(frame.format);
    const bool planar = av_sample_fmt_is_planar(format) != 0;
    const int planeCount = planar ? channels : 1;
    for (int plane = 0; plane < planeCount; ++plane) {
        if (!frame.extended_data[plane]) {
            invalidFrame = true;
            return;
        }
    }

    switch (av_get_packed_sample_fmt(format)) {
    case AV_SAMPLE_FMT_U8:
        appendSamples<quint8>(frame, planar, 1.0 / 128.0, -1.0);
        break;
    case AV_SAMPLE_FMT_S16:
        appendSamples<qint16>(frame, planar, 1.0 / 32768.0);
        break;
    case AV_SAMPLE_FMT_S32:
        appendSamples<qint32>(frame, planar, 1.0 / 2147483648.0);
        break;
    case AV_SAMPLE_FMT_S64:
        appendSamples<qint64>(frame, planar, 1.0 / 9223372036854775808.0);
        break;
    case AV_SAMPLE_FMT_FLT:
        appendSamples<float>(frame, planar, 1.0);
        break;
    case AV_SAMPLE_FMT_DBL:
        appendSamples<double>(frame, planar, 1.0);
        break;
    default:
        invalidFrame = true;
        break;
    }
}

template<typename Sample>
void AudioPeakAccumulator::appendSamples(const AVFrame &frame, bool planar, double scale, double offset)
{
    constexpr int bucketsPerSecond = 1000 / AudioWaveform::bucketDurationMs;
    const int channels = waveform.channelCount;
    const int stride = planar ? 1 : channels;
    int frameOffset = 0;

    while (frameOffset < frame.nb_samples) {
        // 采样率不能整除时按累计采样位置计算边界，避免每桶舍入造成时间漂移。
        const qint64 bucket = sampleCount * bucketsPerSecond / sampleRate;
        const qint64 nextSample = ((bucket + 1) * sampleRate + bucketsPerSecond - 1) / bucketsPerSecond;
        const int count = static_cast<int>(std::min<qint64>(frame.nb_samples - frameOffset,
                                                           nextSample - sampleCount));
        if (bucket >= std::numeric_limits<int>::max() / channels) {
            invalidFrame = true;
            return;
        }
        const int firstPeak = static_cast<int>(bucket * channels);
        if (firstPeak >= waveform.peaks.size()) {
            waveform.peaks.resize(firstPeak + channels);
            std::fill(waveform.peaks.begin() + firstPeak, waveform.peaks.end(),
                      AudioWaveform::Peak{infinity, -infinity});
        }

        for (int channel = 0; channel < channels; ++channel) {
            const auto *samples = reinterpret_cast<const Sample *>(frame.extended_data[planar ? channel : 0]);
            samples += frameOffset * stride + (planar ? 0 : channel);
            Sample minimum = std::numeric_limits<Sample>::max();
            Sample maximum = std::numeric_limits<Sample>::lowest();
            double sumSquares = 0.0;
            quint32 validSampleCount = 0;
            for (int index = 0; index < count; ++index) {
                const Sample value = samples[index * stride];
                if constexpr (std::is_floating_point_v<Sample>) {
                    // 排除非有限值和峰值字段无法表示的样本，避免整桶统计失效。
                    constexpr float peakLimit = std::numeric_limits<float>::max();
                    if (!(value >= -peakLimit && value <= peakLimit))
                        continue;
                }
                minimum = std::min(minimum, value);
                maximum = std::max(maximum, value);
                const double normalized = static_cast<double>(value) * scale + offset;
                sumSquares += normalized * normalized;
                ++validSampleCount;
            }
            if (validSampleCount > 0) {
                AudioWaveform::Peak &peak = waveform.peaks[firstPeak + channel];
                peak.minimum = std::min(peak.minimum, static_cast<float>(static_cast<double>(minimum) * scale + offset));
                peak.maximum = std::max(peak.maximum, static_cast<float>(static_cast<double>(maximum) * scale + offset));
                peak.sumSquares += sumSquares;
                peak.sampleCount += validSampleCount;
            }
        }

        frameOffset += count;
        sampleCount += count;
    }
}

} // namespace

AudioWaveformExtractor::AudioWaveformExtractor(const QString &filePath, double speed, QObject *parent)
    : QThread(parent)
    , m_filePath(filePath)
    , m_speed(speed)
{
    qRegisterMetaType<AudioWaveform>();
}

AudioWaveformExtractor::~AudioWaveformExtractor()
{
    requestInterruption();
    wait();
}

void AudioWaveformExtractor::run()
{
    const QFileInfo file(m_filePath);
    if (!file.isFile()) {
        emit failed(tr("找不到音频文件：%1").arg(m_filePath));
        return;
    }
    if (!std::isfinite(m_speed) || m_speed <= 0.0) {
        emit failed(tr("音频提取倍速必须为正数。"));
        return;
    }

    AVFormatContext *input = avformat_alloc_context();
    AVCodecContext *decoder = nullptr;
    AVPacket *packet = nullptr;
    AVFrame *frame = nullptr;
    const auto release = qScopeGuard([&] {
        av_frame_free(&frame);
        av_packet_free(&packet);
        avcodec_free_context(&decoder);
        avformat_close_input(&input);
    });

    if (input) {
        input->interrupt_callback = {[](void *opaque) -> int {
            return static_cast<AudioWaveformExtractor *>(opaque)->isInterruptionRequested();
        }, this};
    }
    const QByteArray path = file.absoluteFilePath().toUtf8();
    if (!input || avformat_open_input(&input, path.constData(), nullptr, nullptr) < 0
        || avformat_find_stream_info(input, nullptr) < 0) {
        if (!isInterruptionRequested())
            emit failed(tr("无法打开音频源：%1").arg(m_filePath));
        return;
    }

    const AVCodec *codec = nullptr;
    const int audioStream = av_find_best_stream(input, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0);
    if (audioStream >= 0)
        decoder = avcodec_alloc_context3(codec);
    if (!decoder || avcodec_parameters_to_context(decoder, input->streams[audioStream]->codecpar) < 0) {
        if (!isInterruptionRequested())
            emit failed(tr("无法初始化音频解码：%1").arg(m_filePath));
        return;
    }
    decoder->pkt_timebase = input->streams[audioStream]->time_base;
    decoder->err_recognition |= AV_EF_EXPLODE;
    packet = av_packet_alloc();
    frame = av_frame_alloc();
    if (!packet || !frame || avcodec_open2(decoder, codec, nullptr) < 0) {
        if (!isInterruptionRequested())
            emit failed(tr("无法初始化音频解码：%1").arg(m_filePath));
        return;
    }

    AudioPeakAccumulator accumulator;
    QElapsedTimer elapsed;
    elapsed.start();
    bool complete = false;
    while (!isInterruptionRequested()) {
        const int readStatus = av_read_frame(input, packet);
        const bool draining = readStatus == AVERROR_EOF;
        if (readStatus < 0) {
            if (!draining || (input->pb && input->pb->error < 0))
                break;
        } else if (packet->stream_index != audioStream) {
            av_packet_unref(packet);
            continue;
        } else if (packet->flags & AV_PKT_FLAG_CORRUPT) {
            break;
        }

        int decodeStatus = avcodec_send_packet(decoder, draining ? nullptr : packet);
        av_packet_unref(packet);
        if (decodeStatus < 0)
            break;

        while (!isInterruptionRequested() && (decodeStatus = avcodec_receive_frame(decoder, frame)) == 0) {
            if ((frame->flags & AV_FRAME_FLAG_CORRUPT) || frame->decode_error_flags) {
                accumulator.invalidFrame = true;
                break;
            }
            accumulator.appendFrame(*frame);
            av_frame_unref(frame);
            if (accumulator.invalidFrame)
                break;

            if (accumulator.sampleRate > 0) {
                const double targetMs = double(accumulator.sampleCount) * 1000.0 / accumulator.sampleRate / m_speed;
                for (double remainingMs = targetMs - elapsed.elapsed();
                     remainingMs > 0.0 && !isInterruptionRequested();
                     remainingMs = targetMs - elapsed.elapsed()) {
                    msleep(static_cast<unsigned long>(std::ceil(std::min(10.0, remainingMs))));
                }
            }
        }
        if (draining) {
            complete = decodeStatus == AVERROR_EOF;
            break;
        }
        if (accumulator.invalidFrame || decodeStatus != AVERROR(EAGAIN))
            break;
    }

    if (isInterruptionRequested())
        return;
    // 读到文件末尾并取完解码器的尾帧后才能发布结果。
    if (!complete) {
        emit failed(tr("音频解码未能完成：%1").arg(m_filePath));
        return;
    }
    if (accumulator.invalidFrame || accumulator.sampleCount == 0) {
        emit failed(tr("无法提取有效的音频采样：%1").arg(m_filePath));
        return;
    }

    AudioWaveform &waveform = accumulator.waveform;
    waveform.durationMs = (accumulator.sampleCount * 1000 + accumulator.sampleRate - 1)
        / accumulator.sampleRate;
    const qint64 bucketCount = (waveform.durationMs - 1) / AudioWaveform::bucketDurationMs + 1;
    if (bucketCount > std::numeric_limits<int>::max() / waveform.channelCount) {
        emit failed(tr("音频波形包含过多时间桶：%1").arg(m_filePath));
        return;
    }
    waveform.peaks.resize(int(bucketCount * waveform.channelCount));
    for (AudioWaveform::Peak &peak : waveform.peaks) {
        if (!std::isfinite(peak.minimum) || !std::isfinite(peak.maximum))
            peak = {};
    }
    emit resultReady(waveform);
}
