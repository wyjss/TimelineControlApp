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
    //
	auto* ipField = new DeviceParamSpec(DeviceKey::Ip,
											 tr("IP"),
											 "",
											 DeviceParamSpec::StringType,
											 DeviceParamSpec::TextEditor,
											 parent);
    ipField->setPattern(DevicePattern::Ip);
    ipField->setPlaceholderText(QStringLiteral("192.168.1.10"));
    addCreationInputField(ipField);
	//
	auto* portField = new DeviceParamSpec(DeviceKey::IpPort,
										  tr("端口"),
										  10001,
										  DeviceParamSpec::IntType,
										  DeviceParamSpec::AutoEditor,
										  parent);
	portField->setMinimum(1);
	portField->setMaximum(65535);
    addCreationInputField(portField);
	//
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
	//
	auto* pathField = new DeviceParamSpec(DeviceKey::ApiPath,
										  tr("路径"),
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

void DeviceCommand_Http::execute()
{
    const QString ip = ipField() ? ipField()->stringValue() : QString();
    const QString path = pathField() ? pathField()->stringValue() : QString();
    if (ip.isEmpty() || path.isEmpty()) {
        emit executionFinished(false, tr("HTTP 地址或路径为空"));
        return;
    }

    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(ip);
    url.setPort(portField() ? portField()->intValue() : 80);
    url.setPath(path);
    if (!url.isValid()) {
        emit executionFinished(false, tr("HTTP URL 无效"));
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
                ? tr("HTTP 请求超时")
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
