#include "devices/CrossConditionModel.h"

#include "devices/Device.h"
#include "devices/DeviceConstants.h"
#include "devices/DeviceModel.h"
#include "location/FenceManager.h"
#include "runtime/TimelineRuntime.h"
#include "timeline/Timeline.h"
#include "timeline/TimelineManager.h"

#define LC "[CrossConditionModel] "
#include "LogMacros.h"

#include <QDataStream>
#include <QSet>
#include <QUuid>
#include <QtAlgorithms>
#include <QtMath>
#include <QTimer>

namespace {

constexpr quint32 kCrossConditionModelMagic = 0x4352434D;
constexpr qint32 kCrossConditionModelVersion = 3;

}

CrossConditionModel::CrossConditionModel(Timeline* sourceTimeline, QObject* parent)
	: TypedListModel<CrossCondition*>(QByteArrayLiteral("condition"), parent)
	, m_sourceTimeline(sourceTimeline)
{
	if (m_sourceTimeline) {
		connect(m_sourceTimeline, &Timeline::stateChanged, this,
				[this](Timeline::State state) {
					if (state == Timeline::Stopped
						) {
						LOG_DEBUG("aaa" << m_sourceTimeline->name() << state);
						deactivate();
					}
				});
	}
}

int CrossConditionModel::count() const
{
	return rowCount();
}

CrossCondition* CrossConditionModel::conditionAt(int index) const
{
	return itemAt(index);
}

CrossCondition* CrossConditionModel::conditionById(const QString& id) const
{
	const QString value = id.trimmed();
	for (CrossCondition* condition : items()) {
		if (condition->id() == value)
			return condition;
	}
	return nullptr;
}

CrossCondition* CrossConditionModel::addCondition(const QString& locator,
													  const QString& fence,
													  double heading,
													  const QString& timeline)
{
	const QString locatorId = locator.trimmed();
	const QString fenceHandle = fence.trimmed();
	const QString timelineId = timeline.trimmed();
	if (!isValidCondition(locatorId, fenceHandle, heading, timelineId))
		return nullptr;

	auto* condition = new CrossCondition(
		QStringLiteral("cross-condition-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces)),
		m_sourceTimeline,
		locatorId,
		fenceHandle,
		heading,
		timelineId,
		this);
	if (!appendItem(condition)) {
		delete condition;
		return nullptr;
	}
	emit conditionsChanged();
	return condition;
}

bool CrossConditionModel::updateCondition(CrossCondition* condition,
														const QString& locator,
														const QString& fence,
														double heading,
														const QString& timeline)
{
	const QString locatorId = locator.trimmed();
	const QString fenceHandle = fence.trimmed();
	const QString timelineId = timeline.trimmed();
	if (indexOfItem(condition) < 0
		|| !isValidCondition(locatorId,
			fenceHandle,
			heading,
			timelineId))
		return false;

	condition->setLocator(locatorId);
	condition->setFence(fenceHandle);
	condition->setHeading(heading);
	condition->setTimeline(timelineId);
	emit conditionsChanged();
	return true;
}

bool CrossConditionModel::removeCondition(CrossCondition* condition)
{
	const int index = indexOfItem(condition);
	if (index < 0 || !removeItemAt(index))
		return false;

	condition->deleteLater();
	emit conditionsChanged();
	return true;
}

void CrossConditionModel::clear()
{
	const QList<CrossCondition*> conditions = items();
	if (conditions.isEmpty())
		return;

	clearItems();
	qDeleteAll(conditions);
	emit conditionsChanged();
}

void CrossConditionModel::activate()
{
	LOG_INFO("activate" << this);
	TimelineRuntime* runtime = TimelineRuntime::getInstance();
	TimelineManager* timelineManager = runtime ? runtime->timelineManager() : nullptr;
	if (!timelineManager
		|| !m_sourceTimeline
		|| m_sourceTimeline->state() != Timeline::Running)
		return;

	for (CrossCondition* condition : items()) {
		Timeline* targetTimeline = condition && condition->isEnabled()
			? timelineManager->timelineById(condition->timeline())
			: nullptr;
		if (!targetTimeline || targetTimeline == m_sourceTimeline) {
			if (condition)
				condition->setActive(false);
			continue;
		}

		timelineManager->waitForTrigger(targetTimeline->id());
		condition->setActive(targetTimeline->state() == Timeline::Waiting);
	}
}

void CrossConditionModel::deactivate()
{
	LOG_INFO("deactivate" << this);
	for (CrossCondition* condition : items()) {
		if (condition) {
			condition->setActive(false);
			condition->setTouched(false);
		}
	}
}

void CrossConditionModel::writeToStream(QDataStream& stream) const
{
	stream << kCrossConditionModelMagic
		   << kCrossConditionModelVersion
		   << items().size();
	for (CrossCondition* condition : items())
		condition->writeToStream(stream);
}

void CrossConditionModel::readFromStream(QDataStream& stream)
{
	quint32 magic = 0;
	qint32 version = 0;
	int count = 0;
	stream >> magic >> version >> count;
	if (stream.status() != QDataStream::Ok
		|| magic != kCrossConditionModelMagic
		|| version != kCrossConditionModelVersion
		|| count < 0) {
		stream.setStatus(QDataStream::ReadCorruptData);
		return;
	}

	QList<CrossCondition*> conditions;
	QSet<QString> ids;
	conditions.reserve(count);
	for (int index = 0; index < count; ++index) {
		CrossCondition* condition = CrossCondition::readFromStream(stream,
			m_sourceTimeline,
			this);
		if (!condition || ids.contains(condition->id())) {
			delete condition;
			stream.setStatus(QDataStream::ReadCorruptData);
			break;
		}
		ids.insert(condition->id());
		conditions.append(condition);
	}

	if (stream.status() != QDataStream::Ok || conditions.size() != count) {
		qDeleteAll(conditions);
		return;
	}

	const QList<CrossCondition*> oldConditions = items();
	if (!resetItems(conditions)) {
		qDeleteAll(conditions);
		stream.setStatus(QDataStream::ReadCorruptData);
		return;
	}
	qDeleteAll(oldConditions);
	emit conditionsChanged();
}

bool CrossConditionModel::acceptsItem(CrossCondition* condition) const
{
	return condition != nullptr;
}

bool CrossConditionModel::isValidCondition(const QString& locator,
														const QString& fence,
														double heading,
														const QString& timeline) const
{
	TimelineRuntime* runtime = TimelineRuntime::getInstance();
	DeviceModel* deviceModel = runtime ? runtime->deviceModel() : nullptr;
	FenceManager* fenceManager = runtime ? runtime->fenceManager() : nullptr;
	TimelineManager* timelineManager = runtime ? runtime->timelineManager() : nullptr;
	Device* device = deviceModel ? deviceModel->deviceById(locator) : nullptr;
	if (!device
		|| device->deviceType() != DeviceType::Locator
		|| !timelineManager
		|| !m_sourceTimeline
		|| !timelineManager->timelineById(timeline)
		|| m_sourceTimeline->id() == timeline
		|| !qIsFinite(heading))
		return false;

	if (fenceManager) {
		for (const QVariant& value : fenceManager->fences()) {
			if (value.toMap().value(QStringLiteral("handle")).toString() == fence)
				return true;
		}
	}
	return false;
}
