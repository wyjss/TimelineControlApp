#include "runtime/video/PcTimelinePreviewGenerator.h"

#include <QFile>
#include <QPainter>
#include <QProcess>
#include <QTemporaryDir>

#include "devices/Device.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceModel.h"
#include <UICore/Shell/AppShellController.h>
#include "timeline/Timeline.h"
#include "timeline/TimelineCommand.h"
#include "timeline/TimelineManager.h"


namespace {

const QString kTimelineDrawerKey = QStringLiteral("timeline");

} // namespace


class PcTimelinePreviewWorker final : public QObject
{
    Q_OBJECT

public:
    using VideoState = PcTimelinePreviewGenerator::VideoState;

    PcTimelinePreviewWorker()
        : m_process(this)
    {
        connect(&m_process,
                qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
                this,
                [this](int exitCode, QProcess::ExitStatus exitStatus) {
                    completeFrame(exitCode == 0 && exitStatus == QProcess::NormalExit,
                                  QString::fromLocal8Bit(m_process.readAllStandardError()).trimmed());
                });
        connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
            if (error == QProcess::FailedToStart)
                completeFrame(false, m_process.errorString());
        });
    }

public slots:
    void startPreview(const QVector<VideoState> &videoStates, const QSize &canvasSize,
                      const QString &ffmpegProgram, int revision);
    void cancel();

signals:
    void finished(const QImage &image, const QUrl &url, const QString &errorString, int revision);

private:
    void startNextFrame();
    void completeFrame(bool success, const QString &errorMessage);
    void finishPreview();

    QProcess m_process;
    QTemporaryDir m_temporaryDir;
    QVector<VideoState> m_videoStates;
    QImage m_canvas;
    QStringList m_errors;
    QString m_ffmpegProgram;
    int m_frameIndex = 0;
    int m_revision = -1;
    bool m_framePending = false;
};


PcTimelinePreviewGenerator::PcTimelinePreviewGenerator(TimelineManager *timelineManager,
                                                       DeviceModel *deviceModel,
                                                       UICore::AppShellController *shellController,
                                                       QObject *parent)
    : QObject(parent)
    , m_timelineManager(timelineManager)
    , m_deviceModel(deviceModel)
    , m_shellController(shellController)
{
    m_refreshTimer.setInterval(80);
    m_refreshTimer.setSingleShot(true);
    connect(&m_refreshTimer, &QTimer::timeout, this, &PcTimelinePreviewGenerator::startPreview);

    if (m_timelineManager) {
        connect(m_timelineManager, &TimelineManager::playbackStateChanged,
                this, &PcTimelinePreviewGenerator::updateActiveState);
        connect(m_timelineManager, &TimelineManager::currentTimelineChanged,
                this, &PcTimelinePreviewGenerator::updateCurrentTimeline);
    }
    if (m_deviceModel)
        connect(m_deviceModel, &DeviceModel::currentDeviceChanged,
                this, &PcTimelinePreviewGenerator::updatePcDevice);
    if (m_shellController)
        connect(m_shellController, &UICore::AppShellController::activeNavigationKeyChanged,
                this, &PcTimelinePreviewGenerator::updateActiveState);

    qRegisterMetaType<QVector<VideoState>>("QVector<VideoState>");
    m_worker = new PcTimelinePreviewWorker;
    m_worker->moveToThread(&m_workerThread);
    connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(this, &PcTimelinePreviewGenerator::previewRequested,
            m_worker, &PcTimelinePreviewWorker::startPreview, Qt::QueuedConnection);
    connect(this, &PcTimelinePreviewGenerator::cancelRequested,
            m_worker, &PcTimelinePreviewWorker::cancel, Qt::QueuedConnection);
    connect(m_worker, &PcTimelinePreviewWorker::finished, this,
            [this](const QImage &image, const QUrl &url, const QString &errorString, int revision) {
                if (isActive() && revision == m_generationRevision) {
                    m_previewImage = image;
                    if (!m_previewUrl.isEmpty())
                        QFile::remove(m_previewUrl.toLocalFile());
                    m_previewUrl = url;
                    m_previewTimeMs = m_generationTimeMs;
                    setErrorString(errorString);
                    emit previewChanged();
                    emit previewReady(m_previewImage, m_previewTimeMs);
                } else if (!url.isEmpty()) {
                    QFile::remove(url.toLocalFile());
                }
                setBusy(false);
                if (isActive() && m_generationRevision != m_revision && !m_refreshTimer.isActive())
                    m_refreshTimer.start();
            }, Qt::QueuedConnection);
    m_workerThread.start();

    updateCurrentTimeline();
    updatePcDevice();
    updateActiveState();
}

