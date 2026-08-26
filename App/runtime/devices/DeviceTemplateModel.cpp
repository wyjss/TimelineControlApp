#include "devices/DeviceTemplateModel.h"

#include "devices/DeviceConstants.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceCommandFactory.h"


DeviceTemplateModel::DeviceTemplateModel(TimelineModel *timelineModel,
                                         QObject *parent)
    : TypedListModel<DeviceTemplate *>(parent)
    , m_timelineModel(timelineModel)
{
}

void DeviceTemplateModel::loadDefaultTemplates()
{
    if (!items().isEmpty())
        return;

    appendTemplate(createDefaultDeviceTemplatePc());
    appendTemplate(createDefaultDeviceTemplateDmx512Adapter());
    appendTemplate(createDefaultDeviceTemplateDmx512());
    appendTemplate(createDefaultDeviceTemplateHttp());
    appendTemplate(createDefaultDeviceTemplateSerial());
    appendTemplate(createDefaultDeviceTemplateOsc());
    appendTemplate(createDefaultDeviceTemplateFusion3());
    appendTemplate(createDefaultDeviceTemplateLocator());
    appendTemplate(new SerialPowerDeviceTemplate);
}

QVariantList DeviceTemplateModel::templates() const
{
    QVariantList result;
    const QList<DeviceTemplate *> currentItems = items();
    result.reserve(currentItems.size());

    for (DeviceTemplate *deviceTemplate : currentItems)
        result.append(QVariant::fromValue(deviceTemplate));

    return result;
}

DeviceTemplate *DeviceTemplateModel::templateAt(int row) const
{
    return itemAt(row);
}

DeviceTemplate *DeviceTemplateModel::templateByName(const QString &templateName) const
{
    const int row = indexOfTemplateName(templateName);
    return templateAt(row);
}

int DeviceTemplateModel::indexOfTemplate(DeviceTemplate *deviceTemplate) const
{
    return deviceTemplate ? indexOfItem(deviceTemplate) : -1;
}

int DeviceTemplateModel::indexOfTemplateName(const QString &templateName) const
{
    const QString normalizedTemplateName = templateName.trimmed();
    if (normalizedTemplateName.isEmpty())
        return -1;

    const QList<DeviceTemplate *> currentItems = items();
    for (int row = 0; row < currentItems.size(); ++row) {
        DeviceTemplate *deviceTemplate = currentItems.at(row);
        if (deviceTemplate && deviceTemplate->name() == normalizedTemplateName)
            return row;
    }

    return -1;
}

void DeviceTemplateModel::appendTemplate(DeviceTemplate *deviceTemplate)
{
    if (!deviceTemplate
        || indexOfTemplate(deviceTemplate) >= 0
        || indexOfTemplateName(deviceTemplate->name()) >= 0) {
        return;
    }

    if (appendItem(deviceTemplate))
        emit templatesChanged();
}

