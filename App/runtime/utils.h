#pragma once

#include <QRect>
#include <QSize>
#include <QString>
#include <QVariantMap>

namespace Utils {

	class VideoOptionsMgr : public QObject
	{
		Q_OBJECT
	private:
		VideoOptionsMgr();
	public:
		static VideoOptionsMgr* getInstance();
		const QVariantList& getOptions();
	signals:
		void optionsChanged(const QVariantList&);
	private:
		QVariantList m_options;
	};
	// 获取视频的可选项列表
	QVariantList getVideoOptions();

	// 获取视频的真实地址
	QString getVideoRealSource(const QString& source);

	// rect <-> variant map转换
	bool rectFromMap(const QVariantMap& vmap, QRect& rect);
	bool rectToMap(const QRect& rect, QVariantMap& vmap);

	// rect <-> string
	bool rectFromString(const QString& str, QRect& rect);
	bool rectToString(const QRect& rect, QString& str);

	// size <-> variant map转换，使用width/height键
	bool sizeFromMap(const QVariantMap& vmap, QSize& size);
	bool sizeToMap(const QSize& size, QVariantMap& vmap);

	// 调整矩形的位置和大小以限制在边界内，宽高及边界至少按1处理
	QRect boundedRect(const QRect& rect, const QSize& bounds);

	QVariantMap makeOption(const QString& label, const QString& value);

	// hex
	bool toHexData(const QString& ss, QByteArray* data = nullptr);
	QString toHex(uint8_t v);
	uint8_t fromHex(const QString& s);

} // namespace Utils
