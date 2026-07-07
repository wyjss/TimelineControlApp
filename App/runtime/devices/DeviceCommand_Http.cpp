#include "devices/DeviceCommand_Http.h"
#include "devices/DeviceConstants.h"

#include <QVariantMap>

namespace {

QVariantMap option(const QString &label, const QString &value)
{
    return QVariantMap{
        {QStringLiteral("label"), label},
        {QStringLiteral("value"), value}
    };
}

} // namespace

using namespace TimelineControl;

DeviceCommand_Http::DeviceCommand_Http(QObject *parent)
    : DeviceCommand(QStringLiteral("HTTP 指令"), parent)
{
	auto* ipField = new DeviceParamSpec(DeviceKey::Ip,
											 tr("IP"),
											 "",
											 DeviceParamSpec::StringType,
											 DeviceParamSpec::TextEditor,
											 parent);
    ipField->setPattern(DevicePattern::Ip);
    ipField->setPlaceholderText(QStringLiteral("192.168.1.10"));
    addCreationInputField(ipField);

	auto* portField = new DeviceParamSpec(DeviceKey::IpPort,
										  tr("端口"),
										  10001,
										  DeviceParamSpec::IntType,
										  DeviceParamSpec::AutoEditor,
										  parent);
	portField->setMinimum(1);
	portField->setMaximum(65535);
    addCreationInputField(portField);

	auto* methodField = new DeviceParamSpec(DeviceKey::HttpMethod,
											tr("方法"),
											"GET",
											DeviceParamSpec::SelectType,
											DeviceParamSpec::SelectEditor,
											parent);
	methodField->setOptions(QVariantList{
		option(QStringLiteral("GET"), QStringLiteral("GET")),
		option(QStringLiteral("POST"), QStringLiteral("POST")),
							});
    addCreationInputField(methodField);

	auto* pathField = new DeviceParamSpec(DeviceKey::ApiPath,
										  tr("路径"),
										  "",
										  DeviceParamSpec::StringType,
										  DeviceParamSpec::TextEditor,
										  parent);
	pathField->setPattern(QStringLiteral("^/.*"));
	pathField->setPlaceholderText(QStringLiteral("/api/command"));
    addCreationInputField(pathField);

	auto* bodyField = new DeviceParamSpec(DeviceKey::HttpBody,
										  tr("内容"),
										  "",
										  DeviceParamSpec::StringType,
										  DeviceParamSpec::TextEditor,
										  parent);
	bodyField->setRequired(false);
    addCreationInputField(bodyField);
}

QString DeviceCommand_Http::protocol() const
{
    return protocolName();
}

QString DeviceCommand_Http::protocolName()
{
    return QStringLiteral("http");
}