PcTimelinePreviewGenerator::~PcTimelinePreviewGenerator()
{
    QMetaObject::invokeMethod(m_worker, "cancel", Qt::BlockingQueuedConnection);
    m_workerThread.quit();
    m_workerThread.wait();
}

Device *PcTimelinePreviewGenerator::pcDevice() const
{
    return m_pcDevice.data();
}

void PcTimelinePreviewGenerator::updatePcDevice()
{
    setPcDevice(m_deviceModel ? m_deviceModel->currentDevice() : nullptr);
}

void PcTimelinePreviewGenerator::setPcDevice(Device *device)
{
    if (device && !device->supportsProtocol(DeviceProtocol::Pc))
        device = nullptr;
    if (m_pcDevice == device)
        return;

    if (m_pcDevice)
        disconnect(m_pcDevice, nullptr, this, nullptr);
    m_generationRevision = -1;
    emit cancelRequested();
    m_pcDevice = device;
    if (m_pcDevice) {
        connect(m_pcDevice, &Device::configValuesChanged,
                this, &PcTimelinePreviewGenerator::requestPreview);
        connect(m_pcDevice, &QObject::destroyed, this, [this]() {
            m_generationRevision = -1;
            emit cancelRequested();
            m_pcDevice = nullptr;
            emit pcDeviceChanged();
            requestPreview();
        });
    }

    emit pcDeviceChanged();
    requestPreview();
}

QImage PcTimelinePreviewGenerator::previewImage() const
{
    return m_previewImage;
}

QUrl PcTimelinePreviewGenerator::previewUrl() const
{
    return m_previewUrl;
}

qint64 PcTimelinePreviewGenerator::previewTimeMs() const
{
    return m_previewTimeMs;
}

QString PcTimelinePreviewGenerator::ffmpegProgram() const
{
    return m_ffmpegProgram;
}

void PcTimelinePreviewGenerator::setFfmpegProgram(const QString &program)
{
    const QString value = program.trimmed();
    if (value.isEmpty() || m_ffmpegProgram == value)
        return;

    m_ffmpegProgram = value;
    emit ffmpegProgramChanged();
    requestPreview();
}

bool PcTimelinePreviewGenerator::busy() const
{
    return m_busy;
}

QString PcTimelinePreviewGenerator::errorString() const
{
    return m_errorString;
}

void PcTimelinePreviewGenerator::refresh()
{
    requestPreview();
}

void PcTimelinePreviewGenerator::seek(qint64 timeMs)
{
    const qint64 normalizedTimeMs = qMax<qint64>(0, timeMs);
    if (m_requestedTimeMs == normalizedTimeMs)
        return;

    m_requestedTimeMs = normalizedTimeMs;
    requestPreview();
}

void PcTimelinePreviewGenerator::requestPreview()
{
    if (!isActive())
        return;
    ++m_revision;
    if (!m_busy && !m_refreshTimer.isActive())
        m_refreshTimer.start();
}

bool PcTimelinePreviewGenerator::isActive() const
{
    return m_timelineManager
        && m_timelineManager->playbackState() == TimelineManager::Stopped
        && m_shellController
        && m_shellController->activeNavigationKey() == kTimelineDrawerKey;
}

void PcTimelinePreviewGenerator::updateCurrentTimeline()
{
    TimelineCommandModel *commandModel = m_timelineManager
        && m_timelineManager->currentTimeline()
        ? m_timelineManager->currentTimeline()->commandModel()
        : nullptr;
    if (m_timelineCommandModel == commandModel)
        return;

    if (m_timelineCommandModel)
        disconnect(m_timelineCommandModel, nullptr, this, nullptr);
    m_generationRevision = -1;
    emit cancelRequested();
    m_timelineCommandModel = commandModel;
    if (m_timelineCommandModel) {
        connect(m_timelineCommandModel, &TimelineCommandModel::commandsChanged,
                this, &PcTimelinePreviewGenerator::requestPreview);
    }
    m_requestedTimeMs = 0;
    requestPreview();
}

void PcTimelinePreviewGenerator::updateActiveState()
{
    if (isActive()) {
        requestPreview();
        return;
    }

    ++m_revision;
    m_refreshTimer.stop();
    m_generationRevision = -1;
    emit cancelRequested();
}

