#pragma once

#include <QObject>
#include <QPointer>
#include <QString>

class QDataStream;
class Device;
class DeviceModel;
class FenceManager;
class Timeline;
class TimelineManager;
class CrossConditionModel;

//! 定位器过点触发节目播放
class CrossCondition final : public QObject
{
	Q_OBJECT
	Q_PROPERTY(QString id READ id CONSTANT FINAL)
	Q_PROPERTY(QString locator READ locator WRITE setLocator NOTIFY targetChanged FINAL)
	Q_PROPERTY(QString fence READ fence WRITE setFence NOTIFY fenceChanged FINAL)
	Q_PROPERTY(double heading READ heading WRITE setHeading NOTIFY headingChanged FINAL)
	Q_PROPERTY(QString timeline READ timeline WRITE setTimeline NOTIFY timelineChanged FINAL)
	Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged FINAL)
	Q_PROPERTY(bool active READ isActive NOTIFY activeChanged FINAL)
	Q_PROPERTY(bool touched READ touched NOTIFY touchedChanged FINAL)

public:
	CrossCondition(const QString& id,
				   Timeline* sourceTimeline,
				   const QString& locator,
				   const QString& fence,
				   double heading,
				   const QString& timeline,
				   QObject* parent = nullptr);

	QString id() const;
	QString locator() const;
	void setLocator(const QString& locator);
	QString fence() const;
	void setFence(const QString& fence);
	double heading() const;
	void setHeading(double heading);
	QString timeline() const;
	void setTimeline(const QString& timeline);
	bool isEnabled() const;
	void setEnabled(bool enabled);
	bool isActive() const;
	bool touched() const;

	void writeToStream(QDataStream& stream) const;
	static CrossCondition* readFromStream(QDataStream& stream,
									  Timeline* sourceTimeline,
									  QObject* parent = nullptr);

signals:
	void targetChanged();
	void fenceChanged();
	void headingChanged();
	void timelineChanged();
	void enabledChanged();
	void activeChanged();
	void touchedChanged();

private:
	friend class CrossConditionModel;

	void bindLocator();
	void resetTracking();
	void updateLocation(double longitude, double latitude, double heading);
	void setActive(bool active);
	void setTouched(bool touched);

	QString m_id;
	QString m_locator;
	QString m_fence;
	double m_heading = 0;
	QString m_timeline;
	bool m_enabled = true;
	bool m_active = false;
	bool m_touched = false;
	bool m_hasPreviousLocation = false;
	double m_previousLongitude = 0;
	double m_previousLatitude = 0;
	QPointer<Device> m_locatorDevice;
	QPointer<DeviceModel> m_deviceModel;
	QPointer<FenceManager> m_fenceManager;
	QPointer<Timeline> m_sourceTimeline;
	QPointer<TimelineManager> m_timelineManager;
};

Q_DECLARE_METATYPE(CrossCondition*)
