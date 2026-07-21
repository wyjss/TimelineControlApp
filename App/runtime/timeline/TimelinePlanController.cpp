#include "timeline/TimelinePlanController.h"

#include "timeline/TimelineCommand.h"
#include "timeline/TimelineController.h"

#include <QDataStream>
#include <QIODevice>
#include <QUuid>

namespace {

constexpr quint32 kTimelinePlansMagic = 0x544C5053;
constexpr qint32 kTimelinePlansVersion = 1;

QString createPlanId()
{
    return QStringLiteral("timeline-plan-%1").arg(QUuid::createUuid().toString(QUuid::WithoutBraces));
}

} // namespace


TimelinePlanController::TimelinePlanController(TimelineCommandModel *commandModel,
                                               TimelineController *timelineController,
                                               QObject *parent)
    : QObject(parent)
    , m_commandModel(commandModel)
    , m_timelineController(timelineController)
{
    resetFromCurrentModel();
}

QVariantList TimelinePlanController::plans() const
{
    QVariantList result;
    result.reserve(m_plans.size());
    for (int index = 0; index < m_plans.size(); ++index) {
        const Plan &plan = m_plans.at(index);
        result.append(QVariantMap{
            {QStringLiteral("id"), plan.id},
            {QStringLiteral("name"), plan.name},
            {QStringLiteral("index"), index}
        });
    }
    return result;
}

int TimelinePlanController::currentPlanIndex() const
{
    return m_currentPlanIndex;
}

QString TimelinePlanController::currentPlanName() const
{
    return m_currentPlanIndex >= 0 && m_currentPlanIndex < m_plans.size()
        ? m_plans.at(m_currentPlanIndex).name
        : QString();
}

QStringList TimelinePlanController::selectedPlanIds() const
{
    return m_selectedPlanIds;
}

void TimelinePlanController::setCurrentPlanIndex(int index)
{
    if (!canChangePlan()
        || index < 0
        || index >= m_plans.size()
        || m_currentPlanIndex == index)
        return;

    storeCurrentPlan();
    m_currentPlanIndex = index;
    restoreCurrentPlan();
    emit currentPlanChanged();
}

int TimelinePlanController::createPlan(const QString &name)
{
    const QString normalizedName = name.trimmed();
    if (!canChangePlan() || normalizedName.isEmpty())
        return -1;

    storeCurrentPlan();
    Plan plan;
    plan.id = createPlanId();
    plan.name = normalizedName;
    m_plans.append(plan);
    m_currentPlanIndex = m_plans.size() - 1;
    restoreCurrentPlan();
    emit plansChanged();
    emit currentPlanChanged();
    return m_currentPlanIndex;
}

int TimelinePlanController::duplicateCurrentPlan(const QString &name)
{
    const QString normalizedName = name.trimmed();
    if (!canChangePlan()
        || normalizedName.isEmpty()
        || m_currentPlanIndex < 0
        || m_currentPlanIndex >= m_plans.size())
        return -1;

    storeCurrentPlan();
    Plan plan = m_plans.at(m_currentPlanIndex);
    plan.id = createPlanId();
    plan.name = normalizedName;
    m_plans.append(plan);
    m_currentPlanIndex = m_plans.size() - 1;
    restoreCurrentPlan();
    emit plansChanged();
    emit currentPlanChanged();
    return m_currentPlanIndex;
}

bool TimelinePlanController::removeCurrentPlan()
{
    if (!canChangePlan()
        || m_plans.size() <= 1
        || m_currentPlanIndex < 0
        || m_currentPlanIndex >= m_plans.size())
        return false;

    const int nextIndex = m_currentPlanIndex == m_plans.size() - 1
        ? m_currentPlanIndex - 1
        : m_currentPlanIndex;
    const QString removedPlanId = m_plans.at(m_currentPlanIndex).id;
    m_plans.removeAt(m_currentPlanIndex);
    const bool selectionChanged = m_selectedPlanIds.removeAll(removedPlanId) > 0;
    m_currentPlanIndex = nextIndex;
    restoreCurrentPlan();
    emit plansChanged();
    emit currentPlanChanged();
    if (selectionChanged)
        emit selectedPlansChanged();
    return true;
}

void TimelinePlanController::togglePlanSelected(const QString &planId)
{
    const int selectedIndex = m_selectedPlanIds.indexOf(planId);
    if (selectedIndex >= 0) {
        m_selectedPlanIds.removeAt(selectedIndex);
    } else {
        bool planExists = false;
        for (const Plan &plan : m_plans) {
            if (plan.id == planId) {
                planExists = true;
                break;
            }
        }
        if (!planExists)
            return;
        m_selectedPlanIds.append(planId);
    }
    emit selectedPlansChanged();
}