bool DeviceTemplateModel::acceptsItem(DeviceTemplate *deviceTemplate) const
{
    return deviceTemplate != nullptr;
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplatePc()
{
    const QList<DeviceParamSpec *> specs{
        DeviceParamSpec::createForKey(DeviceKey::VirtualScreenWidth),
        DeviceParamSpec::createForKey(DeviceKey::VirtualScreenHeight),
        DeviceParamSpec::createForKey(DeviceKey::ScreenWidth),
        DeviceParamSpec::createForKey(DeviceKey::ScreenHeight),
        DeviceParamSpec::createForKey(DeviceKey::ScreenColumns),
        DeviceParamSpec::createForKey(DeviceKey::ScreenRows)
    };

	QList<DeviceCommand*> commands;

    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "openVideo", nullptr);
    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "playVideo", nullptr);
    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "pauseVideo", nullptr);
    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "closeVideo", nullptr);
    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "closePlayer", nullptr);

	{
		DeviceCommand* cmd = DeviceCommandFactory::create(DeviceProtocol::Pc,
													 QStringLiteral("playDomeVideo"));
		commands.push_back(cmd);
	}

    return makeDeviceTemplate(tr("电脑"),
                              DeviceType::PC,
                              QStringList{DeviceProtocol::Pc, DeviceProtocol::Http},
                              tr("电脑设备"),
                              specs,
                              commands);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateDmx512Adapter()
{
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = DeviceParamSpec::createForKey(DeviceKey::SerialPort);
        spec->setLabel(QStringLiteral("适配器串口"));
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("DMX512适配器"),
                              DeviceType::Dmx512Adapter,
                              QStringList{DeviceProtocol::Dmx512},
                              tr("DMX512适配器"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateDmx512()
{
    const QList<DeviceParamSpec *> specs{
        DeviceParamSpec::createForKey(DeviceKey::Dmx512AdapterDeviceId)
    };

    return makeDeviceTemplate(tr("DMX512协议"),
                              QString(),
                              QStringList{DeviceProtocol::Dmx512},
                              tr("DMX512协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateHttp()
{
    const QList<DeviceParamSpec *> specs{
        DeviceParamSpec::createForKey(DeviceKey::Port)
    };

    return makeDeviceTemplate(tr("HTTP协议"),
                              QString(),
                              QStringList{DeviceProtocol::Http},
                              tr("HTTP协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateSerial()
{
    const QList<DeviceParamSpec *> specs{
        DeviceParamSpec::createForKey(DeviceKey::SerialPort),
        DeviceParamSpec::createForKey(DeviceKey::BaudRate)
    };

    return makeDeviceTemplate(tr("串口协议"),
                              QString(),
                              QStringList{DeviceProtocol::Serial},
                              tr("串口协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateOsc()
{
    QList<DeviceParamSpec*> params;

    auto *portSpec = DeviceParamSpec::createForKey(DeviceKey::Port);
    portSpec->setValue(8000);
    portSpec->setDefaultValue(8000);
    params << portSpec;

    params << DeviceParamSpec::createForKey(DeviceKey::OscTransProtocol);

	QList<DeviceCommand*> commands;
	commands << DeviceCommandFactory::createForProtocol(DeviceProtocol::Osc, nullptr);


    return makeDeviceTemplate(tr("OSC协议"),
                              QString(""),
                              QStringList{DeviceProtocol::Osc},
                              tr("OSC协议设备"),
                              params,
                              commands);
}

namespace
{
	DeviceCommand* createFusionCommand(const QString& name,
									   const QString& strTemplate,
									   const QString& paramKey = "",
									   const QString& paramLabel = "",
									   const QVariant& v = {},
									   const double& minV = {},
									   const double& maxV = {}
	)
	{
		auto cmd = DeviceCommandFactory::createForProtocol(DeviceProtocol::Udp, nullptr);
		cmd->setName(name);

		cmd->setStringTemplateKey(DeviceKey::ApiPath);
		if (!paramKey.isEmpty()) {
			auto param = new DeviceParamSpec(paramKey, paramLabel, v);
			param->setMinimum(minV);
			param->setMaximum(maxV);
			cmd->addExecutionInputField(param);
		}
		return cmd;
	}

	QList< DeviceCommand*> createFusionCommands()
	{
		QList< DeviceCommand*> cmds;

		cmds << createFusionCommand("播放视频", R"({"_msg":"v_play","_p":"{videoIndex}"})", "videoIndex", "视频索引", 0, 99);
		cmds << createFusionCommand("暂停", R"({"_msg":"v_pause"})");
		cmds << createFusionCommand("继续", R"({"_msg":"v_resume"})");
		cmds << createFusionCommand("停止", R"({"_msg":"stop"})");
		cmds << createFusionCommand("上一曲", R"({"_msg":"v_prev"})");
		cmds << createFusionCommand("下一曲", R"({"_msg":"v_next"})");
		cmds << createFusionCommand("循环模式", R"({"_msg":"set_loop","_p":"{loopMode}"})", "loopMode", "循环模式", 0, 3);
		cmds << createFusionCommand("视频定位", R"({"_msg":"seek","_p":{sec}})", "sec", "秒", 0, 9999);
		cmds << createFusionCommand("前进10秒", R"({"_msg":"forward"})");
		cmds << createFusionCommand("后退10秒", R"({"_msg":"rewind"})");
		cmds << createFusionCommand("前进或者后退", R"({"_msg":"move","_p":"{sec}"})", "sec", "秒数", -999, 999);
		cmds << createFusionCommand("声音大小", R"({"_msg":"vol","_p":"{volume}"})", "volume", "音量", 0, 100);
		cmds << createFusionCommand("静音", R"({"_msg":"mute"})");
		cmds << createFusionCommand("取消静音", R"({"_msg":"un_mute"})");
		cmds << createFusionCommand("音量-", R"({"_msg":"vol-"})");
		cmds << createFusionCommand("音量+", R"({"_msg":"vol+"})");
		cmds << createFusionCommand("播放第几张图片", R"({"_msg":"p_play","_p":"{imageIndex}"})", "imageIndex", "图片索引", 0, 999);
		cmds << createFusionCommand("上一张", R"({"_msg":"p_prev"})");
		cmds << createFusionCommand("下一张", R"({"_msg":"p_next"})");
		cmds << createFusionCommand("播放第几个播单", R"({"_msg":"ls_index","_p":"{playIndex}"})", "playIndex", "播单索引", 0, 999);
		cmds << createFusionCommand("上一播单", R"({"_msg":"pl_prev"})");
		cmds << createFusionCommand("下一播单", R"({"_msg":"pl_next"})");
		cmds << createFusionCommand("选播单内曲目", R"({"_msg":"ls_sub","_p":"{index}"})", "index", "曲目索引", 0, 999);
		cmds << createFusionCommand("遮罩开", R"({"_msg":"show_mask","_p":"1"})");
		cmds << createFusionCommand("遮罩关", R"({"_msg":"show_mask","_p":"0"})");
		cmds << createFusionCommand("采集开", R"({"_msg":"show_capture","_p":"1"})");
		cmds << createFusionCommand("采集关", R"({"_msg":"show_capture","_p":"0"})");
		cmds << createFusionCommand("跑马灯开", R"({"_msg":"floating","_p":"1"})");
		cmds << createFusionCommand("跑马灯关", R"({"_msg":"floating","_p":"0"})");
		cmds << createFusionCommand("重启", R"({"_msg":"reboot"})");
		cmds << createFusionCommand("开机", R"({"_msg":"on"})");
		cmds << createFusionCommand("关机", R"({"_msg":"off"})");

		return cmds;
	}
}
DeviceTemplate* DeviceTemplateModel::createDefaultDeviceTemplateFusion3()
{
	QList<DeviceParamSpec*> params;

	auto* portSpec = DeviceParamSpec::createForKey(DeviceKey::Port);
	portSpec->setValue(9999);
	portSpec->setDefaultValue(9999);
	params << portSpec;

	return makeDeviceTemplate(tr("分布式融合器"),
                              DeviceType::Fusion3,
							  QStringList{DeviceProtocol::Udp},
							  tr("分布式融合器3.0设备"),
							  params,
                              createFusionCommands());
}

DeviceTemplate* DeviceTemplateModel::createDefaultDeviceTemplateLocator()
{
	QList<DeviceParamSpec*> params;

    auto cmd = DeviceCommandFactory::createForProtocol(DeviceProtocol::Internal);
    cmd->setName("节目触发");
	cmd->addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::Timeline,
														 m_timelineModel));
	return makeDeviceTemplate(tr("定位器"),
							  DeviceType::Locator,
							  QStringList{DeviceProtocol::Internal},
							  tr("定位器设备"),
							  params,
                              {cmd});
}

DeviceTemplate *DeviceTemplateModel::makeDeviceTemplate(const QString &name,
                                                        const QString &deviceType,
                                                        const QStringList &supportedProtocols,
                                                        const QString &description,
                                                        const QList<DeviceParamSpec *> &configSpecs,
                                                        const QList<DeviceCommand *> &commands)
{
    return new DeviceTemplate(name,
                              deviceType,
                              supportedProtocols,
                              description,
                              configSpecs,
                              commands,
                              this);
}

