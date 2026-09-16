#include "projection/VideoProjectionPlanController.h"

#include <QDataStream>

void VideoProjectionPlanController::writeToStream(QDataStream &stream) const
{
    stream << m_currentPlanIndex
           << m_plans.size();

    for (const VideoProjectionPlan &plan : m_plans) {
        stream << plan.name
               << plan.projectionWindowId
               << plan.targetPcIds
               << plan.videoSource
               << plan.videoSize
               << plan.createdAt
               << plan.updatedAt
               << plan.captures.size();

        for (const VideoProjectionCapture &capture : plan.captures) {
            stream << capture.name
                   << capture.rect;
        }

        stream << plan.mappings.size();
        for (const VideoProjectionMapping &mapping : plan.mappings) {
            stream << mapping.captureIndex
                   << mapping.pcId
                   << mapping.outputRect
                   << mapping.screenTotalSize
                   << mapping.screenResolution
                   << mapping.screenLayout
                   << mapping.screenColumn
                   << mapping.screenRow;
        }
    }
}

void VideoProjectionPlanController::readFromStream(QDataStream &stream)
{
    int currentPlanIndex = -1;
    int planCount = 0;
    stream >> currentPlanIndex
           >> planCount;
    if (stream.status() != QDataStream::Ok || planCount < 0)
        return;

    QVector<VideoProjectionPlan> plans;
    plans.reserve(planCount);
    for (int planIndex = 0; planIndex < planCount; ++planIndex) {
        VideoProjectionPlan plan;
        int captureCount = 0;
        stream >> plan.name
               >> plan.projectionWindowId
               >> plan.targetPcIds
               >> plan.videoSource
               >> plan.videoSize
               >> plan.createdAt
               >> plan.updatedAt
               >> captureCount;
        if (stream.status() != QDataStream::Ok || captureCount < 0)
            return;

        plan.captures.reserve(captureCount);
        for (int captureIndex = 0; captureIndex < captureCount; ++captureIndex) {
            VideoProjectionCapture capture;
            stream >> capture.name
                   >> capture.rect;
            if (stream.status() != QDataStream::Ok)
                return;

            plan.captures.append(capture);
        }

        int mappingCount = 0;
        stream >> mappingCount;
        if (stream.status() != QDataStream::Ok || mappingCount < 0)
            return;

        plan.mappings.reserve(mappingCount);
        for (int mappingIndex = 0; mappingIndex < mappingCount; ++mappingIndex) {
            VideoProjectionMapping mapping;
            stream >> mapping.captureIndex
                   >> mapping.pcId
                   >> mapping.outputRect
                   >> mapping.screenTotalSize
                   >> mapping.screenResolution
                   >> mapping.screenLayout
                   >> mapping.screenColumn
                   >> mapping.screenRow;
            if (stream.status() != QDataStream::Ok)
                return;

            plan.mappings.append(mapping);
        }

        plans.append(plan);
    }

    m_plans = plans;
    m_currentPlanIndex = currentPlanIndex >= 0 && currentPlanIndex < m_plans.size()
        ? currentPlanIndex
        : (m_plans.isEmpty() ? -1 : 0);
}

void VideoProjectionPlanController::removeMappingsForPc(const QString &pcId)
{
    if (pcId.isEmpty())
        return;

    for (VideoProjectionPlan &plan : m_plans) {
        const int oldCount = plan.mappings.size();
        for (int index = plan.mappings.size() - 1; index >= 0; --index) {
            if (plan.mappings.at(index).pcId == pcId)
                plan.mappings.removeAt(index);
        }
        if (plan.mappings.size() == oldCount)
            continue;

        plan.targetPcIds.clear();
        for (const VideoProjectionMapping &mapping : plan.mappings) {
            if (!mapping.pcId.isEmpty() && !plan.targetPcIds.contains(mapping.pcId))
                plan.targetPcIds.append(mapping.pcId);
        }
        plan.updatedAt = QDateTime::currentDateTimeUtc();
    }
}
