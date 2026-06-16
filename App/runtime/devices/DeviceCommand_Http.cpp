#include "devices/DeviceCommand_Http.h"

#include <QStringList>
#include <QVariantMap>

namespace {

const char *kAddressKey = "address";
const char *kMethodKey = "method";
const char *kPathKey = "path";
const char *kBodyKey = "body";

QString httpAddressPattern()
{
    return QStringLiteral("^(http://)?((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(:[0-9]{1,5})?$");
}

QString normalizedAddress(const QString &address)
{
    return address.trimmed();
}

QString normalizedMethod(const QString &method)
{
    const QString normalized = method.trimmed().toUpper();
    return normalized.isEmpty() ? QStringLiteral("POST") : normalized;
}

QString normalizedPath(const QString &path)
{
    QString normalized = path.trimmed();
    if (normalized.isEmpty())
        return QStringLiteral("/");

    if (!normalized.startsWith(QLatin1Char('/')))
        normalized.prepend(QLatin1Char('/'));

    return normalized;
}

bool isValidIPv4Address(const QString &address)
{
    const QStringList parts = address.split(QLatin1Char('.'));
    if (parts.size() != 4)
        return false;

    for (const QString &part : parts) {
        if (part.isEmpty())
            return false;

        bool ok = false;
        const int value = part.toInt(&ok);
        if (!ok || value < 0 || value > 255)
            return false;
    }

    return true;
}

bool isValidHttpAddress(const QString &address)
{
    QString value = normalizedAddress(address);
    if (value.isEmpty())
        return false;

    if (value.startsWith(QStringLiteral("http://"), Qt::CaseInsensitive))
        value = value.mid(7);
    else if (value.contains(QStringLiteral("://")))
        return false;

    if (value.contains(QLatin1Char('/')) || value.contains(QLatin1Char('?')) || value.contains(QLatin1Char('#')))
        return false;

    QString host = value;
    const int portIndex = value.lastIndexOf(QLatin1Char(':'));
    if (portIndex >= 0) {
        host = value.left(portIndex);
        const QString portText = value.mid(portIndex + 1);

        bool ok = false;
        const int port = portText.toInt(&ok);
        if (!ok || port < 1 || port > 65535)
            return false;
    }

    return isValidIPv4Address(host);
}

QVariantMap option(const QString &label, const QString &value)
{
    return QVariantMap{
        {QStringLiteral("label"), label},
        {QStringLiteral("value"), value}
    };
}

} // namespace

