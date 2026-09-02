#include "devices/DeviceTemplateModel.h"

#include "devices/DeviceConstants.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceCommand.h"
#include "devices/backends/Fusion3.h"
#include "devices/backends/Locator.h"
#include "devices/backends/PC.h"


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

    appendTemplate(new PcDeviceTemplate(this));
    appendTemplate(createDefaultDeviceTemplateDmx512Adapter());
    appendTemplate(createDefaultDeviceTemplateDmx512());
    appendTemplate(createDefaultDeviceTemplateHttp());
    appendTemplate(createDefaultDeviceTemplateSerial());
    appendTemplate(createDefaultDeviceTemplateOsc());
    appendTemplate(new Fusion3DeviceTemplate(this));
    appendTemplate(new LocatorDeviceTemplate(m_timelineModel, this));
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

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateDmx512Adapter()
{
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = DeviceParamSpec::createForKey(DeviceKey::SerialPort);
        spec->setLabel(QStringLiteral("适配器串口"));
        specs.push_back(spec);
    }

    {
        auto spec = DeviceParamSpec::createForKey(DeviceKey::Dmx512Bits);
        spec->setRequired(false);
        specs << spec;
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
        DeviceParamSpec::createForKey(DeviceKey::Dmx512AdapterDeviceId),
        DeviceParamSpec::createForKey(DeviceKey::Dmx512BitStart),
    };

    const QList<DeviceParamSpec*> cmds = {

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
	commands << DeviceCommand::createForProtocol(DeviceProtocol::Osc, nullptr);


    return makeDeviceTemplate(tr("OSC协议"),
                              QString(""),
                              QStringList{DeviceProtocol::Osc},
                              tr("OSC协议设备"),
                              params,
                              commands);
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

