#include "devices/executors/DmxCommandExecutor.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "devices/Device.h"
#include "devices/DeviceModel.h"

#include "runtime/TimelineRuntime.h"

#define LC "[DmxCommandExecutor] "
#include "LogMacros.h"
#include <QUdpSocket>
#include <QTimer>
#include <QUrl>



DmxCommandExecutor::DmxCommandExecutor(const QString &ip, int port, QObject *parent)
    : DeviceCommandExecutor(parent)
    , m_ip(ip)
    , m_port(port)
{
}

void DmxCommandExecutor::executeImpl(const QString &executionId,
                                     DeviceCommand *command,
                                     const QVariantMap &params)
{
    auto bitStart = params[DeviceKey::Dmx512BitStart].toInt();
    auto bitOffset = params[DeviceKey::Dmx512BitOffset].toInt();
    auto bitStrs = params[DeviceKey::Dmx512CommandBits].toString().split(",", Qt::SkipEmptyParts);

    auto targetAdapterId = command->device()->getParam(DeviceKey::Dmx512AdapterDeviceId)->value().toString();
    
    auto adapter = TimelineRuntime::getInstance()->deviceModel()->deviceById(targetAdapterId);
    if (!adapter) {
        emit executionFinished(executionId, command, false, "没有找到目标DMX适配器");
        return;
    }
    auto vs = adapter->getParam(DeviceKey::Dmx512Bits)->value().value<QVector<int>>();

    for (int i = 0; i < bitStrs.size(); ++i) {
        int targetBit = bitStart + bitOffset + i;
        int value = bitStrs[i].toInt();

        if (targetBit >= 512) {
            emit executionFinished(executionId, command, false, "目标bit超出512范围");
            return;
        }
        vs[targetBit] = value;
    }
    adapter->getParam(DeviceKey::Dmx512Bits)->setValue(QVariant::fromValue(vs));
    emit executionFinished(executionId, command, true, "");
    
    LOG_WARN("@todo dmx适配器执行指令");
}
