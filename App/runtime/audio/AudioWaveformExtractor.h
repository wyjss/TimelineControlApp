#pragma once

#include <QThread>
#include <QVector>

struct AudioWaveform
{
    struct Peak
    {
        float minimum = 0.0f;
        float maximum = 0.0f;
        //! 归一化采样的平方和及有效采样数。
        double sumSquares = 0.0;
        quint32 sampleCount = 0;
    };

    static constexpr int bucketDurationMs = 10;
    qint64 durationMs = 0;
    int channelCount = 0;
    //! 以满幅为 1.0，按时间桶排列，每个桶内按声道顺序排列。
    QVector<Peak> peaks;
};

Q_DECLARE_METATYPE(AudioWaveform)

class AudioWaveformExtractor final : public QThread
{
    Q_OBJECT

public:
    //! 输入本地文件路径。连接结果信号后调用 start()，可请求中断。
    explicit AudioWaveformExtractor(const QString &filePath, double speed = 8.0,
                                    QObject *parent = nullptr);
    ~AudioWaveformExtractor() override;

signals:
    void resultReady(const AudioWaveform &waveform);
    void failed(const QString &errorString);

protected:
    void run() override;

private:
    const QString m_filePath;
    const double m_speed;
};
