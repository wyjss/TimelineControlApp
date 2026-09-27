#include "devices/backends/GF_T.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "runtime/utils.h"

#define LC "[LMI] "
#include "LogMacros.h"
namespace {
    class BaseGFTCommand : public DeviceCommand_Udp
    {
    public:
        BaseGFTCommand(const QString& name, const QString& payloadTemplate)
            : DeviceCommand_Udp(DeviceProtocol::Udp, name, "", nullptr)
        {
            getField(DeviceKey::Payload)->setValue(payloadTemplate);
			getField(DeviceKey::PayloadType)->setValue(DeviceKey::PayloadType_Hex);
        }
    };
} // namespace

GFTDeviceTemplate::GFTDeviceTemplate(QObject *parent)
    : DeviceTemplate("光峰T投影机",
                     DeviceType::Projector,
                     QStringList{DeviceProtocol::Udp},
                     QStringLiteral("基于UDP协议的光峰T系列投影机"),
                     {},
                     {},
                     parent)
{
    
}

Device* GFTDeviceTemplate::createDevice(QObject* parent, const QVariantMap& configValues)
{
    auto device = DeviceTemplate::createDevice(parent, configValues);
    
	{// 开机（网络待机）	EF FE 01 01 01 01 00 00 00 00 01 00 00 00 08 11 00 00 22 2B 41 54 2B 53 79 73 74 65 6D 3D 4F 6E 0D 0A
	
		QString payload = "EF FE 01 01 01 01 00 00 00 00 01 00 00 00 08 11 00 00 22 2B 41 54 2B 53 79 73 74 65 6D 3D 4F 6E 0D 0A";
		payload = payload.remove(" ");
		auto cmd = new BaseGFTCommand("开机（网络待机）", payload);

		device->appendCommand(cmd);
    }

	{// 关机	EF FE 01 01 01 01 00 00 00 00 01 01 00 00 08 11 00 00 23 45 41 54 2B 53 79 73 74 65 6D 3D 4F 66 66 0D 0A
		QString payload = "EF FE 01 01 01 01 00 00 00 00 01 01 00 00 08 11 00 00 23 45 41 54 2B 53 79 73 74 65 6D 3D 4F 66 66 0D 0A";
		payload = payload.remove(" ");
		auto cmd = new BaseGFTCommand("关机", payload);
		device->appendCommand(cmd);
	}

    return device;
}