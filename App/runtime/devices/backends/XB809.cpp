#include "devices/backends/XB809.h"

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include "runtime/utils.h"

#define LC "[XB809] "
#include "LogMacros.h"
namespace {
    class BaseXB809Command : public DeviceCommand_Udp
    {
    public:
        BaseXB809Command(const QString& name, const QString& payloadTemplate)
            : DeviceCommand_Udp(DeviceProtocol::Udp, name, "", nullptr)
        {
            // 修改输入类型
            getField(DeviceKey::Payload)->setValue(payloadTemplate);
            getField(DeviceKey::PayloadType)->setValue(DeviceKey::PayloadType_Hex);

            setStringTemplateKey(DeviceKey::Payload);
        }

        virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
        {
            auto params = DeviceCommand_Udp::resolvedParams(executionInputValues);
            auto payload = params[DeviceKey::Payload].toString();
            QByteArray data;
            if (!Utils::toHexData(payload, &data)) {
                LOG_FATAL("16进制处理失败" << payload);
                exit(0);
            }

            // 计算校验码
            uint32_t sum = 0;
            for (int i = 0; i < data.size(); i++) {
                uint8_t v = *(const uint8_t*)(data.constData() + i);
                sum += v;
            }
            
            uint8_t v1 = sum / 256;
            uint8_t v2 = sum % 256;

            // 追加
            payload += Utils::toHex(v1);
            payload += Utils::toHex(v2);

            // 回写覆盖
            params[DeviceKey::Payload] = payload;

            
            return params;
        }
    };

QList<DeviceParamSpec *> createXB809Params()
{
    auto *port = DeviceParamSpec::createForKey(DeviceKey::Port);
    port->setValue(55577);
    port->setDefaultValue(55577);
    return {port};
}

} // namespace

XB809DeviceTemplate::XB809DeviceTemplate(QObject *parent)
    : DeviceTemplate(QStringLiteral("XB809"),
                     DeviceType::XB809,
                     QStringList{DeviceProtocol::Udp},
                     QStringLiteral("XB809控制"),
                     createXB809Params(),
                     {},
                     parent)
{
    
}

Device* XB809DeviceTemplate::createDevice(QObject* parent, const QVariantMap& configValues)
{
    auto device = DeviceTemplate::createDevice(parent, configValues);
    
	{// 暂停播放	3c 6b 7c 8d  	11 00 00 00
		auto cmd = new BaseXB809Command("暂停播放", "3c6b7c8d11000000");
        device->appendCommand(cmd);
	}
	{// 继续播放	3c 6b 7c 8d 	22 00 00 00
		auto cmd = new BaseXB809Command("继续播放", "3c6b7c8d22000000");
        device->appendCommand(cmd);
	}
	{// 播放指定节目	3c 6b 7c 8d  	33 x1 00 00 (注2)
		auto cmd = new BaseXB809Command("播放指定节目", "3c6b7c8d33${index}0000");

		auto param = new DeviceParamSpec("index", "节目索引", 0, DeviceParamSpec::IntType);
		param->setMinimum(0);
		param->setMaximum(0x1f);
		cmd->addExecutionInputField(param);

        device->appendCommand(cmd);
	}
	{// 恢复定时播放	3c 6b 7c 8d  	44 00 00 00
		auto cmd = new BaseXB809Command("恢复定时播放", "3c6b7c8d44000000");
        device->appendCommand(cmd);
	}
	{// 调节速度	3c 6b 7c 8d  	55 x2 00 00 (注3)
		auto cmd = new BaseXB809Command("调节速度", "3c6b7c8d55${spd}0000");

		auto param = new DeviceParamSpec("spd", "速度等级", 0, DeviceParamSpec::IntType);
		param->setMinimum(0);
		param->setMaximum(0x0f);
		cmd->addExecutionInputField(param);

        device->appendCommand(cmd);
	}
	{// 循环/不循环 播放	3c 6b 7c 8d  	66 x3 00 00 (注4)
		auto cmd = new BaseXB809Command("关闭循环", "3c6b7c8d66000000");
        device->appendCommand(cmd);

		cmd = new BaseXB809Command("打开循环", "3c6b7c8d66550000");
        device->appendCommand(cmd);
	}
	{// 保存当前设置	3c 6b 7c 8d  	77 00 00 00
		auto cmd = new BaseXB809Command("保存当前设置", "3c6b7c8d77000000");
        device->appendCommand(cmd);
	}

    return device;
}