#include "devices/backends/LMI.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "runtime/utils.h"

#define LC "[LMI] "
#include "LogMacros.h"
namespace {
    class BaseLMICommand : public DeviceCommand_Udp
    {
    public:
        BaseLMICommand(const QString& name, const QString& payloadTemplate)
            : DeviceCommand_Udp(DeviceProtocol::Udp, name, "", nullptr)
        {
            // 修改输入类型
            getField(DeviceKey::Payload)->setValue(payloadTemplate);
            setStringTemplateKey(DeviceKey::Payload);
        }
    };

	class BaseLMIIndexCommand : public DeviceCommand_Udp
	{
	public:
		BaseLMIIndexCommand(const QString& name, const QString& payloadTemplate)
			: DeviceCommand_Udp(DeviceProtocol::Udp, name, "", nullptr)
		{
			// 修改输入类型
			getField(DeviceKey::Payload)->setValue(payloadTemplate);
			setStringTemplateKey(DeviceKey::Payload);

		}

		virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
		{
			auto params = DeviceCommand_Udp::resolvedParams(executionInputValues);

			auto sIdx = params["index"].toString();
			if (sIdx.size() == 1) {
				sIdx.insert(0, "0");
			}
			params[DeviceKey::Payload] =
				params[DeviceKey::Payload].toString() + sIdx;
			return params;
		}
	};

} // namespace

LMIDeviceTemplate::LMIDeviceTemplate(QObject *parent)
    : DeviceTemplate(QStringLiteral("LMI"),
                     DeviceType::LMI,
                     QStringList{DeviceProtocol::Udp},
                     QStringLiteral("基于UDP协议的LMI水幕设备"),
                     {},
                     {},
                     parent)
{
    
}

Device* LMIDeviceTemplate::createDevice(QObject* parent, const QVariantMap& configValues)
{
    auto device = DeviceTemplate::createDevice(parent, configValues);
    
	{// 播放第1个节目	bf01	bf01ok
		// 不加${index}，方便在BaseLMIIndexCommand中进行补位
		auto cmd = new BaseLMIIndexCommand("播放节目", "bf");

		auto param = new DeviceParamSpec("index", "节目索引", 1, DeviceParamSpec::IntType);
		param->setMinimum(1);
		param->setMaximum(99);
		param->setSubtitle("第几个节目");
		cmd->addExecutionInputField(param);

		device->appendCommand(cmd);
    }

	{// 停止播放	stop	stopok
		auto cmd = new BaseLMICommand("停止播放", "stop");
		device->appendCommand(cmd);
	}

	{// 打开灯电源	kd00
		auto cmd = new BaseLMICommand("打开灯电源", "kd00");
		device->appendCommand(cmd);
	}

	{// 关闭灯电源	gd00
		auto cmd = new BaseLMICommand("关闭灯电源", "gd00");
		device->appendCommand(cmd);
	}

	{// 清单循环	xh00
		auto cmd = new BaseLMICommand("清单循环", "xh00");
		device->appendCommand(cmd);
	}

	{// 清单不循环	xh01
		auto cmd = new BaseLMICommand("清单不循环", "xh01");
		device->appendCommand(cmd);
	}

	{// 单曲循环	xh02
		auto cmd = new BaseLMICommand("单曲循环", "xh02");
		device->appendCommand(cmd);
	}

	{// 单曲不循环	xh03
		auto cmd = new BaseLMICommand("单曲不循环", "xh03");
		device->appendCommand(cmd);
	}

	{// 导入节目组1	dr01
		auto cmd = new BaseLMIIndexCommand("导入节目组", "dr");

		auto param = new DeviceParamSpec("index", "节目组索引", 1, DeviceParamSpec::IntType);
		param->setMinimum(1);
		param->setMaximum(99);
		param->setSubtitle("第几个节目组");
		cmd->addExecutionInputField(param);

		device->appendCommand(cmd);
	}

    return device;
}