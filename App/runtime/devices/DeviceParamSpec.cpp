#include "devices/DeviceParamSpec.h"
#include "devices/DeviceConstants.h"
#include "timeline/Timeline.h"
#include "timeline/TimelineModel.h"
#include "utils.h"
#include <QColor>
#include <QRegularExpression>

DeviceParamSpec::DeviceParamSpec(QObject *parent)
    : BaseField(parent)
{
    setRequired(true);
}

DeviceParamSpec::DeviceParamSpec(const QString &key,
                                 const QString &label,
                                 const QVariant &value,
                                 ValueType valueType,
                                 EditorHint editorHint,
                                 QObject *parent)
    : BaseField(parent)
{
    const QVariant normalized = normalizedValue(valueType, value);

    setKey(key);
    setLabel(label);
    setValueType(valueType);
    setEditorHint(editorHint);
    setValue(normalized);
    setDefaultValue(normalized);
    setRequired(true);
}

QVariant DeviceParamSpec::defaultValue() const
{
    return m_defaultValue;
}

void DeviceParamSpec::setDefaultValue(const QVariant &defaultValue)
{
    if (m_defaultValue == defaultValue)
        return;

    m_defaultValue = defaultValue;
    emit defaultValueChanged();
}

QString DeviceParamSpec::pattern() const
{
    return m_pattern;
}

void DeviceParamSpec::setPattern(const QString &pattern)
{
    if (m_pattern == pattern)
        return;

    m_pattern = pattern;
    emit patternChanged();
}

QString DeviceParamSpec::typeName() const
{
    return typeName(valueType());
}

DeviceParamSpec *DeviceParamSpec::clone(QObject *parent) const
{
    auto *field = m_timelineModel
        ? createForKey(key(), m_timelineModel)
        : new DeviceParamSpec(parent);
    if (field->parent() != parent)
        field->setParent(parent);
    field->setKey(key());
    field->setLabel(label());
    field->setSubtitle(subtitle());
    field->setValueType(valueType());
    field->setEditorHint(editorHint());
    field->setValue(value());
    field->setDefaultValue(defaultValue());
    field->setRequired(required());
    field->setReadOnly(readOnly());
    field->setOptions(options());
    field->setPlaceholderText(placeholderText());
    field->setPattern(pattern());
    field->setMinimum(minimum());
    field->setMaximum(maximum());
    field->setStepSize(stepSize());
    field->setSuffix(suffix());
    return field;
}

QString DeviceParamSpec::invalidReason(const QVariant &value) const
{
    const QVariant checkedValue = value.isValid() ? value : this->value();
    const QString labelText = label().isEmpty() ? key() : label();
    const QString text = checkedValue.toString();
    if (required() && text.isEmpty())
        return tr("%1 必填").arg(labelText);
    if (text.isEmpty())
        return QString();

    if (!pattern().isEmpty()) {
        const QRegularExpression expression(pattern());
        if (!expression.isValid())
            return tr("%1 的校验规则无效").arg(labelText);
        if (!expression.match(text).hasMatch())
            return tr("%1 格式无效").arg(labelText);
    }

    if (valueType() == IntType || valueType() == DoubleType) {
        bool ok = false;
        const double numberValue = checkedValue.toDouble(&ok);
        if (!ok)
            return tr("%1 必须是数字").arg(labelText);
        if (numberValue < minimum())
            return tr("%1 低于最小值").arg(labelText);
        if (numberValue > maximum())
            return tr("%1 高于最大值").arg(labelText);
    }

    return QString();
}

QString DeviceParamSpec::typeName(ValueType valueType)
{
    switch (valueType) {
    case IntType:
        return QStringLiteral("整数");
    case DoubleType:
        return QStringLiteral("小数");
    case StringType:
        return QStringLiteral("文本");
    case BoolType:
        return QStringLiteral("布尔");
    case SelectType:
        return QStringLiteral("选项");
    case ColorType:
        return QStringLiteral("颜色");
    case VariantType:
        return QStringLiteral("通用");
    case InvalidType:
        break;
    }

    return QStringLiteral("无效");
}

QVariant DeviceParamSpec::normalizedValue(ValueType valueType, const QVariant &value)
{
    switch (valueType) {
    case IntType:
        return value.toInt();
    case DoubleType:
        return value.toDouble();
    case StringType:
    case SelectType:
        return value.toString();
    case BoolType:
        return value.toBool();
    case ColorType:
        return value.value<QColor>();
    case VariantType:
    case InvalidType:
        break;
    }

    return value;
}

