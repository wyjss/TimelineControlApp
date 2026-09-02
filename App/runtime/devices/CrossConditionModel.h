#pragma once

#include "devices/CrossCondition.h"
#include "models/TypedListModel.h"

class QDataStream;
class Timeline;

//! 实例由 TimelineRuntime 创建并管理。
class CrossConditionModel final : public TypedListModel<CrossCondition*>
{
	Q_OBJECT
	Q_PROPERTY(int count READ count NOTIFY conditionsChanged FINAL)

public:
	CrossConditionModel(Timeline* sourceTimeline,
						QObject* parent = nullptr);

	int count() const;
	Q_INVOKABLE CrossCondition* conditionAt(int index) const;
	CrossCondition* conditionById(const QString& id) const;
	Q_INVOKABLE CrossCondition* addCondition(const QString& locator,
										 const QString& fence,
										 double heading,
										 const QString& timeline);
	Q_INVOKABLE bool updateCondition(CrossCondition* condition,
									 const QString& locator,
									 const QString& fence,
									 double heading,
									 const QString& timeline);
	Q_INVOKABLE bool removeCondition(CrossCondition* condition);
	void clear();
	void activate();
	void deactivate();

	void writeToStream(QDataStream& stream) const;
	void readFromStream(QDataStream& stream);

signals:
	void conditionsChanged();

protected:
	bool acceptsItem(CrossCondition* condition) const override;

private:
	bool isValidCondition(const QString& locator,
						  const QString& fence,
						  double heading,
						  const QString& timeline) const;

	Timeline* m_sourceTimeline = nullptr;
};

Q_DECLARE_METATYPE(CrossConditionModel*)
