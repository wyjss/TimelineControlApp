#include "devices/backends/PC.h"
#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceCommandFactory.h"

#include <QUrl>
#include <QUrlQuery>

class _VideoControlCommand : public DeviceCommand_PC
{
public:
	explicit _VideoControlCommand(const QString& name,
								  const QString& commandType,
								  const QString& api,
								  QObject* parent)
		: DeviceCommand_PC(name,
						   commandType,
						   parent)
		, m_api(api)
	{
		auto* videoFileField = DeviceParamSpec::createForKey(DeviceKey::VideoFile);
		videoFileField->setRequired(false);
		addExecutionInputField(videoFileField);
	}

	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
	{
		auto params = DeviceCommand_PC::resolvedParams(executionInputValues);
		QString api = m_api;
		QString url = executionInputValues.value("videoFile", "").toString();
		if (!url.isEmpty() && url.startsWith("$")) {
			url = url.replace("$", DeviceConstants::LocalVideoPrefix);
		}
		if (!url.isEmpty()) {
			QUrl qurl(api);
			QUrlQuery query(qurl);
			query.addQueryItem("url", url);
			qurl.setQuery(query);
			api = qurl.url();
			params[DeviceKey::Name] = this->name() + "-" + url;
		}
		params[DeviceKey::ApiPath] = api;
		return params;
	}
private:
	QString m_api;
};

class OpenVideoCommand : public DeviceCommand_PC
{
public:
	explicit OpenVideoCommand(QObject* parent)
		: DeviceCommand_PC("加载视频",
						   "openVideo",
						   parent)
	{
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoFile));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::Rect));

		auto* playField = new DeviceParamSpec(QStringLiteral("play"),
											  QStringLiteral("立即播放"),
											  true,
											  DeviceParamSpec::BoolType,
											  DeviceParamSpec::AutoEditor,
											  this);
		playField->setRequired(true);
		addExecutionInputField(playField);

	}

	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
	{
		auto params = DeviceCommand_PC::resolvedParams(executionInputValues);
		QString url = executionInputValues.value("videoFile", "").toString();
		if (url.startsWith("$")) {
			url = url.replace("$", DeviceConstants::LocalVideoPrefix);
		}


		int w = params[DeviceKey::VirtualScreenWidth].toInt();
		int h = params[DeviceKey::VirtualScreenHeight].toInt();
		QUrlQuery query;
		query.addQueryItem("mode", "virtual");
		query.addQueryItem("url", url);
		query.addQueryItem("play", executionInputValues.value("play", true).toString());
		query.addQueryItem("rect", executionInputValues[DeviceKey::Rect].toString());
		query.addQueryItem("canvasSize", QString("%1x%2").arg(w).arg(h));

		QString api = QString("/video/open?") + query.toString();
		params[DeviceKey::Name] = this->name() + "-" + url;
		params[DeviceKey::ApiPath] = api;
		return params;
	}
private:
	QString m_api;
};

class PlayVideoCommand : public _VideoControlCommand
{
public:
	explicit PlayVideoCommand(QObject* parent)
		: _VideoControlCommand("播放视频",
							   "playVideo",
							   "/video/play",
							   parent)
	{
	}
};

class PauseVideoCommand : public _VideoControlCommand
{
public:
	explicit PauseVideoCommand(QObject* parent)
		: _VideoControlCommand("暂停播放",
							   "pauseVideo",
							   "/video/pause",
							   parent)
	{
	}
};

class StopVideoCommand : public _VideoControlCommand
{
public:
	explicit StopVideoCommand(QObject* parent)
		: _VideoControlCommand("停止播放",
							   "closeVideo",
							   "/video/close",
							   parent)
	{
	}
};

class ClosePlayerCommand : public DeviceCommand_PC
{
public:
	explicit ClosePlayerCommand(QObject* parent)
		: DeviceCommand_PC("关闭播放器",
						   "closePlayer",
						   parent)
	{
		getField(DeviceKey::ApiPath)->setValue("/video/closePlayer");
	}
};

class PlayDomeVideoCommand final : public DeviceCommand_PC
{
public:
	explicit PlayDomeVideoCommand(QObject* parent)
		: DeviceCommand_PC(QStringLiteral("播放全景视频"),
						   QStringLiteral("playDomeVideo"),
						   parent)
	{
		auto* videoFileField = new DeviceParamSpec(QStringLiteral("videoFile"),
												   QStringLiteral("视频文件"),
												   QString(),
												   DeviceParamSpec::StringType,
												   DeviceParamSpec::TextEditor,
												   this);
		videoFileField->setRequired(true);
		addExecutionInputField(videoFileField);
	}

	QVariantMap resolvedParams(const QVariantMap& executionInputValues) const override
	{
		QVariantMap params = DeviceCommand::resolvedParams();
		const QString videoFile = executionInputValues.value(QStringLiteral("videoFile")).toString().trimmed();
		if (!videoFile.isEmpty()) {
			params.insert(DeviceKey::ApiPath,
						  QStringLiteral("/video/play?mode=dome&url=")
						  + QString::fromLatin1(QUrl::toPercentEncoding(videoFile)));
		}
		return params;
	}
};

class VirtualPlaybackCommand final : public DeviceCommand_PC
{
public:
	explicit VirtualPlaybackCommand(QObject* parent)
		: DeviceCommand_PC(QStringLiteral("虚拟播放"),
						   QStringLiteral("virtualPlayback"),
						   parent)
	{
		addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Videos));
	}
};

PcDeviceTemplate::PcDeviceTemplate(QObject* parent)
	:DeviceTemplate("电脑",
					DeviceType::PC,
					QStringList{DeviceProtocol::Pc, DeviceProtocol::Http},
					"电脑设备",
					{},
					{},
					parent
	)
{

}

Device* PcDeviceTemplate::createDevice(QObject* parent, const QVariantMap& configValues)
{
	auto device = DeviceTemplate::createDevice(parent, configValues);

	device->appendCommand(new OpenVideoCommand(device));
	device->appendCommand(new PlayVideoCommand(device));
	device->appendCommand(new PauseVideoCommand(device));
	device->appendCommand(new StopVideoCommand(device));
	device->appendCommand(new ClosePlayerCommand(device));
	device->appendCommand(new PlayDomeVideoCommand(device));
	device->appendCommand(new VirtualPlaybackCommand(device));

	return device;
}