#include "devices/DeviceTemplateModel.h"

#include "devices/DeviceConstants.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceCommandFactory.h"


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
        DeviceParamSpec::createForKey(DeviceKey::ScreenWidth),
        DeviceParamSpec::createForKey(DeviceKey::ScreenHeight),
        DeviceParamSpec::createForKey(DeviceKey::ScreenColumns),
        DeviceParamSpec::createForKey(DeviceKey::ScreenRows)
    };

	QList<DeviceCommand*> commands;

    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "playVideo", nullptr);
    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "pauseVideo", nullptr);
    commands << DeviceCommandFactory::create(DeviceProtocol::Pc, "stopVideo", nullptr);

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
    auto *portSpec = DeviceParamSpec::createForKey(DeviceKey::Port);
    portSpec->setValue(8000);
    portSpec->setDefaultValue(8000);

    return makeDeviceTemplate(tr("OSC协议"),
                              QString(),
                              QStringList{DeviceProtocol::Osc},
                              tr("OSC协议设备"),
                              {portSpec});
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

