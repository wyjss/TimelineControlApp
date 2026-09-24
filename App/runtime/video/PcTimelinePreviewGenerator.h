#pragma once

#include <QImage>
#include <QObject>
#include <QPointer>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <QVector>

#include "runtime/video/PcVideoStateCalculator.h"


class Device;
class DeviceModel;
class TimelineCommandModel;
class TimelineManager;
class PcTimelinePreviewWorker;
namespace UICore {
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
    using VideoState = PcVideoStateCalculator::VideoState;

    PcTimelinePreviewGenerator(TimelineManager *timelineManager,
                               DeviceModel *deviceModel,
                               UICore::AppShellController *shellController,
                               QObject *parent = nullptr);
    ~PcTimelinePreviewGenerator() override;

    Device *pcDevice() const;

    QImage previewImage() const;
    QUrl previewUrl() const;
    qint64 previewTimeMs() const;

    QString ffmpegProgram() const;
    void setFfmpegProgram(const QString &program);

    bool busy() const;
    QString errorString() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void seek(qint64 timeMs);

signals:
    void previewRequested(const QVector<VideoState> &videoStates, const QSize &canvasSize,
                          const QString &ffmpegProgram, int revision);
    void cancelRequested();
    void pcDeviceChanged();
    void previewChanged();
    void previewReady(const QImage &image, qint64 timeMs);
    void ffmpegProgramChanged();
    void busyChanged();
    void errorStringChanged();

private:
    void requestPreview();
    bool isActive() const;
    void updateActiveState();
    void updateCurrentTimeline();
    void updatePcDevice();
    void setPcDevice(Device *device);
    void startPreview();
    void setBusy(bool busy);
    void setErrorString(const QString &errorString);

    QPointer<TimelineManager> m_timelineManager;
    QPointer<TimelineCommandModel> m_timelineCommandModel;
    QPointer<DeviceModel> m_deviceModel;
    QPointer<UICore::AppShellController> m_shellController;
    QPointer<Device> m_pcDevice;
    QImage m_previewImage;
    QUrl m_previewUrl;
    qint64 m_previewTimeMs = 0;
    QString m_ffmpegProgram = QStringLiteral("ffmpeg");
    bool m_busy = false;
    QString m_errorString;
    QTimer m_refreshTimer;
    QThread m_workerThread;
    PcTimelinePreviewWorker *m_worker = nullptr;
    int m_revision = 0;
    int m_generationRevision = 0;
    qint64 m_requestedTimeMs = 0;
    qint64 m_generationTimeMs = 0;
};

Q_DECLARE_METATYPE(QVector<PcTimelinePreviewGenerator::VideoState>)
