#pragma once

#include <memory>

#include <QImage>
#include <QQuickPaintedItem>
#include <QSize>
#include <QTimer>
#include <QUrl>

class AVReader;
namespace PixelTool {
class PixelConvProcessor;
struct AVFramePixelData;
}


class FfmpegVideoFrameItem : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool playing READ isPlaying NOTIFY playingChanged)
    Q_PROPERTY(qint64 position READ position NOTIFY positionChanged)
    Q_PROPERTY(qint64 duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(QSize videoSize READ videoSize NOTIFY videoSizeChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)
    Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY hasFrameChanged)

public:
    explicit FfmpegVideoFrameItem(QQuickItem *parent = nullptr);
    ~FfmpegVideoFrameItem() override;

    QUrl source() const;
    void setSource(const QUrl &source);

    bool isPlaying() const;
    qint64 position() const;
    qint64 duration() const;
    QSize videoSize() const;
    QString errorString() const;
    bool hasFrame() const;

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(qint64 positionMs);

    void paint(QPainter *painter) override;

signals:
    void sourceChanged();
    void playingChanged();
    void positionChanged();
    void durationChanged();
    void videoSizeChanged();
    void errorStringChanged();
    void hasFrameChanged();

private slots:
    void advanceFrame();

private:
    bool openCurrentSource();
    void closeDecoder();
    bool updateOutputInfo();
    void setPlaying(bool playing);
    void setPositionValue(qint64 positionMs);
    void setDurationValue(qint64 durationMs);
    void setVideoSizeValue(const QSize &size);
    void setErrorString(const QString &errorString);
    void setHasFrame(bool hasFrame);
    bool takeAndConvertFrame();
    bool convertFrame(const PixelTool::AVFramePixelData &frameData, qint64 framePositionMs);
    QString sourcePath() const;

    QUrl m_source;
    bool m_playing = false;
    bool m_hasFrame = false;
    bool m_pendingFrame = false;
    qint64 m_positionMs = 0;
    qint64 m_durationMs = 0;
    QSize m_videoSize;
    QString m_errorString;
    QImage m_frameImage;
    QTimer m_timer;

    std::unique_ptr<AVReader> m_reader;
    std::unique_ptr<PixelTool::PixelConvProcessor> m_converter;
};
