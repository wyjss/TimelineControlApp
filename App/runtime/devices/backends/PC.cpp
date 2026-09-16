#include "devices/backends/PC.h"
#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "utils.h"

#include "LogMacros.h"
#include <QUrl>
#include <QUrlQuery>
#include <QRect>

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
		QString url = Utils::getVideoRealSource(executionInputValues.value(DeviceKey::VideoFile).toString());
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
						   DeviceKey::CommandOpenVideo,
						   parent)
	{
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoFile));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoTimeSec));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoWindowX));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoWindowY));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoWindowW));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoWindowH));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoSrcX));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoSrcY));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoSrcW));
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::VideoSrcH));

		auto* playField = new DeviceParamSpec(QStringLiteral("play"),
											  QStringLiteral("立即播放"),
											  false,
											  DeviceParamSpec::BoolType,
											  DeviceParamSpec::ChoiceEditor,
											  this);
		playField->setOptions({"false", "true"});
		playField->setRequired(true);
		addExecutionInputField(playField);

	}

	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
	{
		auto params = DeviceCommand_PC::resolvedParams(executionInputValues);
		QString url = Utils::getVideoRealSource(executionInputValues.value(DeviceKey::VideoFile).toString());
		params[DeviceKey::VideoFile] = url;

		QString sVideoRect, sVideoSrcRect;
		Utils::rectToString(QRect(params[DeviceKey::VideoWindowX].toInt(),
			params[DeviceKey::VideoWindowY].toInt(),
			params[DeviceKey::VideoWindowW].toInt(),
			params[DeviceKey::VideoWindowH].toInt()), sVideoRect);
		Utils::rectToString(QRect(params[DeviceKey::VideoSrcX].toInt(),
			params[DeviceKey::VideoSrcY].toInt(),
			params[DeviceKey::VideoSrcW].toInt(),
			params[DeviceKey::VideoSrcH].toInt()), sVideoSrcRect);

		int w = params[DeviceKey::VirtualScreenWidth].toInt();
		int h = params[DeviceKey::VirtualScreenHeight].toInt();
		QUrlQuery query;
		query.addQueryItem("mode", "virtual");
		query.addQueryItem("url", url);
		query.addQueryItem("play", executionInputValues.value("play", true).toString());
		query.addQueryItem("rect", sVideoRect);
		query.addQueryItem("srcRect", sVideoSrcRect);
		query.addQueryItem("sec", executionInputValues.value(DeviceKey::VideoTimeSec, 0).toString());
		//query.addQueryItem("canvasSize", QString("%1x%2").arg(w).arg(h));

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
							   DeviceKey::CommandPlayVideo,
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
							   DeviceKey::CommandPauseVideo,
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
							   DeviceKey::CommandStopVideo,
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
						   DeviceKey::CommandClosePlayer,
						   parent)
	{
		getField(DeviceKey::ApiPath)->setValue("/video/closePlayer");
	}
};

//class PlayDomeVideoCommand final : public DeviceCommand_PC
//{
//public:
//	explicit PlayDomeVideoCommand(QObject* parent)
//		: DeviceCommand_PC(QStringLiteral("播放全景视频"),
//						   DeviceKey::CommandPlayDomeVideo,
//						   parent)
//	{
//		auto* videoFileField = new DeviceParamSpec(QStringLiteral("videoFile"),
//												   QStringLiteral("视频文件"),
//												   QString(),
//												   DeviceParamSpec::StringType,
//												   DeviceParamSpec::TextEditor,
//												   this);
//		videoFileField->setRequired(true);
//		addExecutionInputField(videoFileField);
//	}
//
//	QVariantMap resolvedParams(const QVariantMap& executionInputValues) const override
//	{
//		QVariantMap params = DeviceCommand::resolvedParams(executionInputValues);
//		const QString videoFile = executionInputValues.value(QStringLiteral("videoFile")).toString().trimmed();
//		if (!videoFile.isEmpty()) {
//			params.insert(DeviceKey::ApiPath,
//						  QStringLiteral("/video/play?mode=dome&url=")
//						  + QString::fromLatin1(QUrl::toPercentEncoding(videoFile)));
//		}
//		return params;
//	}
//};



PcDeviceTemplate::PcDeviceTemplate(QObject* parent)
	:DeviceTemplate("电脑",
					DeviceType::PC,
					QStringList{DeviceProtocol::Pc, DeviceProtocol::Http},
					"电脑设备",
					{
						DeviceParamSpec::createForKey(DeviceKey::VirtualScreenWidth),
						DeviceParamSpec::createForKey(DeviceKey::VirtualScreenHeight),
						DeviceParamSpec::createForKey(DeviceKey::ScreenWidth),
						DeviceParamSpec::createForKey(DeviceKey::ScreenHeight),
						DeviceParamSpec::createForKey(DeviceKey::ScreenColumns),
						DeviceParamSpec::createForKey(DeviceKey::ScreenRows)
					},
					{},
					parent
	)
{

}

Device* PcDeviceTemplate::createDevice(QObject* parent, const QVariantMap& configValues)
{
	auto device = DeviceTemplate::createDevice(parent, configValues);
	auto* keystoneCorrection = new DeviceParamSpec(DeviceKey::KeystoneCorrection,
													  QStringLiteral("几何校正"),
													  QVariantList(),
													  DeviceParamSpec::VariantType,
													  DeviceParamSpec::AutoEditor,
													  device);
	device->addParam(keystoneCorrection);
	if (configValues.contains(DeviceKey::KeystoneCorrection))
		device->setParamValue(DeviceKey::KeystoneCorrection,
							  configValues.value(DeviceKey::KeystoneCorrection));

	device->appendCommand(new OpenVideoCommand(device));
	device->appendCommand(new PlayVideoCommand(device));
	device->appendCommand(new PauseVideoCommand(device));
	device->appendCommand(new StopVideoCommand(device));
	device->appendCommand(new ClosePlayerCommand(device));
	//device->appendCommand(new PlayDomeVideoCommand(device));

	// 系统
	auto _createSystemCommand = [](const QString& name, const QString& url) {
		auto cmd = new DeviceCommand_PC();
		cmd->setName(name);
		cmd->getField(DeviceKey::ApiPath)->setValue(url);
		return cmd;
	};
	device->appendCommand(
		_createSystemCommand(DeviceKey::SystemPause, "/video/systemPause"));
	device->appendCommand(
		_createSystemCommand(DeviceKey::SystemResume, "/video/systemResume"));
	device->appendCommand(
		_createSystemCommand(DeviceKey::SystemStop, "/video/systemStop"));
	

	return device;
}

DeviceCommand *PcDeviceTemplate::createCommand(const QString &commandType,
                                               QObject *parent) const
{
	if (commandType == DeviceKey::CommandOpenVideo)
		return new OpenVideoCommand(parent);
	if (commandType == DeviceKey::CommandPlayVideo)
		return new PlayVideoCommand(parent);
	if (commandType == DeviceKey::CommandPauseVideo)
		return new PauseVideoCommand(parent);
	if (commandType == DeviceKey::CommandStopVideo)
		return new StopVideoCommand(parent);
	if (commandType == DeviceKey::CommandClosePlayer)
		return new ClosePlayerCommand(parent);
// 	if (commandType == DeviceKey::CommandPlayDomeVideo)
// 		return new PlayDomeVideoCommand(parent);
	return nullptr;
}
