#include "devices/DeviceCommand_PC.h"

using namespace TimelineControl;

DeviceCommand_PC::DeviceCommand_PC(QObject *parent)
    : DeviceCommand_Http(parent)
{
	setName(QStringLiteral("PC 指令"));
	updateConfigMap({
	   {DeviceKey::HttpMethod, "GET"},
	   {DeviceKey::HttpBody, ""},
	   {DeviceKey::IpPort, 11357},
					});
}

QString DeviceCommand_PC::protocol() const
{
    return protocolName();
}

QString DeviceCommand_PC::protocolName()
{
    return QStringLiteral("pc");
}
