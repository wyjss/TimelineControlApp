#include "devices/DeviceCommand_PC.h"

using namespace TimelineControl;

DeviceCommand_PC::DeviceCommand_PC(QObject *parent)
    : DeviceCommand_Http(parent)
{
    setName(QStringLiteral("PC Cue"));
}

DeviceCommand_PC::DeviceCommand_PC(const QString &name,
                                   const QString &path,
                                   QObject *parent)
    : DeviceCommand_Http(parent)
{
    setName(name);
}

QString DeviceCommand_PC::protocol() const
{
    return protocolName();
}

QString DeviceCommand_PC::protocolName()
{
    return QStringLiteral("pc");
}
