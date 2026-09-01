#include "devices/backends/Fusion3.h"

#include "devices/DeviceCommand.h"
#include "devices/DeviceConstants.h"

#define LC "[Fusion3DeviceTemplate] "
#include "LogMacros.h"
namespace {

QList<DeviceParamSpec *> createFusion3Params()
{
    auto *port = DeviceParamSpec::createForKey(DeviceKey::Port);
    port->setValue(9999);
    port->setDefaultValue(9999);
    return {port};
}

DeviceCommand *createFusion3Command(const QString &name,
                                    const QString &stringTemplate,
                                    const QString &paramKey = QString(),
                                    const QString &paramLabel = QString(),
                                    const QVariant &value = QVariant(),
                                    double minimum = 0,
                                    double maximum = 0)
{
    DeviceCommand *command = DeviceCommand::createForProtocol(DeviceProtocol::Udp);
    command->setName(name);
    command->getField(DeviceKey::Payload)->setValue(stringTemplate);
    command->setStringTemplateKey(DeviceKey::Payload);

    if (!paramKey.isEmpty()) {
        auto *param = new DeviceParamSpec(paramKey, paramLabel, value);
        param->setMinimum(minimum);
        param->setMaximum(maximum);
        command->addExecutionInputField(param);
    }
    return command;
}

QList<DeviceCommand *> createFusion3Commands()
{
    return {
        createFusion3Command("播放视频", R"({"_msg":"v_play","_p":"${videoIndex}"})", "videoIndex", "视频索引", 0, 99),
        createFusion3Command("暂停", R"({"_msg":"v_pause"})"),
        createFusion3Command("继续", R"({"_msg":"v_resume"})"),
        createFusion3Command("停止", R"({"_msg":"stop"})"),
        createFusion3Command("上一曲", R"({"_msg":"v_prev"})"),
        createFusion3Command("下一曲", R"({"_msg":"v_next"})"),
        createFusion3Command("循环模式", R"({"_msg":"set_loop","_p":"${loopMode}"})", "loopMode", "循环模式", 0, 3),
        createFusion3Command("视频定位", R"({"_msg":"seek","_p":${sec}})", "sec", "秒", 0, 9999),
        createFusion3Command("前进10秒", R"({"_msg":"forward"})"),
        createFusion3Command("后退10秒", R"({"_msg":"rewind"})"),
        createFusion3Command("前进或者后退", R"({"_msg":"move","_p":"${sec}"})", "sec", "秒数", -999, 999),
        createFusion3Command("声音大小", R"({"_msg":"vol","_p":"${volume}"})", "volume", "音量", 0, 100),
        createFusion3Command("静音", R"({"_msg":"mute"})"),
        createFusion3Command("取消静音", R"({"_msg":"un_mute"})"),
        createFusion3Command("音量-", R"({"_msg":"vol-"})"),
        createFusion3Command("音量+", R"({"_msg":"vol+"})"),
        createFusion3Command("播放第几张图片", R"({"_msg":"p_play","_p":"${imageIndex}"})", "imageIndex", "图片索引", 0, 999),
        createFusion3Command("上一张", R"({"_msg":"p_prev"})"),
        createFusion3Command("下一张", R"({"_msg":"p_next"})"),
        createFusion3Command("播放第几个播单", R"({"_msg":"ls_index","_p":"${playIndex}"})", "playIndex", "播单索引", 0, 999),
        createFusion3Command("上一播单", R"({"_msg":"pl_prev"})"),
        createFusion3Command("下一播单", R"({"_msg":"pl_next"})"),
        createFusion3Command("选播单内曲目", R"({"_msg":"ls_sub","_p":"${index}"})", "index", "曲目索引", 0, 999),
        createFusion3Command("遮罩开", R"({"_msg":"show_mask","_p":"1"})"),
        createFusion3Command("遮罩关", R"({"_msg":"show_mask","_p":"0"})"),
        createFusion3Command("采集开", R"({"_msg":"show_capture","_p":"1"})"),
        createFusion3Command("采集关", R"({"_msg":"show_capture","_p":"0"})"),
        createFusion3Command("跑马灯开", R"({"_msg":"floating","_p":"1"})"),
        createFusion3Command("跑马灯关", R"({"_msg":"floating","_p":"0"})"),
        createFusion3Command("重启", R"({"_msg":"reboot"})"),
        createFusion3Command("开机", R"({"_msg":"on"})"),
        createFusion3Command("关机", R"({"_msg":"off"})")
    };
}

} // namespace

Fusion3DeviceTemplate::Fusion3DeviceTemplate(QObject *parent)
    : DeviceTemplate(QStringLiteral("分布式融合器"),
                     DeviceType::Fusion3,
                     QStringList{DeviceProtocol::Udp},
                     QStringLiteral("分布式融合器3.0设备"),
                     createFusion3Params(),
                     createFusion3Commands(),
                     parent)
{
}
