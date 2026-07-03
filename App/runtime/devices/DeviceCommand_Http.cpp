#include "devices/DeviceCommand_Http.h"
#include "devices/DeviceConstants.h"
#include "LogMacros.h"
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

namespace {

QString ipAddressPattern()
{
	return QStringLiteral("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(:[0-9]{1,5})?$");
}

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
    : DeviceCommand(QStringLiteral("HTTP Cue"), parent)
{
    //
	auto* ipField = new DeviceParamSpec(DeviceKey::Ip,
											 tr("ip"),
											 "",
											 DeviceParamSpec::StringType,
											 DeviceParamSpec::TextEditor,
											 parent);
    ipField->setPattern(ipAddressPattern());
    ipField->setPlaceholderText(QStringLiteral("192.168.1.10"));
    addCreationInputField(ipField);
	//
	auto* portField = new DeviceParamSpec(DeviceKey::IpPort,
										  tr("port"),
										  10001,
										  DeviceParamSpec::IntType,
										  DeviceParamSpec::AutoEditor,
										  parent);
	portField->setMinimum(1);
	portField->setMaximum(65535);
    addCreationInputField(portField);
	//
	auto* methodField = new DeviceParamSpec(DeviceKey::HttpMethod,
											tr("Method"),
											"GET",
											DeviceParamSpec::SelectType,
											DeviceParamSpec::SelectEditor,
											parent);
	methodField->setOptions(QVariantList{
		option(QStringLiteral("GET"), QStringLiteral("GET")),
		option(QStringLiteral("POST"), QStringLiteral("POST")),
							});
    addCreationInputField(methodField);
	//
	auto* pathField = new DeviceParamSpec(DeviceKey::ApiPath,
										  tr("Path"),
										  "",
										  DeviceParamSpec::StringType,
										  DeviceParamSpec::TextEditor,
										  parent);
	pathField->setPattern(QStringLiteral("^/.*"));
	pathField->setPlaceholderText(QStringLiteral("/api/command"));
    addCreationInputField(pathField);
	//     fields.append(pathField);
	// 	//
	// 	auto* queryField = new DeviceParamSpec(DeviceKey::HttpQueryParams,
	// 										  tr("Path"),
	// 										  path(),
	// 										  DeviceParamSpec::StringType,
	// 										  DeviceParamSpec::TextEditor,
	// 										  parent);
	//     queryField->setPattern(QStringLiteral(""));
	//     queryField->setPattern(R"(^(?:$|[A-Za-z0-9_.~-]+=[^&=]*(?:&[A-Za-z0-9_.~-]+=[^&=]*)*)$)");
	// 	fields.append(queryField);
		//
	auto* bodyField = new DeviceParamSpec(DeviceKey::HttpBody,
										  tr("Body"),
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

void DeviceCommand_Http::execute()
{
    const QString ip = ipField() ? ipField()->stringValue() : QString();
    const QString path = pathField() ? pathField()->stringValue() : QString();
    if (ip.isEmpty() || path.isEmpty()) {
        emit executionFinished(false, tr("HTTP address or path is empty"));
        return;
    }

    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(ip);
    url.setPort(portField() ? portField()->intValue() : 80);
    url.setPath(path);
    if (!url.isValid()) {
        emit executionFinished(false, tr("Invalid HTTP URL"));
        return;
    }

	LOG_DEBUG("http " << url);
    QNetworkRequest request(url);
    auto *manager = new QNetworkAccessManager;
    QNetworkReply *reply = nullptr;
    if (methodField() && methodField()->stringValue() == QStringLiteral("POST")) {
        request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
        reply = manager->post(request, bodyField() ? bodyField()->stringValue().toUtf8() : QByteArray());
    } else {
        reply = manager->get(request);
    }

    QTimer::singleShot(5000, reply, [reply]() {
        if (reply->isRunning()) {
            reply->setProperty("timedOut", true);
            reply->abort();
        }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QVariant status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute);
        const int httpStatus = status.toInt();
        const bool success = reply->error() == QNetworkReply::NoError
            && (!status.isValid() || httpStatus < 400);
        QString errorMessage;
        if (!success)
            errorMessage = reply->property("timedOut").toBool()
                ? tr("HTTP request timed out")
                : (reply->error() == QNetworkReply::NoError ? tr("HTTP %1").arg(httpStatus) : reply->errorString());
        emit executionFinished(success, errorMessage);
    });
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
    connect(reply, &QNetworkReply::finished, manager, &QObject::deleteLater);
}

QString DeviceCommand_Http::protocolName()
{
    return QStringLiteral("http");
}
