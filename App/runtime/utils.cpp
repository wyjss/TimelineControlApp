#include "utils.h"

#include "devices/DeviceConstants.h"

#include <QTime>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QFileSystemWatcher>

namespace Utils 
{
	//////////////////////////////////////////////////////////////////////////
	AVOptionsMgr::AVOptionsMgr()
	{
		refreshOptions();

		QFileSystemWatcher* watcher = new QFileSystemWatcher(this);
		watcher->addPath(DeviceConstants::LocalVideoPrefix);
		watcher->addPath(DeviceConstants::LocalAudioPrefix);
		connect(watcher, &QFileSystemWatcher::directoryChanged,
				this, [this]() {refreshOptions(); });
	}

	AVOptionsMgr* AVOptionsMgr::getInstance()
	{
		static AVOptionsMgr* s_AVOptionsMgr = new AVOptionsMgr;
		return s_AVOptionsMgr;
	}

	const QVariantList& AVOptionsMgr::getVideoOptions()
	{
		return m_videoOptions;
	}

	const QVariantList& AVOptionsMgr::getAudioOptions()
	{
		return m_audioOptions;
	}

	QVariantList AVOptionsMgr::getOptions(const QString path, const QStringList& nameFilters) const
	{
		QVariantList opts;
		QDir dir(path);
		auto infos = dir.entryInfoList(nameFilters);
		for (const auto& info : infos) {
			opts.push_back(QString("$") + info.fileName());
		}
		return opts;
	}

	void AVOptionsMgr::refreshOptions()
	{
		auto videos = getOptions(DeviceConstants::LocalVideoPrefix,
								 { "*.mp4", "*.avi" , "*.flv", "*.png", "*.jpg"});
		auto audios = getOptions(DeviceConstants::LocalAudioPrefix, 
								 { "*.mp3","*.wav" ,"*.aac"});

		bool dirty = false;

		if (videos != m_videoOptions) {
			m_videoOptions = videos;
			dirty = true;
		}

		if (audios != m_audioOptions) {
			m_audioOptions = audios;
			dirty = true;
		}

		if (dirty) {
			emit optionsChanged(m_videoOptions, m_audioOptions);
		}
	}
	//////////////////////////////////////////////////////////////////////////

	QVariantList getVideoOptions()
	{
		return AVOptionsMgr::getInstance()->getVideoOptions();
	}
	
	QVariantList getAudioOptions()
	{
		return AVOptionsMgr::getInstance()->getAudioOptions();
	}

	QString getVideoRealSource(const QString& source)
	{
		if (source.startsWith("$")) {
			return DeviceConstants::LocalVideoPrefix + source.mid(1);
		} else {
			return source;
		}
	}

	QString getAudioRealSource(const QString& source)
	{
		if (source.startsWith("$")) {
			return DeviceConstants::LocalAudioPrefix + source.mid(1);
		} else {
			return source;
		}
	}

	bool rectFromMap(const QVariantMap& vmap, QRect& rect)
	{
		if (
			vmap.contains("x") &&
			vmap.contains("y") &&
			vmap.contains("w") &&
			vmap.contains("h")
			) {
			rect = QRect(
				QPoint(vmap["x"].toInt(), vmap["y"].toInt()),
				QSize(vmap["w"].toInt(), vmap["h"].toInt())
			);
			return true;
		}
		return false;
	}

	bool rectToMap(const QRect& rect, QVariantMap& vmap)
	{
		vmap["x"] = rect.left();
		vmap["y"] = rect.top();
		vmap["w"] = rect.width();
		vmap["h"] = rect.height();
		return true;
	}

	bool rectFromString(const QString& str, QRect& rect)
	{
		auto strs = str.split(",", Qt::SkipEmptyParts);
		if (strs.size() == 4) {
			rect = QRect(
				QPoint(strs[0].toInt(), strs[1].toInt()),
				QSize(strs[2].toInt(), strs[3].toInt())
			);
			return true;
		}

		return false;
	}

	bool rectToString(const QRect& rect, QString& str)
	{
		str.clear();
		for (auto v : {rect.left(), rect.top(), rect.width(), rect.height()}) {
			if (!str.isEmpty()) {
				str.push_back(",");
			}
			str.push_back(QString::number(v));
		}
		return true;
	}

	bool sizeFromMap(const QVariantMap& vmap, QSize& size)
	{
		if (vmap.contains("width") && vmap.contains("height")) {
			size = {vmap["width"].toInt(), vmap["height"].toInt()};
			return true;
		}
		return false;
	}

	bool sizeToMap(const QSize& size, QVariantMap& vmap)
	{
		vmap["width"] = size.width();
		vmap["height"] = size.height();
		return true;
	}

	QRect boundedRect(const QRect& rect, const QSize& bounds)
	{
		int boundedWidth = qMax(1, bounds.width());
		int boundedHeight = qMax(1, bounds.height());
		int rectWidth = qBound(1, rect.width(), boundedWidth);
		int rectHeight = qBound(1, rect.height(), boundedHeight);
		int rectX = qBound(0, rect.x(), boundedWidth - rectWidth);
		int rectY = qBound(0, rect.y(), boundedHeight - rectHeight);
		return QRect(rectX, rectY, rectWidth, rectHeight);
	}

	QVariantMap makeOption(const QString& label, const QString& value)
	{
		return {{"label", label}, {"value", value}};
	}

	bool toHexData(const QString& ss, QByteArray* data)
	{
		if (ss.isEmpty() || ss.size() % 2 != 0) {
			return false;
		}

		for (int i = 0; i < ss.size(); ++i) {
			auto c = ss[i].toUpper();
			
			if (
				(c >= '0' && c <= '9') ||
				(c >= 'A' && c <= 'F')
				) {
				;
			} else {
				return false;
			}
		}

		if (data) {
			*data = QByteArray::fromHex(ss.toLatin1());
		}
		return true;
	}

	QString toHex(uint8_t v)
	{
		auto s = QString::number(v, 16);
		if (s.size() % 2 == 1) {
			s.insert(0, '0');
		}
		return s;
	}

	uint8_t fromHex(const QString& s)
	{
		assert(s.size() == 1);
		return s.toUInt(nullptr, 16);
	}
} // namespace Utils
