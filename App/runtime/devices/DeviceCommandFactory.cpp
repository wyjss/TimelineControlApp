#include "devices/DeviceCommandFactory.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "LogMacros.h"

#include <QList>
#include <QUrl>
#include <QUrlQuery>
#include <QVariantMap>


namespace {

const char *kProtocolKey = "protocol";

struct RegisteredCommand
{
    QString protocol;
    QString commandType;
    DeviceCommandFactory::Creator creator;
};

QList<RegisteredCommand> &registeredCommands()
{
    static QList<RegisteredCommand> commands;
    return commands;
}

class SerialCommand final : public DeviceCommand
{
public:
    explicit SerialCommand(QObject *parent)
        : DeviceCommand(DeviceProtocol::Serial, QStringLiteral("串口指令"), parent)
    {
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::SerialPort));
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::BaudRate));
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::SerialPayload));
    }
};

class Dmx512Command final : public DeviceCommand
{
public:
    explicit Dmx512Command(QObject *parent)
        : DeviceCommand(DeviceProtocol::Dmx512, QStringLiteral("DMX指令"), parent)
    {
        auto *channelField = new DeviceParamSpec(QStringLiteral("channel"),
                                                 QStringLiteral("通道"),
                                                 1,
                                                 DeviceParamSpec::IntType,
                                                 DeviceParamSpec::TextEditor,
                                                 this);
        channelField->setMinimum(1);
        channelField->setMaximum(512);
        addCreationInputField(channelField);

        auto *valueField = new DeviceParamSpec(QStringLiteral("value"),
                                               QStringLiteral("值"),
                                               255,
                                               DeviceParamSpec::IntType,
                                               DeviceParamSpec::SliderEditor,
                                               this);
        valueField->setMinimum(0);
        valueField->setMaximum(255);
        valueField->setStepSize(1);
        addCreationInputField(valueField);
    }
};

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
    explicit PlayDomeVideoCommand(QObject *parent)
        : DeviceCommand_PC(QStringLiteral("播放全景视频"),
                           QStringLiteral("playDomeVideo"),
                           parent)
    {
        auto *videoFileField = new DeviceParamSpec(QStringLiteral("videoFile"),
                                                   QStringLiteral("视频文件"),
                                                   QString(),
                                                   DeviceParamSpec::StringType,
                                                   DeviceParamSpec::TextEditor,
                                                   this);
        videoFileField->setRequired(true);
        addExecutionInputField(videoFileField);
    }

    QVariantMap resolvedParams(const QVariantMap &executionInputValues) const override
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
    explicit VirtualPlaybackCommand(QObject *parent)
        : DeviceCommand_PC(QStringLiteral("虚拟播放"),
                           QStringLiteral("virtualPlayback"),
                           parent)
    {
        addCreationInputField(DeviceParamSpec::createForKey(DeviceKey::Videos));
    }
};

void registerBuiltInCommands()
{
    static const bool registered = [] {
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new DeviceCommand_Http(parent);
        });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new DeviceCommand_PC(parent);
        });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new SerialCommand(parent);
        });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new DeviceCommand_Osc(parent);
        });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new Dmx512Command(parent);
        });
		DeviceCommandFactory::registerCommand([](QObject* parent) -> DeviceCommand* {
			return new OpenVideoCommand(parent);
											  });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new PlayVideoCommand(parent);
        });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new PauseVideoCommand(parent);
        });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new StopVideoCommand(parent);
											  });
		DeviceCommandFactory::registerCommand([](QObject* parent) -> DeviceCommand* {
			return new ClosePlayerCommand(parent);
											  });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new PlayDomeVideoCommand(parent);
        });
        DeviceCommandFactory::registerCommand([](QObject *parent) -> DeviceCommand * {
            return new VirtualPlaybackCommand(parent);
        });
        return true;
    }();
    Q_UNUSED(registered)
}

} // namespace

void DeviceCommandFactory::registerCommand(Creator creator)
{
    if (!creator)
        return;

    DeviceCommand *command = creator(nullptr);
    if (!command)
        return;

    const QString protocol = command->protocol();
    const QString commandType = command->commandType();
    for (const RegisteredCommand &registered : registeredCommands()) {
        if (registered.protocol == protocol && registered.commandType == commandType) {
            delete command;
            return;
        }
    }

    registeredCommands().append({protocol, commandType, creator});
    delete command;
}

DeviceCommand *DeviceCommandFactory::create(const QString &protocol,
                                            const QString &commandType,
                                            QObject *parent)
{
    registerBuiltInCommands();
    const QString protocolValue = protocol.trimmed();
    const QString commandTypeValue = commandType.trimmed();
    for (const RegisteredCommand &registered : registeredCommands()) {
        if (registered.protocol == protocolValue && registered.commandType == commandTypeValue)
            return registered.creator(parent);
    }
    return nullptr;
}

DeviceCommand *DeviceCommandFactory::createForProtocol(const QString &protocol, QObject *parent)
{
    return create(protocol, QString(), parent);
}

DeviceCommand *DeviceCommandFactory::createFromJson(const QJsonObject &json, QObject *parent)
{
    DeviceCommand *command = create(json.value(QString::fromLatin1(kProtocolKey)).toString(),
                                    json.value(DeviceKey::CommandType).toString(),
                                    parent);
    if (!command)
        return nullptr;

    if (!command->loadFromJson(json)) {
        delete command;
        return nullptr;
    }

    return command;
}
