#pragma once

#include <QString>
#include <QVariantMap>

namespace TimelineControl {

class DeviceCommand;

namespace DeviceCommandExecutionParamUpdaterName {
inline const QString PcPlayDomeVideo = QStringLiteral("pc.playDomeVideo");
}

namespace DeviceCommandExecutionParamUpdater {
void install(const QString &name, DeviceCommand *command);
void update(const QString &name, DeviceCommand *command, const QVariantMap &params);
}

} // namespace TimelineControl
