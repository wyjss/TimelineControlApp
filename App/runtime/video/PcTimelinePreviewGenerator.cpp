#include "runtime/video/PcTimelinePreviewGenerator.h"

#include <algorithm>

#include <QFile>
#include <QPainter>

#include "devices/Device.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceModel.h"
#include "runtime/shell/AppShellController.h"
#include "timeline/TimelineCommand.h"
#include "timeline/TimelineController.h"


namespace {

const QString kExecutionInputFields = QStringLiteral("executionInputFields");
const QString kTimelineDrawerKey = QStringLiteral("timeline");

QString videoSource(const QVariant &value)
{
    QString source = value.toString().trimmed();
    if (source.startsWith(QLatin1Char('$')))
        source = DeviceConstants::LocalVideoPrefix + source.mid(1);
    return source;
}

QRect videoRect(const QVariant &value, const QSize &canvasSize)
{
    const QStringList parts = value.toString().split(QLatin1Char(','));
    if (parts.size() != 4)
        return QRect();

    int values[4];
    for (int index = 0; index < 4; ++index) {
        bool ok = false;
        values[index] = parts.at(index).trimmed().toInt(&ok);
        if (!ok)
            return QRect();
    }

    return QRect(values[0], values[1], values[2], values[3])
        .intersected(QRect(QPoint(), canvasSize));
}

} // namespace


