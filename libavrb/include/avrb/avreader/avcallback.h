#ifndef AVCALLBACK_H
#define AVCALLBACK_H
#include "pixeltool/pixeldata.h"

class AVReader;
struct PIXELTOOL_EXPORT AVReaderCallback
{
public:
	virtual ~AVReaderCallback() {}
public:
	//! 帧数据更新回调
	virtual void onVideoDataUpdated(const PixelTool::AVFramePixelData&) {}
	virtual void onAudioDataUpdated(const PixelTool::AVFramePixelData&) {}

	//! 是否使用自定义io
	virtual bool useCustomInput() { return false; }
	virtual int onReadData(void* data, int size) { return 0; }

	virtual bool useCustomOutput() { return false; }
	virtual void onWriteData(const void* data, int size) {}

public:
	AVReader* getReader() { return m_reader; }
private:
	AVReader* m_reader = nullptr;
	friend class AVReader;
};
#endif
