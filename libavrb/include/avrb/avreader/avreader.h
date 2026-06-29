#ifndef AVREADER_H
#define AVREADER_H

#include <climits>
#include <string>
#include <memory>

#include "avutil/export.h"
#include "pixeltool/pixeldata.h"
class AVReaderPrivate;
struct AVReaderCallback;

struct AVREADERWRITER_EXPORT AVReaderOptions
{
	//! 输入文件
	//!		本地媒体文件
	//!		流url
	//!		desktop	（录屏）
	std::string avPath;
	
	//! 打开超时时间
	int maxOpenDelayMS = 3000;

	//! 是否优先硬解
	bool hw = false;
	
	//! 是否循环播放，仅对本地媒体文件有效
	bool loop = false;

	//! 是否输出图像数据
	bool outputVideoFrame = true;

	//! 是否输出音频数据
	bool outputAudioFrame = false;

	//! 转发地址，对打开的输入二次编码输出
	//! 本地文件地址/网络流地址
	std::string forwardingAddress;

	//! desktop 采集参数，仅 avPath 为 "desktop" 时生效。
	std::string title;
	int capFps = 15;
	int capX = INT_MIN;
	int capY = INT_MIN;
	int capW = -1;
	int capH = -1;

	//! 回调
	std::shared_ptr<AVReaderCallback> cb;
};

struct AVREADERWRITER_EXPORT AVReaderOutputInfo
{
	double currentTime;
	double duration;

	bool hasVideoData;
	int w;
	int h;
	int pixelFormat;
	double fps;

	bool hasAudioData;
	int frequency;
	int channels;
	int sampleSize;
	int frameSize;

	AVReaderOutputInfo()
		: currentTime(0.0)
		, duration(0.0)
		, hasVideoData(false)
		, w(0)
		, h(0)
		, pixelFormat(-1)
		, fps(0.0)
		, hasAudioData(false)
		, frequency(0)
		, channels(0)
		, sampleSize(0)
		, frameSize(0)
	{
	}
};

class AVREADERWRITER_EXPORT AVReader
{
public:
	AVReader();
	~AVReader();

	bool open(const AVReaderOptions& options);
	bool play();
	bool pause();
	bool speed(double speed = 1.0);
	bool seek(double timeSeconds);
	bool quit(unsigned long timeoutMS = 3000);
	bool isRunning() const;
	bool getOutputInfo(AVReaderOutputInfo& info) const;

	PixelTool::AVFramePixelDataPtr takeVideoFrame();
	PixelTool::AVFramePixelDataPtr takeAudioFrame();

private:
	AVReaderPrivate* m_d;
};

#endif // AVREADER_H
