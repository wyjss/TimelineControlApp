#include "devices/DeviceCommandFactory.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include <QVariantList>
#include <QVariantMap>

using namespace TimelineControl;

namespace {

const char *kProtocolKey = "protocol";
const char *kHexPayloadPattern = "^([0-9A-Fa-f]{2})(\\s+[0-9A-Fa-f]{2})*$";

QVariantMap option(const QString &label, const QString &value)
{
    return QVariantMap{
        {QStringLiteral("label"), label},
        {QStringLiteral("value"), value}
    };
}

void addHttpFields(DeviceCommand *command)
{
    auto *ipField = new DeviceParamSpec(DeviceKey::Ip,
                                        QStringLiteral("IP"),
                                        QString(),
                                        DeviceParamSpec::StringType,
                                        DeviceParamSpec::TextEditor,
                                        command);
    ipField->setPattern(DevicePattern::Ip);
    ipField->setPlaceholderText(QStringLiteral("192.168.1.10"));
    command->addCreationInputField(ipField);

    auto *portField = new DeviceParamSpec(DeviceKey::IpPort,
                                          QStringLiteral("端口"),
                                          10001,
                                          DeviceParamSpec::IntType,
                                          DeviceParamSpec::AutoEditor,
                                          command);
    portField->setMinimum(1);
    portField->setMaximum(65535);
    command->addCreationInputField(portField);

    auto *methodField = new DeviceParamSpec(DeviceKey::HttpMethod,
                                            QStringLiteral("方法"),
                                            QStringLiteral("GET"),
                                            DeviceParamSpec::SelectType,
                                            DeviceParamSpec::SelectEditor,
                                            command);
    methodField->setOptions(QVariantList{
        option(QStringLiteral("GET"), QStringLiteral("GET")),
        option(QStringLiteral("POST"), QStringLiteral("POST"))
    });
    command->addCreationInputField(methodField);

    auto *pathField = new DeviceParamSpec(DeviceKey::ApiPath,
                                          QStringLiteral("路径"),
                                          QString(),
                                          DeviceParamSpec::StringType,
                                          DeviceParamSpec::TextEditor,
                                          command);
    pathField->setPattern(QStringLiteral("^/.*"));
    pathField->setPlaceholderText(QStringLiteral("/api/command"));
    command->addCreationInputField(pathField);

    auto *bodyField = new DeviceParamSpec(DeviceKey::HttpBody,
                                          QStringLiteral("内容"),
                                          QString(),
                                          DeviceParamSpec::StringType,
                                          DeviceParamSpec::TextEditor,
                                          command);
    bodyField->setRequired(false);
    command->addCreationInputField(bodyField);
}

} // namespace

DeviceCommand *DeviceCommandFactory::createForProtocol(const QString &protocol, QObject *parent)
{
    const QString protocolValue = protocol.trimmed();
    if (protocolValue == DeviceProtocol::Http) {
        auto *command = new DeviceCommand(protocolValue, QStringLiteral("HTTP 指令"), parent);
        addHttpFields(command);
        return command;
    }

    if (protocolValue == DeviceProtocol::Pc) {
        auto *command = new DeviceCommand(protocolValue, QStringLiteral("PC 指令"), parent);
        addHttpFields(command);
        command->updateConfigMap({
            {DeviceKey::HttpMethod, QStringLiteral("GET")},
            {DeviceKey::HttpBody, QString()},
            {DeviceKey::IpPort, 11357}
        });
        return command;
    }

    if (protocolValue == DeviceProtocol::Serial) {
        auto *command = new DeviceCommand(protocolValue, QStringLiteral("串口指令"), parent);
        auto *serialPortField = new DeviceParamSpec(DeviceKey::SerialPort,
                                                    QStringLiteral("串口"),
                                                    QStringLiteral("COM0"),
                                                    DeviceParamSpec::StringType,
                                                    DeviceParamSpec::TextEditor,
                                                    command);
        serialPortField->setPlaceholderText(QStringLiteral("COM1"));
        serialPortField->setRequired(true);
        command->addCreationInputField(serialPortField);

        auto *baudRateField = new DeviceParamSpec(DeviceKey::BaudRate,
                                                  QStringLiteral("波特率"),
                                                  9600,
                                                  DeviceParamSpec::IntType,
                                                  DeviceParamSpec::TextEditor,
                                                  command);
        baudRateField->setRequired(true);
        baudRateField->setMinimum(1);
        baudRateField->setMaximum(4000000);
        command->addCreationInputField(baudRateField);

        auto *payloadField = new DeviceParamSpec(DeviceKey::Payload,
                                                 QStringLiteral("数据内容"),
                                                 QString(),
                                                 DeviceParamSpec::StringType,
                                                 DeviceParamSpec::TextEditor,
                                                 command);
        payloadField->setPlaceholderText(QStringLiteral("A5 5A 01 00"));
        payloadField->setPattern(QString::fromLatin1(kHexPayloadPattern));
        payloadField->setRequired(true);
        command->addCreationInputField(payloadField);
        return command;
    }

    if (protocolValue == DeviceProtocol::Dmx512) {
        auto *command = new DeviceCommand(protocolValue, QStringLiteral("DMX 指令"), parent);
        auto *channelField = new DeviceParamSpec(QStringLiteral("channel"),
                                                 QStringLiteral("通道"),
                                                 1,
                                                 DeviceParamSpec::IntType,
                                                 DeviceParamSpec::TextEditor,
                                                 command);
        channelField->setMinimum(1);
        channelField->setMaximum(512);
        command->addCreationInputField(channelField);

        auto *valueField = new DeviceParamSpec(QStringLiteral("value"),
                                               QStringLiteral("值"),
                                               255,
                                               DeviceParamSpec::IntType,
                                               DeviceParamSpec::SliderEditor,
                                               command);
        valueField->setMinimum(0);
        valueField->setMaximum(255);
        valueField->setStepSize(1);
        command->addCreationInputField(valueField);
        return command;
    }

    return nullptr;
}

DeviceCommand *DeviceCommandFactory::createFromJson(const QJsonObject &json, QObject *parent)
{
    DeviceCommand *command = createForProtocol(json.value(QString::fromLatin1(kProtocolKey)).toString(), parent);
    if (!command)
        return nullptr;

    if (!command->loadFromJson(json)) {
        delete command;
        return nullptr;
    }

    return command;
}