DeviceParamSpec *DeviceParamSpec::createForKey(const QString &deviceKey,
                                               TimelineModel *timelineModel)
{
    if (deviceKey == DeviceKey::Name) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("名称"),
                                         QString(),
                                         StringType,
                                         TextEditor);
        spec->setPattern(QStringLiteral("^\\S+$"));
        return spec;
    }

    if (deviceKey == DeviceKey::Ip) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("主机IP"),
                                         QStringLiteral("127.0.0.1"),
                                         StringType,
                                         TextEditor);
        spec->setPattern(DevicePattern::Ip);
        spec->setPlaceholderText(QStringLiteral("192.168.1.10"));
        return spec;
    }

    if (deviceKey == DeviceKey::Port) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("端口"),
                                         8080,
                                         IntType,
                                         TextEditor);
        spec->setMinimum(1);
        spec->setMaximum(65535);
        return spec;
    }

    if (deviceKey == DeviceKey::SerialPort) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("串口"),
                                         QStringLiteral("COM0"),
                                         SelectType,
                                         SelectEditor);
        spec->setPlaceholderText(QStringLiteral("COM1"));
        QVariantList options;
        for (int i = 0; i < 10; ++i)
            options.append(QStringLiteral("COM%1").arg(i));
        spec->setOptions(options);
        return spec;
    }

    //if (deviceKey == DeviceKey::StringTemplate) {
	//	auto* spec = new DeviceParamSpec(deviceKey,
	//									 QStringLiteral("字符模板"),
	//									 "",
	//									 StringType,
	//									 TextEditor);
    //    return spec;
    //}

    if (deviceKey == DeviceKey::BaudRate) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("波特率"),
                                         9600,
                                         IntType,
                                         SelectEditor);
        spec->setMinimum(1);
        spec->setMaximum(4000000);
        spec->setOptions(QVariantList{9600, 19200, 38400, 57600, 115200});
        return spec;
    }

    if (deviceKey == DeviceKey::HttpMethod) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("方法"),
                                         QStringLiteral("GET"),
                                         SelectType,
                                         SelectEditor);
        spec->setOptions({Utils::makeOption("GET", "GET"),
                          Utils::makeOption("POST", "POST")});
        return spec;
    }

    if (deviceKey == DeviceKey::ApiPath) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("路径"),
                                         QString(),
                                         StringType,
                                         TextEditor);
        spec->setPattern(QStringLiteral("^/.*"));
        spec->setPlaceholderText(QStringLiteral("/api/command"));
        return spec;
    }

    if (deviceKey == DeviceKey::HttpBody) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("内容"),
                                         QString(),
                                         StringType,
                                         TextEditor);
        spec->setRequired(false);
        return spec;
    }

    if (deviceKey == DeviceKey::SerialPayload) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         QStringLiteral("数据内容"),
                                         QString(),
                                         StringType,
                                         TextEditor);
        spec->setPlaceholderText(QStringLiteral("A5 5A 01 00"));
        spec->setPattern(QStringLiteral("^([0-9A-Fa-f]{2})(\\s+[0-9A-Fa-f]{2})*$"));
        return spec;
    }

	if (deviceKey == DeviceKey::Payload) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("载荷"),
										 QString(),
										 StringType,
										 TextEditor);
		spec->setPlaceholderText(QStringLiteral(""));
		return spec;
	}

	if (deviceKey == DeviceKey::VirtualScreenWidth || deviceKey == DeviceKey::VirtualScreenHeight) {
		const bool width = deviceKey == DeviceKey::VirtualScreenWidth;
		auto* spec = new DeviceParamSpec(deviceKey,
										 width ? QStringLiteral("虚拟大屏宽度") : QStringLiteral("虚拟大屏高度"),
										 width ? 1920 : 1080,
										 IntType,
										 TextEditor);
		spec->setMinimum(1);
		spec->setMaximum(16384);
		return spec;
	}

    if (deviceKey == DeviceKey::ScreenWidth || deviceKey == DeviceKey::ScreenHeight) {
        const bool width = deviceKey == DeviceKey::ScreenWidth;
        auto *spec = new DeviceParamSpec(deviceKey,
                                         width ? QStringLiteral("单屏宽度") : QStringLiteral("单屏高度"),
                                         width ? 1920 : 1080,
                                         IntType,
                                         TextEditor);
        spec->setMinimum(1);
        spec->setMaximum(16384);
        return spec;
    }

    if (deviceKey == DeviceKey::ScreenColumns || deviceKey == DeviceKey::ScreenRows) {
        auto *spec = new DeviceParamSpec(deviceKey,
                                         deviceKey == DeviceKey::ScreenColumns
                                             ? QStringLiteral("屏幕列数")
                                             : QStringLiteral("屏幕行数"),
                                         1,
                                         IntType,
                                         TextEditor);
        spec->setMinimum(1);
        spec->setMaximum(64);
        return spec;
    }

    if (deviceKey == DeviceKey::Dmx512AdapterDeviceId)
        return new DeviceParamSpec(deviceKey,
                                   QStringLiteral("目标DMX512适配器"),
                                   QString(),
                                   SelectType,
                                   SelectEditor);

	if (deviceKey == DeviceKey::Dmx512Bits) {
		auto vs = QVector<qint32>(512, 0);
		auto param = new DeviceParamSpec(deviceKey,
										 QStringLiteral("目标DMX512适配器"),
										 QVariant::fromValue(vs),
										 VariantType,
										 CustomEditor);
		param->setReadOnly(true);
		return param;
	}

	if (deviceKey == DeviceKey::Dmx512BitStart) {
		auto param = new DeviceParamSpec(deviceKey,
										 QStringLiteral("起始位"),
										 0,
										 IntType,
										 AutoEditor);
		param->setMinimum(0);
		param->setMaximum(511);
		param->setReadOnly(false);
		return param;
	}

	if (deviceKey == DeviceKey::Dmx512BitOffset) {
		auto param = new DeviceParamSpec(deviceKey,
										 QStringLiteral("偏移位（相对起始）"),
										 0,
										 IntType,
										 AutoEditor);
		param->setMinimum(0);
		param->setMaximum(511);
		param->setReadOnly(false);
		return param;
	}

	if (deviceKey == DeviceKey::Dmx512BitCount) {
		auto param = new DeviceParamSpec(deviceKey,
										 QStringLiteral("指令宽度"),
										 1,
										 IntType,
										 AutoEditor);
		param->setMinimum(1);
		param->setMaximum(511);
		param->setReadOnly(false);
		return param;
	}

	if (deviceKey == DeviceKey::Dmx512CommandBits) {
		
		auto param = new DeviceParamSpec(deviceKey,
										 QStringLiteral("指令数据"),
										 "",
										 StringType,
										 TextEditor);
        param->setPattern(DevicePattern::Dmx);
		param->setReadOnly(false);
		return param;
	}

	if (deviceKey == DeviceKey::Videos) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("视频"),
										 QVariantList(),
										 VariantType,
										 CustomEditor);
		spec->setRequired(false);
		spec->setReadOnly(true);
		return spec;
	}

	if (deviceKey == DeviceKey::VideoFile) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("视频文件"),
										 "",
										 SelectType,
										 SelectEditor);
		spec->setRequired(true);
		spec->setReadOnly(false);
        spec->setOptions(Utils::getVideoOptions());
		return spec;
	}

