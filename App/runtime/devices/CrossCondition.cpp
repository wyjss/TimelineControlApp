#include "devices/CrossCondition.h"

#include "devices/Device.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceModel.h"
#include "location/FenceManager.h"
#include "runtime/TimelineRuntime.h"
#include "timeline/Timeline.h"
#include "timeline/TimelineManager.h"

#define LC "[CrossCondition] "
#include "LogMacros.h"

#include <QDataStream>
#include <QtMath>
#include <QVariantMap>

#include <cmath>

namespace {

constexpr double kHeadingTolerance = 45.0;

}

CrossCondition::CrossCondition(const QString& id,
							   Timeline* sourceTimeline,
							   const QString& locator,
							   const QString& fence,
							   double heading,
							   const QString& timeline,
							   QObject* parent)
	: QObject(parent)
	, m_id(id.trimmed())
	, m_locator(locator.trimmed())
	, m_fence(fence.trimmed())
	, m_timeline(timeline.trimmed())
	, m_sourceTimeline(sourceTimeline)
{
	double value = std::fmod(heading, 360.0);
	m_heading = value < 0 ? value + 360.0 : value;
	TimelineRuntime* runtime = TimelineRuntime::getInstance();
	if (runtime) {
		m_deviceModel = runtime->deviceModel();
		m_fenceManager = runtime->fenceManager();
		m_timelineManager = runtime->timelineManager();
	}

	if (m_fenceManager) {
		connect(m_fenceManager, &FenceManager::fencesChanged,
				this, &CrossCondition::resetTracking);
	}
	if (m_deviceModel) {
		connect(m_deviceModel, &DeviceModel::deviceAdded, this, [this](Device* device) {
			if (device && device->id() == m_locator)
				bindLocator();
		});
		connect(m_deviceModel, &DeviceModel::deviceRemoved, this, [this](const QString& id) {
			if (id == m_locator)
				bindLocator();
		});
	}
	bindLocator();
}

QString CrossCondition::id() const
{
	return m_id;
}

QString CrossCondition::locator() const
{
	return m_locator;
}

void CrossCondition::setLocator(const QString& locator)
{
	const QString value = locator.trimmed();
	if (m_locator == value)
		return;

	m_locator = value;
	bindLocator();
	emit targetChanged();
}

QString CrossCondition::fence() const
{
	return m_fence;
}

void CrossCondition::setFence(const QString& fence)
{
	const QString value = fence.trimmed();
	if (m_fence == value)
		return;

	m_fence = value;
	resetTracking();
	emit fenceChanged();
}

double CrossCondition::heading() const
{
	return m_heading;
}

void CrossCondition::setHeading(double heading)
{
	if (!qIsFinite(heading))
		return;

	double value = std::fmod(heading, 360.0);
	if (value < 0)
		value += 360.0;
	if (qFuzzyCompare(m_heading + 1.0, value + 1.0))
		return;

	m_heading = value;
	resetTracking();
	emit headingChanged();
}

QString CrossCondition::timeline() const
{
	return m_timeline;
}

void CrossCondition::setTimeline(const QString& timeline)
{
	const QString value = timeline.trimmed();
	if (m_timeline == value)
		return;

	m_timeline = value;
	emit timelineChanged();
}

bool CrossCondition::isEnabled() const
{
	return m_enabled;
}

void CrossCondition::setEnabled(bool enabled)
{
	if (m_enabled == enabled)
		return;

	m_enabled = enabled;
	if (!m_enabled)
		setActive(false);
	emit enabledChanged();
}

bool CrossCondition::isActive() const
{
	return m_active;
}

bool CrossCondition::touched() const
{
	return m_touched;
}

void CrossCondition::writeToStream(QDataStream& stream) const
{
	stream << m_id
		   << m_locator
		   << m_fence
		   << m_heading
		   << m_timeline
		   << m_enabled;
}

CrossCondition* CrossCondition::readFromStream(QDataStream& stream,
											Timeline* sourceTimeline,
											QObject* parent)
{
	QString id;
	QString locator;
	QString fence;
	double heading = 0;
	QString timeline;
	bool enabled = true;
	stream >> id >> locator >> fence >> heading >> timeline >> enabled;
	id = id.trimmed();
	locator = locator.trimmed();
	fence = fence.trimmed();
	timeline = timeline.trimmed();
	if (stream.status() != QDataStream::Ok
		|| id.isEmpty()
		|| !sourceTimeline
		|| locator.isEmpty()
		|| fence.isEmpty()
		|| timeline.isEmpty()
		|| !qIsFinite(heading)) {
		stream.setStatus(QDataStream::ReadCorruptData);
		return nullptr;
	}

	auto* condition = new CrossCondition(id,
									 sourceTimeline,
									 locator,
									 fence,
									 heading,
									 timeline,
									 parent);
	condition->setEnabled(enabled);
	return condition;
}

