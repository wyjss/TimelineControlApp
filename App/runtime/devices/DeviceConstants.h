#pragma once

#include <QString>
#include <QVariant>
#include <QVector>
#include <QVector2D>



//! 通用的设备类型
namespace DeviceType {
	inline const QString PC = "电脑";
	inline const QString Dmx512Adapter = "Dmx512适配器";
	inline const QString Projector = "投影机";
	inline const QString Light = "灯光";
	inline const QString Sound = "音响";
	inline const QString Locator = "定位器";
	inline const QString Fusion3 = "分布式融合器3.0";
	inline const QString XB809 = "XB809主控";
};

//! 公共key定义，包括DeviceParamSpec::createForKey和指令CommandType
namespace DeviceKey {
	inline const QString Name = "name";
	inline const QString CommandType = "commandType";
	inline const QString Protocol = "protocol";
	//! 通过模板拼接url，支持http/udp/serial
	//! 模板：xxxx${paramName}xxx 
	//! 通过查询param.name == paramName进行插入
	//! @todo 将http/udp/serial统一接入
	//inline const QString StringTemplate = "stringTemplate";

	inline const QString BaudRate = "baudRate";
	inline const QString Dmx512AdapterDeviceId = "dmx512AdapterDeviceId";
	// QVector<int32>的dmx适配器！完整！实时数据
	inline const QString Dmx512Bits = "dmx512Bits";
	// dmx512设备的起始位，指令的offset相对于此
	inline const QString Dmx512BitStart = "dmx512Start";
	// dmx512指令相对Dmx512BitStart的偏移
	inline const QString Dmx512BitOffset = "dmx512Offset";
	// dmx512指令占据的位宽
	inline const QString Dmx512BitCount = "dmx512Count";
	// dmx512指令的实时数据，宽度等于Dmx512BitCount
	inline const QString Dmx512CommandBits = "dmx512CommandBits";


	inline const QString Ip = "ip";
	inline const QString HttpMethod = "httpMethod";
	//inline const QString HttpQueryParams = "httpQueryParams";
	inline const QString HttpBody = "httpBody";
	inline const QString ApiPath = "apiPath";
	inline const QString KeystoneCorrection = "keystoneCorrection";
	inline const QString SerialPayload = "serialPayload";
	// @todo 可以代替 SerialPayload/HttpBody ?
	// 内部使用QString承载
	inline const QString Payload = "payload";
	// 载荷类型，Text（默认）、Hex
	// 只用于提示数据处理（数据发送和模板key），不能控制ui输入模式
	// 串口默认hex，不需要这个参数
	// udp根据PayloadType理解Payload
	inline const QString PayloadType = "payloadType";
	inline const QString PayloadType_Text = "Text";
	inline const QString PayloadType_Hex = "Hex";
	//
	inline const QString Port = "port";
	inline const QString VirtualScreenWidth = "virtualScreenWidth";
	inline const QString VirtualScreenHeight = "virtualScreenHeight";
	inline const QString ScreenColumns = "screenColumns";
	inline const QString ScreenHeight = "screenHeight";
	inline const QString ScreenRows = "screenRows";
	inline const QString ScreenWidth = "screenWidth";
	inline const QString SerialPort = "serialPort";
	inline const QString VideoFile = "videoFile";
	inline const QString VideoTimeSec = "videoTimeSec";

	// 已废弃，用VideoWindow*代替。
	// @todo 目前只用来做兼容，后期删除
	inline const QString Rect = "rect";
	// 播放窗口rect（在虚拟屏幕内）
	// 替代Rect
	inline const QString VideoWindowX = "videoWindowX";
	inline const QString VideoWindowY = "videoWindowY";
	inline const QString VideoWindowW = "videoWindowW";
	inline const QString VideoWindowH = "videoWindowH";

	inline const QString VideoSrcX = "videoSrcX";
	inline const QString VideoSrcY = "videoSrcY";
	inline const QString VideoSrcW = "videoSrcW";
	inline const QString VideoSrcH = "videoSrcH";

	// 定位器坐标，VMap["lon" "lat"]
	inline const QString Location = "location";

	// 时间线选择
	inline const QString Timeline = "timeline";

	// 特殊指令
	inline const QString PowerOn = "powerOn";
	inline const QString PowerOff = "powerOff";
	inline const QString Pause = "pause";


	//////////////////////////////////////////////////////////////////////////
	// PC-视频控制指令
	inline const QString CommandOpenVideo = "openVideo";
	inline const QString CommandPlayVideo = "playVideo";
	inline const QString CommandPauseVideo = "pauseVideo";
	inline const QString CommandStopVideo = "closeVideo";
	inline const QString CommandClosePlayer = "closePlayer";
	//inline const QString CommandPlayDomeVideo = "playDomeVideo";


	//////////////////////////////////////////////////////////////////////////
	// 系统控制指令，为了兼容外部创建，只用作名称
	inline const QString SystemPause = "系统暂停";
	inline const QString SystemResume = "系统恢复";
	inline const QString SystemStop = "系统停止";
} // namespace DeviceKey

namespace DeviceConstants {
	inline const QString LocalVideoPrefix = "D:/video/";
}

//! 设备协议名称定义
namespace DeviceProtocol {
	inline const QString Null = "null";
	inline const QString Dmx512 = "dmx512";
	inline const QString Http = "http";
	inline const QString Udp = "udp";
	inline const QString Serial = "serial";
	inline const QString Pc = "pc";
	inline const QString Internal = "internal";
}

//! 通用的patterns
namespace DevicePattern {
	inline const QString Ip = "^\\d{1,3}(?:\\.\\d{1,3}){3}$";
	inline const QString Rect = "^\\d+(,\\d+){3}$";
	inline const QString Dmx = R"(^(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)(?:,(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d))*$)";
}

struct DeviceKeystoneCorrectionItem {
	// 屏幕 layout 的索引，从左到右、从上到下。
	// -1 表示整个 PC 总画布。
	// >= 0 表示某一块屏幕
	int screenIndex = -1;
	QVector2D topLeft;
	QVector2D topRight;
	QVector2D bottomRight;
	QVector2D bottomLeft;
};

