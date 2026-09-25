#include "devices/backends/PC.h"
#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "utils.h"

#include "LogMacros.h"
#include <QUrl>
#include <QUrlQuery>
#include <QRect>

// class PowerOnCommand : public DeviceCommand_Udp
// {
// public:
// 	PowerOnCommand(QObject* parent)
// 		: DeviceCommand_Udp(DeviceProtocol::Udp, "开机", "", parent)
// 	{
// 		this->getField(DeviceKey::Port)->setRequired(false);
// 		this->getField(DeviceKey::Port)->setValue();
// 
// 		addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Ip));
// 		addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Port));
// 		addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Payload));
// 		addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::PayloadType));
// 	}
// };

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
		videoFileField->setSubtitle("留空表示全部视频");
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
		if (commandType() == DeviceKey::CommandSeekVideo) {
			QUrl qurl(api);
			QUrlQuery query(qurl);
			query.addQueryItem("time", params[DeviceKey::VideoSeekTimeSec].toString());
			qurl.setQuery(query);
			api = qurl.url();
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
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::AVLoop));
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
		query.addQueryItem("loop", params[DeviceKey::AVLoop].toString());
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

class SeekVideoCommand : public _VideoControlCommand
{
public:
	explicit SeekVideoCommand(QObject* parent)
		: _VideoControlCommand("视频跳转",
							   DeviceKey::CommandSeekVideo,
							   "/video/seek",
							   parent)
	{

		this->addExecutionInputField(
			DeviceParamSpec::createForKey(DeviceKey::VideoSeekTimeSec)
		);

		setStringTemplateKey(DeviceKey::ApiPath);
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

class PlayAudioCommand : public DeviceCommand_PC
{
public:
	explicit PlayAudioCommand(QObject* parent)
		: DeviceCommand_PC("播放音频",
						   DeviceKey::CommandPlayAudio,
						   parent)
	{
		addExecutionInputField(DeviceParamSpec::createForKey(DeviceKey::AudioFile));
	}

	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
	{
		auto params = DeviceCommand_PC::resolvedParams(executionInputValues);
		QString url = Utils::getAudioRealSource(executionInputValues.value(DeviceKey::AudioFile).toString());
		params[DeviceKey::AudioFile] = url;

		QUrlQuery query;
		query.addQueryItem("url", url);

		QString api = QString("/audio/play?") + query.toString();
		params[DeviceKey::Name] = this->name() + "-" + url;
		params[DeviceKey::ApiPath] = api;
		return params;
	}
private:
	QString m_api;
};

class PauseAudioCommand : public DeviceCommand_PC
{
public:
	explicit PauseAudioCommand(QObject* parent)
		: DeviceCommand_PC("暂停音频",
							   DeviceKey::CommandPauseAudio,
							   parent)
	{
		getField(DeviceKey::ApiPath)->setValue("/audio/pause");
	}
};

class StopAudioCommand : public DeviceCommand_PC
{
public:
	explicit StopAudioCommand(QObject* parent)
		: DeviceCommand_PC("关闭音频",
						   DeviceKey::CommandStopAudio,
						   parent)
	{
		getField(DeviceKey::ApiPath)->setValue("/audio/stop");
	}
};

class SystemOpenCommand : public DeviceCommand_Udp
{
public:
	explicit SystemOpenCommand(QObject* parent)
		: DeviceCommand_Udp(DeviceProtocol::Udp,
							DeviceKey::SystemOpen,
						   "",
						   parent)
	{
		// 占位
		getField(DeviceKey::Payload)->setValue("ffffffff");
	}

	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
	{
		auto params = DeviceCommand_Udp::resolvedParams(executionInputValues);

		auto ip = params[DeviceKey::Ip].toString();
		auto mac = params[DeviceKey::MacAddress].toString();
		mac = mac.remove("-");

		// Wake-on-LAN 固定
		params[DeviceKey::Ip] = "255.255.255.255";
		params[DeviceKey::Port] = 9;
		
		// 生成唤醒数据
		QByteArray payload(6, 0xff);
		QByteArray bMac;
		Utils::toHexData(mac, &bMac);
		for (int i = 0; i < 16; ++i) {
			payload.push_back(bMac);
		}
		
		params[DeviceKey::Payload] = payload;
		return params;
	}
};

class SystemCloseCommand : public DeviceCommand_PC
{
public:
	explicit SystemCloseCommand(QObject* parent)
		: DeviceCommand_PC(DeviceKey::SystemClose,
						   "",
						   parent)
	{
		getField(DeviceKey::ApiPath)->setValue("/system/shutdown");
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
	device->appendCommand(new SeekVideoCommand(device));
	device->appendCommand(new StopVideoCommand(device));
	device->appendCommand(new ClosePlayerCommand(device));
	device->appendCommand(new PlayAudioCommand(device));
	device->appendCommand(new PauseAudioCommand(device));
	device->appendCommand(new StopAudioCommand(device));

	
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

	device->appendCommand(new SystemOpenCommand(device));
	device->appendCommand(new SystemCloseCommand(device));

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
	if (commandType == DeviceKey::CommandSeekVideo)
		return new SeekVideoCommand(parent);
	if (commandType == DeviceKey::CommandStopVideo)
		return new StopVideoCommand(parent);
	if (commandType == DeviceKey::CommandClosePlayer)
		return new ClosePlayerCommand(parent);

	if (commandType == DeviceKey::CommandPlayAudio)
		return new PlayAudioCommand(parent);
	if (commandType == DeviceKey::CommandPauseAudio)
		return new PauseAudioCommand(parent);
	if (commandType == DeviceKey::CommandStopAudio)
		return new StopAudioCommand(parent);
// 	if (commandType == DeviceKey::CommandPlayDomeVideo)
// 		return new PlayDomeVideoCommand(parent);
	return nullptr;
}
