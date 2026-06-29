#pragma once

#include <QtCore/qglobal.h>
#include <QList>
#include <QMutex>
#include <QSet>

#include "pixeltool/pixeldata.h"

#ifndef PIXELTOOL_EXPORT
# ifdef PIXELTOOL_LIB
#  define PIXELTOOL_EXPORT Q_DECL_EXPORT
# else
#  define PIXELTOOL_EXPORT Q_DECL_IMPORT
# endif
#endif

struct AVFrame;
struct AVChannelLayout;
struct SwsContext;

namespace PixelTool {

PIXELTOOL_EXPORT PixelData* ConvRgbToYuv(const void* rgb, int width, int height);

class PIXELTOOL_EXPORT AVFrameFactory
{
public:
	explicit AVFrameFactory(int maxCache = 3);
	~AVFrameFactory();

	AVFrameFactory(const AVFrameFactory&) = delete;
	AVFrameFactory& operator=(const AVFrameFactory&) = delete;

	AVFrame* popFrame();
	AVFrame* popVideoFrame(int width, int height, int format, int align = 32);
	AVFrame* popAudioFrame(const AVChannelLayout& channelLayout, int nbSamples, int format, int align = 0);
	AVFramePixelDataPtr pop();
	AVFramePixelDataPtr popVideo(int width, int height, int format, int align = 32);
	AVFramePixelDataPtr wrap(AVFrame* frame);
	void push(AVFrame* frame);
	

	void clear();
private:
	AVFrame* takeFrame();
	void recycle(AVFramePixelData* framePixelData);
	void recycle(AVFrame* frame);
	static bool matchVideoBuffer(const AVFrame* frame, int width, int height, int format);
	static AVFrame* prepareVideoBuffer(AVFrame* frame, int width, int height, int format, int align);
	static AVFrame* prepareAudioBuffer(AVFrame* frame, const AVChannelLayout& channelLayout, int nbSamples, int format, int align);
private:
	QList<AVFrame*> m_frames;
	QSet<AVFramePixelData*> m_createdPixelDatas;
	int m_maxCache;
	QMutex m_mutex;

	friend struct AVFramePixelData;
};

class PIXELTOOL_EXPORT PixelConvProcessor
{
public:
	explicit PixelConvProcessor(int maxCache = 2);
	~PixelConvProcessor();

	PixelConvProcessor(const PixelConvProcessor&) = delete;
	PixelConvProcessor& operator=(const PixelConvProcessor&) = delete;

	AVFramePixelDataPtr conv(const AVFrame* in, int outFmt, int align = 1);
	AVFramePixelDataPtr conv(const AVFrame* in, int outW, int outH, int outFmt, int align = 1);
	void clear();

private:
	bool setSwsContext(int inFmt, int inW, int inH,
		int outFmt, int outW, int outH);

	AVFrameFactory m_factory;
	SwsContext* m_sws;
	QMutex m_mutex;
};

}
