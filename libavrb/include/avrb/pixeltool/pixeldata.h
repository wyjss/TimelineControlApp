#pragma once
#include <QtCore/qglobal.h>
#include <QByteArray>
#include <QSize>
#include <QList>
#include <QMutex>
#include <QSet>
#include <memory>
#ifdef PIXELTOOL_LIB
# define PIXELTOOL_EXPORT Q_DECL_EXPORT
#else
# define PIXELTOOL_EXPORT Q_DECL_IMPORT
#endif

struct AVFrame;
struct AVFrameCollector;

namespace PixelTool{
	enum PixelType{
		Pixel_YUV420P = 0,
		Pixel_RGB = 2,
		Pixel_BGR = 3,		//QImage->RGB888
		Pixel_YUV422P = 4,
		Pixel_YUV444P = 5,
		Pixel_YUV410P = 6,   ///< planar YUV 4:1:0,  9bpp, (1 Cr & Cb sample per 4x4 Y samples)
		Pixel_YUV411P = 7,
		Pixel_GRAY8 = 8,
		Pixel_NV12 = 23,
		Pixel_NV21 = 24,
		Pixel_ARGB = 25,	//QImage->RGB32,ARGB32
		Pixel_RGBA = 26,
		Pixel_ABGR = 27,
		Pixel_BGRA = 28,
		Pixel_YUV440P = 31,
	};

	struct PIXELTOOL_EXPORT PixelSize{
		PixelSize():w(-1),h(-1){}
		PixelSize(int _w, int _h):w(_w),h(_h){}
		inline int width(){return w;}
		inline int height(){return h;}
		int w;
		int h;
	};

	struct PIXELTOOL_EXPORT PixelChannel{
		int w;
		int h;
		int offset;
		int fmt;
		bool isVaild()const{return w != 0 && h != 0;}
	};

	struct PIXELTOOL_EXPORT PixelChannelLayout{
		int w;
		int h;
		int pixelType;
		PixelChannel yChan;
		PixelChannel uChan;
		PixelChannel vChan;
		bool swapRB;
	};

	PIXELTOOL_EXPORT bool SameYuv(int pixelType);
	PIXELTOOL_EXPORT bool GenPixelChannelLayout(int pixelType, const QSize& size, PixelChannelLayout& pixChanLayout);

	struct PIXELTOOL_EXPORT PixelData{
		PixelData(int pixelType, const QSize& size)
			:m_type(pixelType), m_size(size){}
		virtual ~PixelData(){}
		virtual const uchar* getYData() const = 0;
		virtual const uchar* getUData() const = 0;
		virtual const uchar* getVData() const = 0;

		inline int getType() const{return m_type;}
		inline const QSize& getSize() const {return m_size;}
	protected:
		int m_type;
		QSize m_size;
	};

	struct PIXELTOOL_EXPORT BytePixelData : public PixelData{
		BytePixelData(const uchar* data, int pixelType, const QSize& size, bool isPrivateData)
			:PixelData(pixelType, size), m_data(data), m_isPrivateData(isPrivateData){
				GenPixelChannelLayout(pixelType, size, m_layout);
		}
		virtual ~BytePixelData(){
			if(m_isPrivateData){
				free(const_cast<uchar*>(m_data));
			}
		}
		virtual const uchar* getYData() const{
			return m_data;
		}
		virtual const uchar* getUData() const{
			return m_data + m_layout.uChan.offset;
		}
		virtual const uchar* getVData() const{
			return m_data + m_layout.vChan.offset;
		}
	protected:
		const uchar* m_data;
		PixelChannelLayout m_layout;
		bool m_isPrivateData;
	};

	struct PIXELTOOL_EXPORT QBAPixelData : public PixelData{
		QBAPixelData(const QByteArray&ba, int pixelType, const QSize& size)
			:PixelData(pixelType, size), m_ba(ba){
				GenPixelChannelLayout(pixelType, size, m_layout);
		}
		virtual const uchar* getYData() const{
			return (const uchar*)m_ba.constData();
		}
		virtual const uchar* getUData() const{
			return (const uchar*)m_ba.constData() + m_layout.uChan.offset;
		}
		virtual const uchar* getVData() const{
			return (const uchar*)m_ba.constData() + m_layout.vChan.offset;
		}
	protected:
		const QByteArray& m_ba;
		PixelChannelLayout m_layout;
	};

	class AVFrameFactory;
	struct PIXELTOOL_EXPORT AVFramePixelData : public PixelData{
		explicit AVFramePixelData(AVFrame* avframe);
		AVFramePixelData(AVFrame* avframe, bool ownsFrame);
		AVFramePixelData(const AVFramePixelData&) = delete;
		AVFramePixelData& operator=(const AVFramePixelData&) = delete;
		AVFramePixelData(AVFramePixelData&&) = delete;
		AVFramePixelData& operator=(AVFramePixelData&&) = delete;
		virtual ~AVFramePixelData();
		virtual const uchar* getYData() const;
		virtual const uchar* getUData() const;
		virtual const uchar* getVData() const;
		bool hasData() const{return m_avframe != nullptr;}
		AVFrame* getAVFrame() const{return m_avframe;}
	private:
		explicit AVFramePixelData(AVFrame* avframe, AVFrameFactory* factory);
		AVFramePixelData(AVFrame* avframe, AVFrameFactory* factory, bool ownsFrame);
		void clear();

		AVFrame* m_avframe;
		AVFrameFactory* m_factory;
		bool m_ownsFrame;
		friend class AVFrameFactory;
	};
	using AVFramePixelDataPtr = std::unique_ptr<AVFramePixelData>;

};
