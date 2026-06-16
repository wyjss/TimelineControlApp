#include "devices/DeviceCommand_PC.h"

namespace {

const char *kPathKey = "path";

} // namespace

namespace TimelineControl {

DeviceCommand_PC::DeviceCommand_PC(QObject *parent)
    : DeviceCommand_Http(parent)
{
    setName(QStringLiteral("PC Cue"));
    setAddress(QString());
    setMethod(QStringLiteral("GET"));
    setPath(QStringLiteral(""));
    setBody(QStringLiteral(""));
}

DeviceCommand_PC::DeviceCommand_PC(const QString &name,
                                   const QString &path,
                                   QObject *parent)
    : DeviceCommand_Http(parent)
{
    setName(name);
    setAddress(QString());
    setMethod(QStringLiteral("GET"));
    setPath(path);
    setBody(QStringLiteral(""));
}

QString DeviceCommand_PC::protocol() const
{
    return protocolName();
}

QString DeviceCommand_PC::protocolName()
{
    return QStringLiteral("pc");
}

QJsonObject DeviceCommand_PC::paramsToJson() const
{
    QJsonObject params;
    params.insert(QString::fromLatin1(kPathKey), path());
    return params;
}

bool DeviceCommand_PC::loadParamsFromJson(const QJsonObject &params)
{
    setAddress(QString());
    setMethod(QStringLiteral("GET"));
    setBody(QStringLiteral(""));

    if (params.contains(QString::fromLatin1(kPathKey)))
        setPath(params.value(QString::fromLatin1(kPathKey)).toString(path()));

    return true;
}

QString DeviceCommand_PC::validateParams() const
{
    if (path().trimmed().isEmpty())
        return tr("PC path is required");

    if (!path().startsWith(QLatin1Char('/')))
        return tr("PC path must start with /");

    return QString();
}

QList<DeviceParamSpec *> DeviceCommand_PC::createCreationInputFields(QObject *parent) const
{
    QList<DeviceParamSpec *> fields = DeviceCommand::createCreationInputFields(parent);

    auto *pathField = new DeviceParamSpec(QStringLiteral("path"),
                                          tr("Path"),
                                          path(),
                                          DeviceParamSpec::StringType,
                                          DeviceParamSpec::TextEditor,
                                          parent);
    pathField->setRequired(true);
    pathField->setPattern(QStringLiteral("^/.*"));
    pathField->setPlaceholderText(QStringLiteral("/api/command"));
    fields.append(pathField);

    return fields;
}

} // namespace TimelineControl
