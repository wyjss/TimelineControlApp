#include "devices/DeviceCommandFactory.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"
#include "LogMacros.h"

#include <QJsonArray>
#include <QList>
#include <QUrl>
#include <QUrlQuery>
#include <QVariantMap>


namespace {

const char *kProtocolKey = "protocol";
const char *kCreationInputFieldSpecsKey = "creationInputFieldSpecs";
const char *kExecutionInputFieldSpecsKey = "executionInputFieldSpecs";

bool applyFieldSpec(DeviceParamSpec *field, const QJsonObject &json)
{
    const QVariant defaultValue = json.value(QStringLiteral("defaultValue")).toVariant();
    field->setLabel(json.value(QStringLiteral("label")).toString());
    field->setSubtitle(json.value(QStringLiteral("subtitle")).toString());
    field->setValueType(static_cast<DeviceParamSpec::ValueType>(
        json.value(QStringLiteral("valueType")).toInt(DeviceParamSpec::VariantType)));
    field->setEditorHint(static_cast<DeviceParamSpec::EditorHint>(
        json.value(QStringLiteral("editorHint")).toInt(DeviceParamSpec::AutoEditor)));
    field->setDefaultValue(defaultValue);
    field->setValue(defaultValue);
    field->setRequired(json.value(QStringLiteral("required")).toBool());
    field->setReadOnly(json.value(QStringLiteral("readOnly")).toBool());
    field->setPlaceholderText(json.value(QStringLiteral("placeholderText")).toString());
    field->setPattern(json.value(QStringLiteral("pattern")).toString());
    field->setMinimum(json.value(QStringLiteral("minimum")).toDouble());
    field->setMaximum(json.value(QStringLiteral("maximum")).toDouble());
    field->setStepSize(json.value(QStringLiteral("stepSize")).toDouble());
    field->setSuffix(json.value(QStringLiteral("suffix")).toString());
    const QString optionSource = json.value(QStringLiteral("optionSource")).toString().trimmed();
    if (optionSource.isEmpty())
        field->setOptions(json.value(QStringLiteral("options")).toArray().toVariantList());
    else if (optionSource != QStringLiteral("timelines"))
        return false;
    return true;
}

DeviceParamSpec *fieldFromJson(const QJsonObject &json,
                               TimelineModel *timelineModel,
                               QObject *parent)
{
    const QString key = json.value(QStringLiteral("key")).toString().trimmed();
    if (key.isEmpty())
        return nullptr;

    const QString optionSource = json.value(QStringLiteral("optionSource")).toString().trimmed();
    DeviceParamSpec *field = optionSource == QStringLiteral("timelines")
        ? DeviceParamSpec::createForKey(DeviceKey::Timeline, timelineModel)
        : (optionSource.isEmpty() ? new DeviceParamSpec(parent) : nullptr);
    if (!field)
        return nullptr;
    if (field->parent() != parent)
        field->setParent(parent);
    field->setKey(key);
    if (!applyFieldSpec(field, json)) {
        delete field;
        return nullptr;
    }
    return field;
}

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

///↓↓↓↓↓commandType指令↓↓↓↓↓

class UdpStrTemplateCommand : public DeviceCommand_Internal
{
public:
    UdpStrTemplateCommand(QObject* parent)
        : DeviceCommand_Internal(parent)
    {
        
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
		DeviceCommandFactory::registerCommand([](QObject* parent) -> DeviceCommand* {
			return new DeviceCommand_Internal(parent);
											  });
		DeviceCommandFactory::registerCommand([](QObject* parent) -> DeviceCommand* {
			return new DeviceCommand_Udp(parent);
											  });
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

DeviceCommand *DeviceCommandFactory::createFromJson(const QJsonObject &json,
                                                    QObject *parent,
                                                    TimelineModel *timelineModel)
{
    const bool nativeCommand = json.contains(DeviceKey::CommandType);
    const QString protocol = json.value(QString::fromLatin1(kProtocolKey)).toString();
    const QString commandType = json.value(DeviceKey::CommandType).toString().trimmed();
    if (nativeCommand && commandType.isEmpty())
        return nullptr;

    DeviceCommand *command = nativeCommand
        ? create(protocol, commandType, parent)
        : createForProtocol(protocol, parent);
    if (!command)
        return nullptr;

    if (!nativeCommand) {
        const auto addFields = [command, timelineModel, &json](const char *key,
                                                               bool executionFields) {
            const QJsonArray fields = json.value(QString::fromLatin1(key)).toArray();
            for (const QJsonValue &value : fields) {
                const QJsonObject fieldJson = value.toObject();
                const QString fieldKey = fieldJson.value(QStringLiteral("key")).toString();
                if (!executionFields) {
                    if (DeviceParamSpec *field = command->getField(fieldKey)) {
                        if (!applyFieldSpec(field, fieldJson))
                            return false;
                        continue;
                    }
                }

                DeviceParamSpec *field = fieldFromJson(fieldJson, timelineModel, command);
                if (!field)
                    return false;
                if (executionFields)
                    command->addExecutionInputField(field);
                else
                    command->addCreationInputField(field);
            }
            return true;
        };

        if (!addFields(kCreationInputFieldSpecsKey, false)
            || !addFields(kExecutionInputFieldSpecsKey, true)) {
            delete command;
            return nullptr;
        }
    }

    if (!command->loadFromJson(json)) {
        delete command;
        return nullptr;
    }

    return command;
}
