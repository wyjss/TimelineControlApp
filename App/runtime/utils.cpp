#include "utils.h"

#include "devices/DeviceConstants.h"

#include <QTime>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>

namespace Utils 
{

	QVariantList getVideoOptions()
	{
		static QVariantList s_opts;
		static qint64 s_time = 0;
		// 超过间隔才刷新，避免视频变动
		if (QDateTime::currentMSecsSinceEpoch() - s_time > 1000) {
			s_opts.clear();
			s_time = QDateTime::currentMSecsSinceEpoch();

			QDir dir(DeviceConstants::LocalVideoPrefix);
			auto infos = dir.entryInfoList({"*.mp4", "*.avi"});
			for (const auto& info : infos) {
				s_opts.push_back(QString("$") + info.fileName());
			}
		}
		
		return s_opts;
	}

	QString getVideoRealSource(const QString& source)
	{
		if (source.startsWith("$")) {
			return DeviceConstants::LocalVideoPrefix + source.mid(1);
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

} // namespace Utils