namespace TimelineControl {

DeviceCommand_Http::DeviceCommand_Http(QObject *parent)
    : DeviceCommand(QStringLiteral("HTTP Cue"), parent)
{
    setAddress(QString());
    setMethod(QStringLiteral("POST"));
    setPath(QStringLiteral(""));
    setBody(QStringLiteral(""));
}

DeviceCommand_Http::DeviceCommand_Http(const QString &name,
                                       const QString &method,
                                       const QString &path,
                                       QObject *parent)
    : DeviceCommand_Http(name, QString(), method, path, parent)
{
}

DeviceCommand_Http::DeviceCommand_Http(const QString &name,
                                       const QString &address,
                                       const QString &method,
                                       const QString &path,
                                       QObject *parent)
    : DeviceCommand(name, parent)
{
    setAddress(address);
    setMethod(method);
    setPath(path);
}

QString DeviceCommand_Http::address() const
{
    return m_address;
}

void DeviceCommand_Http::setAddress(const QString &address)
{
    const QString normalized = normalizedAddress(address);
    if (m_address == normalized)
        return;

    m_address = normalized;
    emit addressChanged();
}

QString DeviceCommand_Http::method() const
{
    return m_method;
}

void DeviceCommand_Http::setMethod(const QString &method)
{
    const QString normalized = normalizedMethod(method);
    if (m_method == normalized)
        return;

    m_method = normalized;
    emit methodChanged();
}

QString DeviceCommand_Http::path() const
{
    return m_path;
}

void DeviceCommand_Http::setPath(const QString &path)
{
    const QString normalized = normalizedPath(path);
    if (m_path == normalized)
        return;

    m_path = normalized;
    emit pathChanged();
}

QString DeviceCommand_Http::body() const
{
    return m_body;
}

void DeviceCommand_Http::setBody(const QString &body)
{
    if (m_body == body)
        return;

    m_body = body;
    emit bodyChanged();
}

QString DeviceCommand_Http::protocol() const
{
    return protocolName();
}

QString DeviceCommand_Http::protocolName()
{
    return QStringLiteral("http");
}

QJsonObject DeviceCommand_Http::paramsToJson() const
{
    QJsonObject params;
    params.insert(QString::fromLatin1(kAddressKey), address());
    params.insert(QString::fromLatin1(kMethodKey), method());
    params.insert(QString::fromLatin1(kPathKey), path());
    params.insert(QString::fromLatin1(kBodyKey), body());
    return params;
}

bool DeviceCommand_Http::loadParamsFromJson(const QJsonObject &params)
{
    if (params.contains(QString::fromLatin1(kAddressKey)))
        setAddress(params.value(QString::fromLatin1(kAddressKey)).toString(address()));

    if (params.contains(QString::fromLatin1(kMethodKey)))
        setMethod(params.value(QString::fromLatin1(kMethodKey)).toString(method()));

    if (params.contains(QString::fromLatin1(kPathKey)))
        setPath(params.value(QString::fromLatin1(kPathKey)).toString(path()));

    if (params.contains(QString::fromLatin1(kBodyKey)))
        setBody(params.value(QString::fromLatin1(kBodyKey)).toString(body()));

    return true;
}

QString DeviceCommand_Http::validateParams() const
{
    if (address().trimmed().isEmpty())
        return tr("HTTP address is required");

    if (!isValidHttpAddress(address()))
        return tr("HTTP address must be [http://]ip[:port]");

    if (method().trimmed().isEmpty())
        return tr("HTTP method is required");

    if (path().trimmed().isEmpty())
        return tr("HTTP path is required");

    if (!path().startsWith(QLatin1Char('/')))
        return tr("HTTP path must start with /");

    return QString();
}

QList<DeviceParamSpec *> DeviceCommand_Http::createCreationInputFields(QObject *parent) const
{
    QList<DeviceParamSpec *> fields = DeviceCommand::createCreationInputFields(parent);

    auto *addressField = new DeviceParamSpec(QStringLiteral("address"),
                                             tr("Address"),
                                             address(),
                                             DeviceParamSpec::StringType,
                                             DeviceParamSpec::TextEditor,
                                             parent);
    addressField->setRequired(true);
    addressField->setPattern(httpAddressPattern());
    addressField->setPlaceholderText(QStringLiteral("http://192.168.1.10:8080"));
    fields.append(addressField);

    auto *methodField = new DeviceParamSpec(QStringLiteral("method"),
                                            tr("Method"),
                                            method(),
                                            DeviceParamSpec::SelectType,
                                            DeviceParamSpec::SelectEditor,
                                            parent);
    methodField->setRequired(true);
    methodField->setOptions(QVariantList{
        option(QStringLiteral("GET"), QStringLiteral("GET")),
        option(QStringLiteral("POST"), QStringLiteral("POST")),
        option(QStringLiteral("PUT"), QStringLiteral("PUT")),
        option(QStringLiteral("PATCH"), QStringLiteral("PATCH")),
        option(QStringLiteral("DELETE"), QStringLiteral("DELETE"))
    });
    fields.append(methodField);

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

    auto *bodyField = new DeviceParamSpec(QStringLiteral("body"),
                                          tr("Body"),
                                          body(),
                                          DeviceParamSpec::StringType,
                                          DeviceParamSpec::TextEditor,
                                          parent);
    fields.append(bodyField);

    return fields;
}

} // namespace TimelineControl

