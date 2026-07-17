#pragma once

#include <QImage>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QRect>
#include <QTemporaryDir>
#include <QTimer>
#include <QUrl>
#include <QVector>


class Device;
class DeviceModel;
class TimelineCommandModel;
class TimelineController;
namespace EarthUI {
class AppShellController;
}

class PcTimelinePreviewGenerator final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(Device *pcDevice READ pcDevice NOTIFY pcDeviceChanged FINAL)
    Q_PROPERTY(QImage previewImage READ previewImage NOTIFY previewChanged FINAL)
    Q_PROPERTY(QUrl previewUrl READ previewUrl NOTIFY previewChanged FINAL)
    Q_PROPERTY(qint64 previewTimeMs READ previewTimeMs NOTIFY previewChanged FINAL)
    Q_PROPERTY(QString ffmpegProgram READ ffmpegProgram WRITE setFfmpegProgram NOTIFY ffmpegProgramChanged FINAL)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged FINAL)
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged FINAL)

public:
    PcTimelinePreviewGenerator(TimelineController *timelineController,
                               TimelineCommandModel *timelineCommandModel,
                               DeviceModel *deviceModel,
                               EarthUI::AppShellController *shellController,
                               QObject *parent = nullptr);

    Device *pcDevice() const;

    QImage previewImage() const;
    QUrl previewUrl() const;
    qint64 previewTimeMs() const;

    QString ffmpegProgram() const;
    void setFfmpegProgram(const QString &program);

    bool busy() const;
    QString errorString() const;

    Q_INVOKABLE void refresh();

signals:
    void pcDeviceChanged();
    void previewChanged();
    void previewReady(const QImage &image, qint64 timeMs);
    void ffmpegProgramChanged();
    void busyChanged();
    void errorStringChanged();

private:
    struct VideoState
    {
        QString source;
        QRect rect;
        qint64 positionMs = 0;
        qint64 changedAtMs = 0;
        bool playing = false;
    };

    void requestPreview();
    bool isActive() const;
    void updateActiveState();
    void updatePcDevice();
    void setPcDevice(Device *device);
    void startPreview();
    QVector<VideoState> videoStatesAt(qint64 timeMs, const QSize &canvasSize) const;
    void startNextFrame();
    void completeFrame(bool success, const QString &errorMessage);
    void finishPreview();
    void setBusy(bool busy);
    void setErrorString(const QString &errorString);

    QPointer<TimelineController> m_timelineController;
    QPointer<TimelineCommandModel> m_timelineCommandModel;
    QPointer<DeviceModel> m_deviceModel;
    QPointer<EarthUI::AppShellController> m_shellController;
    QPointer<Device> m_pcDevice;
    QImage m_previewImage;
    QUrl m_previewUrl;
    qint64 m_previewTimeMs = 0;
    QString m_ffmpegProgram = QStringLiteral("ffmpeg");
    bool m_busy = false;
    QString m_errorString;
    QTimer m_refreshTimer;
    QProcess m_process;
    QTemporaryDir m_temporaryDir;
    QVector<VideoState> m_videoStates;
    QImage m_canvas;
    QStringList m_errors;
    int m_frameIndex = 0;
    int m_revision = 0;
    int m_generationRevision = 0;
    qint64 m_generationTimeMs = 0;
    bool m_framePending = false;
};
