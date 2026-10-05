#pragma once

#include <QList>
#include <QRect>
#include <QSize>
#include <QString>
#include <QVariantMap>

namespace Utils {

	struct TLCmd {
		QString time;
		QString deviceName;
		QString cmdName;
		QString simName;
		QVariantMap params;
	};

	struct TL {
		QString name;
		// 仅作为内部解析参数：引用的其它时间线
		QStringList refs;
		// 仅作为内部解析参数：是否仅作为引用对象
		bool refOnly = false;
		//
		QList<TLCmd> cmds;
	};

	// JSON格式：{"timelines":[{"name":"名称","cmds":[...]}]}
	// 成功时替换tls；JSON语法、结构或字段类型错误时返回false，tls保持不变。
	bool timelinesFromJson(const QString& json, QList<TL>& tls);

	class AVOptionsMgr : public QObject
	{
		Q_OBJECT
	private:
		AVOptionsMgr();
	public:
		static AVOptionsMgr* getInstance();

		const QVariantList& getVideoOptions();
		const QVariantList& getAudioOptions();
	private:
		QVariantList getOptions(const QString path, const QStringList& nameFilters) const;
		void refreshOptions();
	signals:
		void optionsChanged(const QVariantList& v, const QVariantList& a);

	private:
		QVariantList m_options;
		QVariantList m_videoOptions;
		QVariantList m_audioOptions;
	};
	// 获取音视频的可选项列表
	QVariantList getVideoOptions();
	QVariantList getAudioOptions();

	// 获取视频的真实地址
	QString getVideoRealSource(const QString& source);
	QString getAudioRealSource(const QString& source);

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
