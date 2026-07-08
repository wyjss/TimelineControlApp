#include "devices/DeviceTemplateModel.h"

#include "devices/DeviceConstants.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceCommandFactory.h"
#include "devices/DeviceCommandExecutionParamUpdater.h"

using namespace TimelineControl;

DeviceTemplateModel::DeviceTemplateModel(QObject *parent)
    : TypedListModel<DeviceTemplate *>(parent)
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
    QList<DeviceParamSpec *> specs;
    {
        

        auto *spec = new DeviceParamSpec(DeviceKey::Ip,
                                         QStringLiteral("IP"),
                                         QString(),
                                         DeviceParamSpec::StringType);
        spec->setPattern(DevicePattern::Ip);
        spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
        specs.push_back(spec);
    }
    {
        auto *spec = new DeviceParamSpec(DeviceKey::ScreenWidth,
                                         QStringLiteral("单屏宽度"),
                                         1920,
                                         DeviceParamSpec::IntType,
                                         DeviceParamSpec::TextEditor);
        spec->setMinimum(1);
        spec->setMaximum(16384);
        specs.push_back(spec);
    }
    {
        auto *spec = new DeviceParamSpec(DeviceKey::ScreenHeight,
                                         QStringLiteral("单屏高度"),
                                         1080,
                                         DeviceParamSpec::IntType,
                                         DeviceParamSpec::TextEditor);
        spec->setMinimum(1);
        spec->setMaximum(16384);
        specs.push_back(spec);
    }
    {
        auto *spec = new DeviceParamSpec(DeviceKey::ScreenColumns,
                                         QStringLiteral("屏幕列数"),
                                         1,
                                         DeviceParamSpec::IntType,
                                         DeviceParamSpec::TextEditor);
        spec->setMinimum(1);
        spec->setMaximum(64);
        specs.push_back(spec);
    }
    {
        auto *spec = new DeviceParamSpec(DeviceKey::ScreenRows,
                                         QStringLiteral("屏幕行数"),
                                         1,
                                         DeviceParamSpec::IntType,
                                         DeviceParamSpec::TextEditor);
        spec->setMinimum(1);
        spec->setMaximum(64);
        specs.push_back(spec);
    }

	QList<DeviceCommand*> commands;
	{
		DeviceCommand* cmd = DeviceCommandFactory::createForProtocol(DeviceProtocol::Pc, nullptr);
		cmd->setName("开始播放");
		cmd->getField(DeviceKey::ApiPath)->setValue("/video/play");
		commands.push_back(cmd);
	}
	{
		DeviceCommand* cmd = DeviceCommandFactory::createForProtocol(DeviceProtocol::Pc, nullptr);
		cmd->setName("暂停播放");
		cmd->getField(DeviceKey::ApiPath)->setValue("/video/pause");
		commands.push_back(cmd);
	}
	{
		DeviceCommand* cmd = DeviceCommandFactory::createForProtocol(DeviceProtocol::Pc, nullptr);
		cmd->setName("停止播放");
		cmd->getField(DeviceKey::ApiPath)->setValue("/video/stop");
		commands.push_back(cmd);
	}
	{
		DeviceCommand* cmd = DeviceCommandFactory::createForProtocol(DeviceProtocol::Pc, nullptr);
		cmd->setName("播放全景视频");
		cmd->setExecutionParamUpdaterName(DeviceCommandExecutionParamUpdaterName::PcPlayDomeVideo);
		commands.push_back(cmd);
	}

    return makeDeviceTemplate(tr("电脑"),
                              DeviceType::PC,
                              QStringList{DeviceProtocol::Pc},
                              tr("电脑设备"),
                              specs,
                              commands);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateDmx512Adapter()
{
    QList<DeviceParamSpec *> specs;
    {
        QVariantList opts;
        for (int i = 0; i < 10; ++i)
            opts.push_back(QStringLiteral("COM%1").arg(i));

        auto *spec = new DeviceParamSpec(DeviceKey::SerialPort,
                                         QStringLiteral("适配器串口"),
                                         QStringLiteral("COM0"),
                                         DeviceParamSpec::SelectType,
                                         DeviceParamSpec::SelectEditor);
        spec->setRequired(true);
        spec->setOptions(opts);
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
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = new DeviceParamSpec(DeviceKey::Dmx512AdapterDeviceId,
                                         QStringLiteral("目标DMX512适配器"),
                                         QString(),
                                         DeviceParamSpec::SelectType,
                                         DeviceParamSpec::SelectEditor);
        spec->setRequired(true);
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("DMX512协议"),
                              QString(),
                              QStringList{DeviceProtocol::Dmx512},
                              tr("DMX512协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateHttp()
{
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = new DeviceParamSpec(DeviceKey::Ip,
                                         QStringLiteral("IP"),
                                         QString(),
                                         DeviceParamSpec::StringType,
                                         DeviceParamSpec::TextEditor);
        spec->setPattern(DevicePattern::Ip);
        spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
        specs.push_back(spec);
    }
    {
        auto *spec = new DeviceParamSpec(DeviceKey::IpPort,
                                         QStringLiteral("端口"),
                                         8080,
                                         DeviceParamSpec::IntType,
                                         DeviceParamSpec::TextEditor);
        spec->setRequired(true);
        spec->setMinimum(1);
        spec->setMaximum(65535);
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("HTTP协议"),
                              QString(),
                              QStringList{DeviceProtocol::Http},
                              tr("HTTP协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateSerial()
{
    QList<DeviceParamSpec *> specs;
    {
        QVariantList opts;
        for (int i = 0; i < 10; ++i)
            opts.push_back(QStringLiteral("COM%1").arg(i));

        auto *spec = new DeviceParamSpec(DeviceKey::SerialPort,
                                         QStringLiteral("串口"),
                                         QStringLiteral("COM0"),
                                         DeviceParamSpec::SelectType,
                                         DeviceParamSpec::SelectEditor);
        spec->setRequired(true);
        spec->setOptions(opts);
        specs.push_back(spec);
    }

    {
        auto *spec = new DeviceParamSpec(DeviceKey::BaudRate,
                                         QStringLiteral("波特率"),
                                         9600,
                                         DeviceParamSpec::IntType,
                                         DeviceParamSpec::SelectEditor);
        spec->setRequired(true);
        spec->setMinimum(1);
        spec->setMaximum(4000000);
        spec->setOptions(QVariantList{9600, 19200, 38400, 57600, 115200});
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("串口协议"),
                              QString(),
                              QStringList{DeviceProtocol::Serial},
                              tr("串口协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateOsc()
{
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = new DeviceParamSpec(DeviceKey::Ip,
                                         QStringLiteral("IP"),
                                         QString(),
                                         DeviceParamSpec::StringType,
                                         DeviceParamSpec::TextEditor);
        spec->setPattern(DevicePattern::Ip);
        spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
        specs.push_back(spec);
    }

    {
        auto *spec = new DeviceParamSpec(DeviceKey::Port,
                                         QStringLiteral("端口"),
                                         8000,
                                         DeviceParamSpec::IntType,
                                         DeviceParamSpec::TextEditor);
        spec->setRequired(true);
        spec->setMinimum(1);
        spec->setMaximum(65535);
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("OSC协议"),
                              QString(),
                              QStringList{DeviceProtocol::Osc},
                              tr("OSC协议设备"),
                              specs);
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

