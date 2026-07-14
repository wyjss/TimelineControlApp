#include "devices/DeviceCommandFactory.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#include <QList>
#include <QUrl>
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

class PlayVideoCommand : public DeviceCommand_PC
{
public:
    explicit PlayVideoCommand(QObject *parent)
        : DeviceCommand_PC(QStringLiteral("播放视频"),
                           QStringLiteral("playVideo"),
                           parent)
    {
        auto *videoFileField = new DeviceParamSpec(QStringLiteral("videoFile"),
                                                   QStringLiteral("视频文件"),
                                                   QString(),
                                                   DeviceParamSpec::StringType,
                                                   DeviceParamSpec::TextEditor,
                                                   this);
        videoFileField->setRequired(false);
        addExecutionInputField(videoFileField);
    }

    virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
    {
        auto params = DeviceCommand_PC::resolvedParams(executionInputValues);
        QString api = "/video/play";
        QString url = executionInputValues.value("videoFile", "").toString();
        if (!url.isEmpty()) {
            api += QString("?url=%1").arg(url);
            params[DeviceKey::Name] = this->name() + "-" + url;
        }
        params[DeviceKey::ApiPath] = api;
        return params;
    }
};

class PauseVideoCommand : public DeviceCommand_PC
{
public:
	explicit PauseVideoCommand(QObject* parent)
		: DeviceCommand_PC(QStringLiteral("暂停播放"),
						   QStringLiteral("pauseVideo"),
						   parent)
	{
		auto* videoFileField = new DeviceParamSpec(QStringLiteral("videoFile"),
												   QStringLiteral("视频文件"),
												   QString(),
												   DeviceParamSpec::StringType,
												   DeviceParamSpec::TextEditor,
												   this);
		videoFileField->setRequired(false);
		addExecutionInputField(videoFileField);
	}

	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
	{
		auto params = DeviceCommand_PC::resolvedParams(executionInputValues);
		QString api = "/video/pause";
		QString url = executionInputValues.value("videoFile", "").toString();
		if (!url.isEmpty()) {
			api += QString("?url=%1").arg(url);
			params[DeviceKey::Name] = this->name() + "-" + url;
		}
		params[DeviceKey::ApiPath] = api;
		return params;
	}
};

class StopVideoCommand : public DeviceCommand_PC
{
public:
	explicit StopVideoCommand(QObject* parent)
		: DeviceCommand_PC(QStringLiteral("停止播放"),
						   QStringLiteral("stopVideo"),
						   parent)
	{
		auto* videoFileField = new DeviceParamSpec(QStringLiteral("videoFile"),
												   QStringLiteral("视频文件"),
												   QString(),
												   DeviceParamSpec::StringType,
												   DeviceParamSpec::TextEditor,
												   this);
		videoFileField->setRequired(false);
		addExecutionInputField(videoFileField);
	}

	virtual QVariantMap resolvedParams(const QVariantMap& executionInputValues = QVariantMap()) const override
	{
		auto params = DeviceCommand_PC::resolvedParams(executionInputValues);
		QString api = "/video/stop";
		QString url = executionInputValues.value("videoFile", "").toString();
		if (!url.isEmpty()) {
			api += QString("?url=%1").arg(url);
			params[DeviceKey::Name] = this->name() + "-" + url;
		}
		params[DeviceKey::ApiPath] = api;
		return params;
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
            return new Dmx512Command(parent);
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