void PcTimelinePreviewGenerator::startPreview()
{
    if (m_busy || !isActive())
        return;
    m_generationRevision = m_revision;
    m_generationTimeMs = m_requestedTimeMs;
    if (!m_pcDevice || !m_timelineCommandModel) {
        m_previewImage = QImage();
        if (m_previewUrl.toLocalFile().isEmpty() == false) {
            QFile::remove(m_previewUrl.toLocalFile());
        }
        m_previewUrl = QUrl();
        m_previewTimeMs = m_generationTimeMs;
        setErrorString(QString());
        emit previewChanged();
        emit previewReady(m_previewImage, m_previewTimeMs);
        return;
    }

    const QVariantMap config = m_pcDevice->configValues();
    int width = config.value(DeviceKey::VirtualScreenWidth).toInt();
    int height = config.value(DeviceKey::VirtualScreenHeight).toInt();
    if (width <= 0)
        width = config.value(DeviceKey::ScreenWidth, 1920).toInt()
            * qMax(1, config.value(DeviceKey::ScreenColumns, 1).toInt());
    if (height <= 0)
        height = config.value(DeviceKey::ScreenHeight, 1080).toInt()
            * qMax(1, config.value(DeviceKey::ScreenRows, 1).toInt());

    const QSize canvasSize(qMax(1, width), qMax(1, height));
    QVector<VideoState> videoStates = PcVideoStateCalculator::stateAt(
        m_timelineCommandModel->commands(), m_pcDevice->id(), m_generationTimeMs).videos;
    for (int index = videoStates.size() - 1; index >= 0; --index) {
        VideoState &state = videoStates[index];
        state.windowRect = state.windowRect.intersected(QRect(QPoint(), canvasSize));
        if (state.windowRect.isEmpty())
            videoStates.removeAt(index);
    }
    setBusy(true);
    emit previewRequested(videoStates, canvasSize, m_ffmpegProgram, m_generationRevision);
}

void PcTimelinePreviewWorker::startPreview(const QVector<VideoState> &videoStates, const QSize &canvasSize,
                                          const QString &ffmpegProgram, int revision)
{
    m_revision = revision;
    m_videoStates = videoStates;
    m_ffmpegProgram = ffmpegProgram;
    m_canvas = QImage(canvasSize, QImage::Format_RGB32);
    m_canvas.fill(Qt::black);
    m_errors.clear();
    m_frameIndex = 0;
    startNextFrame();
}

void PcTimelinePreviewWorker::cancel()
{
    if (m_revision < 0)
        return;
    m_framePending = false;
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
        m_process.waitForFinished(-1);
    }
    emit finished(QImage(), QUrl(), QString(), m_revision);
    m_revision = -1;
}

void PcTimelinePreviewWorker::startNextFrame()
{
    if (m_frameIndex >= m_videoStates.size()) {
        finishPreview();
        return;
    }
    if (!m_temporaryDir.isValid()) {
        m_errors.append(tr("无法创建预览临时目录"));
        finishPreview();
        return;
    }

    const VideoState &state = m_videoStates.at(m_frameIndex);
    const QString outputPath = m_temporaryDir.filePath(QStringLiteral("frame.jpg"));
    if (!outputPath.isEmpty()) {
        QFile::remove(outputPath);
    }
    m_framePending = true;
    m_process.start(m_ffmpegProgram,
                    QStringList{QStringLiteral("-ss"),
                                QString::number(static_cast<double>(state.positionMs) / 1000.0, 'f', 3),
                                QStringLiteral("-i"),
                                state.source,
                                QStringLiteral("-frames:v"),
                                QStringLiteral("1"),
                                QStringLiteral("-an"),
                                QStringLiteral("-sn"),
                                QStringLiteral("-y"),
                                outputPath});
}

void PcTimelinePreviewWorker::completeFrame(bool success, const QString &errorMessage)
{
    if (!m_framePending)
        return;
    m_framePending = false;

    const QString outputPath = m_temporaryDir.filePath(QStringLiteral("frame.jpg"));
    const QImage frame(success ? outputPath : QString());
    if (frame.isNull()) {
        const QString detail = errorMessage.isEmpty() ? tr("无法读取输出帧") : errorMessage;
        m_errors.append(QStringLiteral("%1: %2").arg(m_videoStates.at(m_frameIndex).source, detail));
    } else {
        QPainter painter(&m_canvas);
        painter.drawImage(m_videoStates.at(m_frameIndex).windowRect, frame);
    }

    ++m_frameIndex;
    startNextFrame();
}

void PcTimelinePreviewWorker::finishPreview()
{
    QImage image = m_canvas;
    if (image.width() > 1920 || image.height() > 1080)
        image = image.scaled(1920, 1080, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    const QString previewPath = m_temporaryDir.filePath(
        QStringLiteral("preview-%1.jpg").arg(m_revision));
    QUrl url;
    if (image.save(previewPath, "JPG", 90))
        url = QUrl::fromLocalFile(previewPath);
    else
        m_errors.append(tr("无法保存预览图像"));
    emit finished(image, url, m_errors.join(QLatin1Char('\n')), m_revision);
    m_revision = -1;
}

void PcTimelinePreviewGenerator::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void PcTimelinePreviewGenerator::setErrorString(const QString &errorString)
{
    if (m_errorString == errorString)
        return;
    m_errorString = errorString;
    emit errorStringChanged();
}

#include "PcTimelinePreviewGenerator.moc"
