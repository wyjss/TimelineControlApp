#include "devices/backends/Lighting.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "runtime/utils.h"

#define LC "[Lighting] "
#include "LogMacros.h"
namespace {
    class BaseLightingCommand : public DeviceCommand_Udp
    {
    public:
        BaseLightingCommand(const QString& name, const QString& payloade)
            : DeviceCommand_Udp(DeviceProtocol::Udp, name, "", nullptr)
        {
            getField(DeviceKey::Payload)->setValue(payloade);
            getField(DeviceKey::PayloadType)->setValue(DeviceKey::PayloadType_Hex);
        }
    };

} // namespace

LightingDeviceTemplate::LightingDeviceTemplate(QObject *parent)
    : DeviceTemplate(QStringLiteral("Lighting"),
                     DeviceType::Lighting,
                     QStringList{DeviceProtocol::Udp},
                     QStringLiteral("基于UDP协议的灯控设备水幕设备"),
                     {},
                     {},
                     parent)
{
    
}

Device* LightingDeviceTemplate::createDevice(QObject* parent, const QVariantMap& configValues)
{
    auto device = DeviceTemplate::createDevice(parent, configValues);
    
	// order-name
	QStringList strs =
	{
			"474D41004D5343001E000000F07F7F027F0701","篇章一星汉歌（凤镜船）",
			"474D41004D5343001E000000F07F7F027F0702","篇章二大汉赋（西城阁）",
			"474D41004D5343001E000000F07F7F027F0703","篇章三汉字序（亲水广场）",
			"474D41004D5343001E000000F07F7F027F0704","篇章四知音曲4.5灯光秀（汉江一桥下游）",
			"474D41004D5343001E000000F07F7F027F0705","篇章四知音曲（安澜公园）",
			"474D41004D5343001E000000F07F7F027F0706","篇章五龙舟风5.5灯光秀（汉江三桥）",
			"474D41004D5343001E000000F07F7F027F0707","篇章五龙舟风（龙舟文化园）",
			"474D41004D5343001E000000F07F7F027F0708","篇章六织锦谣6.5灯光秀（汉江一桥上游）",
			"474D41004D5343001E000000F07F7F027F0709","篇章六织锦谣（防汛纪念馆）",
			"474D41004D5343001E000000F07F7F027F0710","篇章六织锦谣（水西门）",
			"474D41004D5343001E000000F07F7F027F0711","篇章七长歌行",
			"474D41004D5343001E000000F07F7F027F0712","篇章七长歌行",
			"474D41004D5343001E000000F07F7F027F0713","篇章八朱鹮引",
			"474D41004D5343001E000000F07F7F027F0714","篇章九安康颂",
			"474D41004D5343001E000000F07F7F027F0715","日常",
			"474D41004D5343001E000000F07F7F027F0716","关闭所有",
			"474D41004D5343001E000000F07F7F027F0717","备用"
	};
	for (int i = 0; i < strs.size(); i += 2) {
		auto cmd = new BaseLightingCommand(strs[i + 1], strs[i]);
		device->appendCommand(cmd);
	}

    return device;
}