void TimelinePlanController::resetFromCurrentModel()
{
    m_plans = {
        Plan{createPlanId(), tr("主时间轴"), commandData(m_commandModel)}
    };
    m_currentPlanIndex = 0;
    m_selectedPlanIds.clear();
    emit plansChanged();
    emit currentPlanChanged();
    emit selectedPlansChanged();
}

void TimelinePlanController::removeCommandsForDevice(const QString &deviceId)
{
    const QString normalizedDeviceId = deviceId.trimmed();
    if (normalizedDeviceId.isEmpty() || !m_commandModel)
        return;

    storeCurrentPlan();
    for (int index = 0; index < m_plans.size(); ++index) {
        if (index == m_currentPlanIndex) {
            m_commandModel->removeCommandsForDevice(normalizedDeviceId);
            m_plans[index].commandData = commandData(m_commandModel);
            continue;
        }

        TimelineCommandModel model;
        if (!restoreCommandData(&model, m_plans.at(index).commandData))
            continue;
        model.removeCommandsForDevice(normalizedDeviceId);
        m_plans[index].commandData = commandData(&model);
    }
}

void TimelinePlanController::writeToStream(QDataStream &stream) const
{
    stream << kTimelinePlansMagic
           << kTimelinePlansVersion
           << m_currentPlanIndex
           << m_plans.size();

    for (int index = 0; index < m_plans.size(); ++index) {
        const Plan &plan = m_plans.at(index);
        stream << plan.id
               << plan.name
               << (index == m_currentPlanIndex ? commandData(m_commandModel) : plan.commandData);
    }
}

bool TimelinePlanController::readFromStream(QDataStream &stream)
{
    quint32 magic = 0;
    qint32 version = 0;
    int currentPlanIndex = -1;
    int planCount = 0;
    stream >> magic
           >> version
           >> currentPlanIndex
           >> planCount;
    if (stream.status() != QDataStream::Ok
        || magic != kTimelinePlansMagic
        || version != kTimelinePlansVersion
        || planCount <= 0)
        return false;

    QVector<Plan> plans;
    plans.reserve(planCount);
    for (int index = 0; index < planCount; ++index) {
        Plan plan;
        stream >> plan.id
               >> plan.name
               >> plan.commandData;
        if (stream.status() != QDataStream::Ok)
            return false;
        if (plan.id.trimmed().isEmpty())
            plan.id = createPlanId();
        if (plan.name.trimmed().isEmpty())
            plan.name = tr("时间轴 %1").arg(index + 1);
        plans.append(plan);
    }

    m_plans = plans;
    m_currentPlanIndex = currentPlanIndex >= 0 && currentPlanIndex < m_plans.size()
        ? currentPlanIndex
        : 0;
    if (!restoreCurrentPlan())
        return false;
    m_selectedPlanIds.clear();
    emit plansChanged();
    emit currentPlanChanged();
    emit selectedPlansChanged();
    return true;
}

QByteArray TimelinePlanController::commandData(TimelineCommandModel *model) const
{
    QByteArray data;
    if (!model)
        return data;

    QDataStream stream(&data, QIODevice::WriteOnly);
    model->writeToStream(stream);
    return stream.status() == QDataStream::Ok ? data : QByteArray();
}

bool TimelinePlanController::restoreCommandData(TimelineCommandModel *model, const QByteArray &data) const
{
    if (!model)
        return false;
    if (data.isEmpty()) {
        model->resetCommands({});
        model->setSelectedCommandId(QString());
        return true;
    }

    QByteArray streamData = data;
    QDataStream stream(&streamData, QIODevice::ReadOnly);
    model->readFromStream(stream);
    return stream.status() == QDataStream::Ok;
}

void TimelinePlanController::storeCurrentPlan()
{
    if (m_currentPlanIndex >= 0 && m_currentPlanIndex < m_plans.size())
        m_plans[m_currentPlanIndex].commandData = commandData(m_commandModel);
}

bool TimelinePlanController::restoreCurrentPlan()
{
    if (m_currentPlanIndex < 0 || m_currentPlanIndex >= m_plans.size())
        return false;

    const bool restored = restoreCommandData(m_commandModel, m_plans.at(m_currentPlanIndex).commandData);
    if (restored && m_timelineController) {
        m_timelineController->setDurationMs(24 * 60 * 60 * 1000);
        m_timelineController->seek(0);
    }
    return restored;
}

bool TimelinePlanController::canChangePlan() const
{
    return !m_timelineController || m_timelineController->state() == TimelineController::Stopped;
}