// 	if (deviceKey == DeviceKey::Rect) {
// 		auto* spec = new DeviceParamSpec(deviceKey,
// 										 QStringLiteral("目标矩形（x,y,w,h）"),
// 										 "",
// 										 StringType,
// 										 TextEditor);
// 		spec->setPattern(DevicePattern::Rect);
// 		return spec;
// 	}

	if (deviceKey == DeviceKey::VideoWindowX) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("视频窗口起点x坐标"),
										 0,
										 IntType,
										 AutoEditor);
		return spec;
	}
	if (deviceKey == DeviceKey::VideoWindowY) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("视频窗口起点y坐标"),
										 0,
										 IntType,
										 AutoEditor);
		return spec;
	}
	if (deviceKey == DeviceKey::VideoWindowW) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("视频窗口宽度"),
										 1920,
										 IntType,
										 AutoEditor);
		spec->setMinimum(1);
		spec->setMaximum(9999);
		return spec;
	}
	if (deviceKey == DeviceKey::VideoWindowH) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("视频窗口高度"),
										 1080,
										 IntType,
										 AutoEditor);
		spec->setMinimum(1);
        spec->setMaximum(9999);
		return spec;
	}

	if (deviceKey == DeviceKey::VideoSrcX) {
		auto* spec = new DeviceParamSpec(deviceKey,
			QStringLiteral("视频源起点x坐标"),
			0,
			IntType,
			AutoEditor);
		return spec;
	}
	if (deviceKey == DeviceKey::VideoSrcY) {
		auto* spec = new DeviceParamSpec(deviceKey,
			QStringLiteral("视频源起点y坐标"),
			0,
			IntType,
			AutoEditor);
		return spec;
	}
	if (deviceKey == DeviceKey::VideoSrcW) {
		auto* spec = new DeviceParamSpec(deviceKey,
			QStringLiteral("视频源宽度"),
			0,
			IntType,
			AutoEditor);
		spec->setMinimum(0);
		spec->setMaximum(9999);
		return spec;
	}
	if (deviceKey == DeviceKey::VideoSrcH) {
		auto* spec = new DeviceParamSpec(deviceKey,
			QStringLiteral("视频源高度"),
			0,
			IntType,
			AutoEditor);
		spec->setMinimum(0);
		spec->setMaximum(9999);
		return spec;
	}

	if (deviceKey == DeviceKey::Location) {
        QVariantMap vm;
        vm["lon"] = 0;
        vm["lat"] = 0;

		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("坐标"),
										 vm,
                                         VariantType,
                                         CustomEditor);
        spec->setReadOnly(true);
		return spec;
	}

	if (deviceKey == DeviceKey::Timeline) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("时间线"),
										 "",
                                         SelectType,
                                         SelectEditor);
        spec->setRequired(true);
		spec->m_timelineModel = timelineModel;
		if (timelineModel) {
			const auto func_updateTimelineOpts = [spec, timelineModel]() {
				QVariantList options;
				options.reserve(timelineModel->count());
				for (int index = 0; index < timelineModel->count(); ++index) {
					const Timeline *timeline = timelineModel->timelineAt(index);
					if (timeline) {
						options.append(Utils::makeOption(timeline->name(), timeline->id()));
					}
				}
				spec->setOptions(options);
			};
			connect(timelineModel, &TimelineModel::timelinesChanged,
					spec, func_updateTimelineOpts);
			func_updateTimelineOpts();
		}
		return spec;
	}

    return nullptr;
}