void CrossCondition::bindLocator()
{
	if (m_locatorDevice)
		disconnect(m_locatorDevice, nullptr, this, nullptr);
	m_locatorDevice.clear();
	resetTracking();

	Device* device = m_deviceModel ? m_deviceModel->deviceById(m_locator) : nullptr;
	if (!device || device->deviceType() != DeviceType::Locator)
		return;

	m_locatorDevice = device;
	connect(device, &Device::paramChanged, this,
			[this](const QString& key, const QVariant& value) {
		if (key != DeviceKey::Location || !m_locatorDevice || !m_locatorDevice->isOnline()) {
			if (key == DeviceKey::Location)
				resetTracking();
			return;
		}

		const QVariantMap location = value.toMap();
		bool longitudeOk = false;
		bool latitudeOk = false;
		bool headingOk = false;
		const double longitude = location.value(QStringLiteral("lon")).toDouble(&longitudeOk);
		const double latitude = location.value(QStringLiteral("lat")).toDouble(&latitudeOk);
		const double heading = location.value(QStringLiteral("heading")).toDouble(&headingOk);
		if (!longitudeOk || !latitudeOk || !headingOk) {
			resetTracking();
			return;
		}
		updateLocation(longitude, latitude, heading);
	});
	connect(device, &Device::onlineChanged, this, [this]() {
		if (!m_locatorDevice || !m_locatorDevice->isOnline())
			resetTracking();
	});
}

void CrossCondition::resetTracking()
{
	m_hasPreviousLocation = false;
	setTouched(false);
}

void CrossCondition::updateLocation(double longitude,
									double latitude,
									double heading)
{
	if (!m_active)
		return;
	if (!m_sourceTimeline || m_sourceTimeline->state() != Timeline::Running) {
		setActive(false);
		return;
	}
	if (m_timelineManager->playbackState() != TimelineManager::Running) {
		return;
	}
	LOG_DEBUG("pass state" << m_sourceTimeline->state());
	setTouched(false);
	if (!qIsFinite(longitude) || !qIsFinite(latitude) || !qIsFinite(heading)) {
		resetTracking();
		return;
	}

	if (!m_hasPreviousLocation) {
		m_previousLongitude = longitude;
		m_previousLatitude = latitude;
		m_hasPreviousLocation = true;
		return;
	}

	QVariantMap fenceData;
	if (m_fenceManager) {
		for (const QVariant& value : m_fenceManager->fences()) {
			const QVariantMap data = value.toMap();
			if (data.value(QStringLiteral("handle")).toString() == m_fence) {
				fenceData = data;
				break;
			}
		}
	}

	const double middleLatitude = (m_previousLatitude + latitude) / 2.0;
	const double longitudeScale = qCos(qDegreesToRadians(middleLatitude));
	const double previousX = m_previousLongitude * longitudeScale;
	const double previousY = m_previousLatitude;
	const double currentX = longitude * longitudeScale;
	const double currentY = latitude;
	const double fenceStartX = fenceData.value(QStringLiteral("startLongitude")).toDouble() * longitudeScale;
	const double fenceStartY = fenceData.value(QStringLiteral("startLatitude")).toDouble();
	const double fenceEndX = fenceData.value(QStringLiteral("endLongitude")).toDouble() * longitudeScale;
	const double fenceEndY = fenceData.value(QStringLiteral("endLatitude")).toDouble();
	const double moveX = currentX - previousX;
	const double moveY = currentY - previousY;
	const double fenceX = fenceEndX - fenceStartX;
	const double fenceY = fenceEndY - fenceStartY;
	const double denominator = moveX * fenceY - moveY * fenceX;

	bool crossed = !fenceData.isEmpty() && !qFuzzyIsNull(longitudeScale)
		&& !qFuzzyIsNull(denominator);
	if (crossed) {
		const double offsetX = fenceStartX - previousX;
		const double offsetY = fenceStartY - previousY;
		const double moveRatio = (offsetX * fenceY - offsetY * fenceX) / denominator;
		const double fenceRatio = (offsetX * moveY - offsetY * moveX) / denominator;
		crossed = moveRatio > 0.0 && moveRatio <= 1.0
			&& fenceRatio >= 0.0 && fenceRatio <= 1.0;
	}

	double normalizedHeading = std::fmod(heading, 360.0);
	if (normalizedHeading < 0)
		normalizedHeading += 360.0;
	double headingDifference = qAbs(normalizedHeading - m_heading);
	headingDifference = qMin(headingDifference, 360.0 - headingDifference);
	crossed = crossed && headingDifference <= kHeadingTolerance;
	m_previousLongitude = longitude;
	m_previousLatitude = latitude;

#if 1
	if (!crossed && m_timelineManager->currentTimeMs() > 2000) {
		LOG_ERROR("调试，2秒后启动子时间线" << m_timelineManager->currentTimeMs());
		setTouched(true);
		if (m_timelineManager && m_timelineManager->triggerTimeline(m_timeline))
			setActive(false);
		return;
	}
	

#endif

	if (!crossed)
		return;
	LOG_DEBUG("正常触发！！！");
	setTouched(true);
	if (m_timelineManager && m_timelineManager->triggerTimeline(m_timeline))
		setActive(false);
}

void CrossCondition::setActive(bool active)
{
	const bool value = active && m_enabled;
	if (m_active == value)
		return;

	m_active = value;
	resetTracking();
	emit activeChanged();
}

void CrossCondition::setTouched(bool touched)
{
	if (m_touched == touched)
		return;

	m_touched = touched;
	emit touchedChanged();
}
