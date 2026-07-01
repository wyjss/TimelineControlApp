#include "devices/DeviceTemplateModel.h"

#include <QSize>

#include "devices/DeviceConstants.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceCommand.h"

#include "devices/DeviceCommand_Http.h"

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
                                         QStringLiteral("ip"),
                                         QString(),
                                         DeviceParamSpec::StringType);
        spec->setPattern(DevicePattern::Ip);
        spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
        specs.push_back(spec);
    }
    {
        auto *spec = new DeviceParamSpec(DeviceKey::ScreenSize,
                                         QStringLiteral("单屏分辨率"),
                                         QSize(),
                                         DeviceParamSpec::SizeType,
                                         DeviceParamSpec::SizeEditor);
        spec->setRequired(false);
        specs.push_back(spec);
    }
    {
        auto *spec = new DeviceParamSpec(DeviceKey::ScreenLayout,
                                         QStringLiteral("屏幕布局"),
                                         QSize(1, 1),
                                         DeviceParamSpec::SizeType,
                                         DeviceParamSpec::SizeEditor);
        spec->setRequired(false);
        specs.push_back(spec);
    }

	QList<DeviceCommand*> commands;
    {
        DeviceCommand_Http* cmd = new DeviceCommand_Http(nullptr);
        cmd->setName("播放视频");
    }

    return makeDeviceTemplate(tr("电脑"),
                              DeviceType::PC,
                              DeviceProtocol::Pc,
                              tr("电脑设备"),
                              specs);
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

    return makeDeviceTemplate(tr("Dmx512适配器"),
                              DeviceType::Dmx512Adapter,
                              DeviceProtocol::Dmx512,
                              tr("Dmx512适配器"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateDmx512()
{
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = new DeviceParamSpec(DeviceKey::Dmx512AdapterDeviceId,
                                         QStringLiteral("目标Dmx512适配器"),
                                         QString(),
                                         DeviceParamSpec::SelectType,
                                         DeviceParamSpec::SelectEditor);
        spec->setRequired(true);
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("Dmx512协议"),
                              QString(),
                              DeviceProtocol::Dmx512,
                              tr("Dmx512协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateHttp()
{
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = new DeviceParamSpec(DeviceKey::Address,
                                         QStringLiteral("HTTP地址"),
                                         QString(),
                                         DeviceParamSpec::StringType,
                                         DeviceParamSpec::TextEditor);
        spec->setPattern(DevicePattern::HttpAddress);
        spec->setRequired(true);
        spec->setPlaceholderText(QStringLiteral("http://192.168.1.10:8080"));
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("HTTP协议"),
                              QString(),
                              DeviceProtocol::Http,
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
        spec->setOptions(QVariantList{9600, 19200, 38400, 57600, 115200});
        specs.push_back(spec);
    }

    return makeDeviceTemplate(tr("串口协议"),
                              QString(),
                              DeviceProtocol::Serial,
                              tr("串口协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::createDefaultDeviceTemplateOsc()
{
    QList<DeviceParamSpec *> specs;
    {
        auto *spec = new DeviceParamSpec(DeviceKey::Ip,
                                         QStringLiteral("ip"),
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
                              DeviceProtocol::Osc,
                              tr("OSC协议设备"),
                              specs);
}

DeviceTemplate *DeviceTemplateModel::makeDeviceTemplate(const QString &name,
                                                        const QString &deviceType,
                                                        const QString &protocol,
                                                        const QString &description,
                                                        const QList<DeviceParamSpec *> &configSpecs)
{
    return new DeviceTemplate(name, deviceType, protocol, description, configSpecs, {}, this);
}

