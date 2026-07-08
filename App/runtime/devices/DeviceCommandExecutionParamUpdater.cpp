#include "devices/DeviceCommandExecutionParamUpdater.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include <QUrl>

using namespace TimelineControl;

namespace {

void installPcPlayDomeVideo(DeviceCommand *command)
{
    if (!command)
        return;

    auto *videoFileField = new DeviceParamSpec(QStringLiteral("videoFile"),
                                               QStringLiteral("视频文件"),
                                               QString(),
                                               DeviceParamSpec::StringType,
                                               DeviceParamSpec::TextEditor,
                                               command);
    videoFileField->setRequired(true);
    command->addExecutionInputField(videoFileField);
}

void updatePcPlayDomeVideo(DeviceCommand *command, const QVariantMap &params)
{
    const QString videoFile = params.value(QStringLiteral("videoFile")).toString().trimmed();
    if (!command || videoFile.isEmpty())
        return;

    if (DeviceParamSpec *pathField = command->getField(DeviceKey::ApiPath))
        pathField->setValue(QStringLiteral("/video/play?mode=dome&url=") + QString::fromLatin1(QUrl::toPercentEncoding(videoFile)));
}

} // namespace

void DeviceCommandExecutionParamUpdater::install(const QString &name, DeviceCommand *command)
{
    const QString updaterName = name.trimmed();
    if (updaterName == DeviceCommandExecutionParamUpdaterName::PcPlayDomeVideo)
        installPcPlayDomeVideo(command);
}

void DeviceCommandExecutionParamUpdater::update(const QString &name, DeviceCommand *command, const QVariantMap &params)
{
    const QString updaterName = name.trimmed();
    if (updaterName == DeviceCommandExecutionParamUpdaterName::PcPlayDomeVideo)
        updatePcPlayDomeVideo(command, params);
}