PcTimelinePreviewGenerator::PcTimelinePreviewGenerator(TimelineController *timelineController,
                                                       TimelineCommandModel *timelineCommandModel,
                                                       DeviceModel *deviceModel,
                                                       EarthUI::AppShellController *shellController,
                                                       QObject *parent)
    : QObject(parent)
    , m_timelineController(timelineController)
    , m_timelineCommandModel(timelineCommandModel)
    , m_deviceModel(deviceModel)
    , m_shellController(shellController)
{
    m_refreshTimer.setInterval(80);
    m_refreshTimer.setSingleShot(true);
    connect(&m_refreshTimer, &QTimer::timeout, this, &PcTimelinePreviewGenerator::startPreview);

    if (m_timelineController)
        connect(m_timelineController, &TimelineController::currentTimeMsChanged,
                this, &PcTimelinePreviewGenerator::requestPreview);
    if (m_timelineController)
        connect(m_timelineController, &TimelineController::stateChanged,
                this, &PcTimelinePreviewGenerator::updateActiveState);
    if (m_timelineCommandModel)
        connect(m_timelineCommandModel, &TimelineCommandModel::commandsChanged,
                this, &PcTimelinePreviewGenerator::requestPreview);
    if (m_deviceModel)
        connect(m_deviceModel, &DeviceModel::currentDeviceChanged,
                this, &PcTimelinePreviewGenerator::updatePcDevice);
    if (m_shellController)
        connect(m_shellController, &EarthUI::AppShellController::activeDrawerKeyChanged,
                this, &PcTimelinePreviewGenerator::updateActiveState);

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

    updatePcDevice();
    updateActiveState();
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
    m_pcDevice = device;
    if (m_pcDevice) {
        connect(m_pcDevice, &Device::configValuesChanged,
                this, &PcTimelinePreviewGenerator::requestPreview);
        connect(m_pcDevice, &QObject::destroyed, this, [this]() {
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
    return m_timelineController
        && m_timelineController->state() == TimelineController::Stopped
        && m_shellController
        && m_shellController->activeDrawerKey() == kTimelineDrawerKey;
}

void PcTimelinePreviewGenerator::updateActiveState()
{
    if (isActive()) {
        requestPreview();
        return;
    }

    ++m_revision;
    m_refreshTimer.stop();
    m_framePending = false;
    if (m_process.state() != QProcess::NotRunning)
        m_process.kill();
    setBusy(false);
}

void PcTimelinePreviewGenerator::startPreview()
{
    if (m_busy || !isActive())
        return;
    if (m_process.state() != QProcess::NotRunning) {
        m_refreshTimer.start();
        return;
    }

    m_generationRevision = m_revision;
    m_generationTimeMs = m_timelineController ? m_timelineController->currentTimeMs() : 0;
    if (!m_pcDevice || !m_timelineCommandModel) {
        m_previewImage = QImage();
        QFile::remove(m_previewUrl.toLocalFile());
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
    m_videoStates = videoStatesAt(m_generationTimeMs, canvasSize);
    m_canvas = QImage(canvasSize, QImage::Format_RGB32);
    m_canvas.fill(Qt::black);
    m_errors.clear();
    m_frameIndex = 0;
    setBusy(true);
    startNextFrame();
}

QVector<PcTimelinePreviewGenerator::VideoState>
PcTimelinePreviewGenerator::videoStatesAt(qint64 timeMs, const QSize &canvasSize) const
{
    QList<TimelineCommand *> commands = m_timelineCommandModel->commands();
    std::stable_sort(commands.begin(), commands.end(), [](TimelineCommand *left, TimelineCommand *right) {
        return left && right ? left->startTimeMs() < right->startTimeMs() : right != nullptr;
    });

    QVector<VideoState> states;
    const QString deviceId = m_pcDevice->id();
    const auto advance = [](VideoState &state, qint64 eventTimeMs) {
        if (state.playing)
            state.positionMs += qMax<qint64>(0, eventTimeMs - state.changedAtMs);
        state.changedAtMs = eventTimeMs;
    };

    for (TimelineCommand *command : commands) {
        if (!command || command->targetDeviceId() != deviceId || command->startTimeMs() > timeMs)
            continue;

        const QVariantMap params = command->commandParams();
        const QString commandType = params.value(DeviceKey::CommandType).toString();
        const QVariantMap input = params.value(kExecutionInputFields).toMap();
        const QString source = videoSource(input.value(DeviceKey::VideoFile));
        const qint64 eventTimeMs = command->startTimeMs();

        if (commandType == QStringLiteral("openVideo")) {
            if (source.isEmpty())
                continue;
            for (int index = states.size() - 1; index >= 0; --index) {
                if (states.at(index).source == source)
                    states.removeAt(index);
            }
            const QRect rect = videoRect(input.value(DeviceKey::Rect), canvasSize);
            if (!rect.isEmpty())
                states.append(VideoState{source, rect, 0, eventTimeMs, input.value(QStringLiteral("play"), true).toBool()});
            continue;
        }

        if (commandType == QStringLiteral("closePlayer")) {
            states.clear();
            continue;
        }

        if (commandType == QStringLiteral("closeVideo")) {
            if (source.isEmpty()) {
                states.clear();
            } else {
                for (int index = states.size() - 1; index >= 0; --index) {
                    if (states.at(index).source == source)
                        states.removeAt(index);
                }
            }
            continue;
        }

        const bool play = commandType == QStringLiteral("playVideo");
        if (!play && commandType != QStringLiteral("pauseVideo"))
            continue;
        for (VideoState &state : states) {
            if (!source.isEmpty() && state.source != source)
                continue;
            advance(state, eventTimeMs);
            state.playing = play;
        }
    }

    for (VideoState &state : states)
        advance(state, timeMs);
    return states;
}

void PcTimelinePreviewGenerator::startNextFrame()
{
    if (!isActive()) {
        finishPreview();
        return;
    }
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
    QFile::remove(outputPath);
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

void PcTimelinePreviewGenerator::completeFrame(bool success, const QString &errorMessage)
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
        painter.drawImage(m_videoStates.at(m_frameIndex).rect, frame);
    }

    ++m_frameIndex;
    startNextFrame();
}

void PcTimelinePreviewGenerator::finishPreview()
{
    if (isActive()) {
        m_previewImage = m_canvas;
        const QString previewPath = m_temporaryDir.filePath(
            QStringLiteral("preview-%1.jpg").arg(m_generationRevision));
        if (m_previewImage.save(previewPath, "JPG", 90)) {
			if (m_previewUrl.isEmpty() == false)
				QFile::remove(m_previewUrl.toLocalFile());
			m_previewUrl = QUrl::fromLocalFile(previewPath);
		} else {
			if (m_previewUrl.isEmpty() == false)
				QFile::remove(m_previewUrl.toLocalFile());
			m_previewUrl = QUrl();
            m_errors.append(tr("无法保存预览图像"));
        }
        m_previewTimeMs = m_generationTimeMs;
        setErrorString(m_errors.join(QLatin1Char('\n')));
        emit previewChanged();
        emit previewReady(m_previewImage, m_previewTimeMs);
    }

    setBusy(false);
    if (isActive() && m_generationRevision != m_revision && !m_refreshTimer.isActive())
        m_refreshTimer.start();
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
