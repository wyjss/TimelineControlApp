#include "devices/DeviceParamSpec.h"
#include "devices/DeviceConstants.h"
#include <QColor>
#include <QRegularExpression>
#include <QDir>

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

QString DeviceParamSpec::typeName() const
{
    return typeName(valueType());
}

DeviceParamSpec *DeviceParamSpec::clone(QObject *parent) const
{
    auto *field = new DeviceParamSpec(parent);
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

DeviceParamSpec *DeviceParamSpec::createForKey(const QString &deviceKey)
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
        spec->setOptions(QVariantList{
            QVariantMap{{QStringLiteral("label"), QStringLiteral("GET")},
                        {QStringLiteral("value"), QStringLiteral("GET")}},
            QVariantMap{{QStringLiteral("label"), QStringLiteral("POST")},
                        {QStringLiteral("value"), QStringLiteral("POST")}}
        });
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

	if (deviceKey == DeviceKey::OscTransProtocol) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("传输协议"),
										 QString(),
                                         SelectType,
                                         SelectEditor);
        spec->setValue("UDP");
        spec->setDefaultValue("UDP");
        spec->setOptions(QVariantList{"UDP", "TCP"});
		return spec;
	}

    if (deviceKey == DeviceKey::OscMessage)
        return new DeviceParamSpec(deviceKey,
                                   QStringLiteral("OSC消息"),
                                   QString(),
                                   StringType,
                                   TextEditor);

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
        // @todo read video dir
        static QVariantList s_videos = []()->QVariantList {
            QVariantList videos;
            QDir dir(DeviceConstants::LocalVideoPrefix);
            auto infos = dir.entryInfoList({"*.mp4", "*.avi"});
            for (const auto& info : infos) {
                videos.push_back(QString("$") + info.fileName());
            }
            return videos;
        }();
        spec->setOptions(s_videos);
		return spec;
	}

    if (deviceKey == DeviceKey::Rect) {
		auto* spec = new DeviceParamSpec(deviceKey,
										 QStringLiteral("目标矩形（x,y,w,h）"),
										 "",
										 StringType,
										 TextEditor);
        spec->setPattern(DevicePattern::Rect);
        return spec;
    }

    return nullptr;
}
