#include "projection/VideoProjectionPlanController.h"

#include <QDataStream>


VideoProjectionPlanController::VideoProjectionPlanController(QObject *parent)
    : QObject(parent)
    , m_planModel(this)
    , m_captureModel(this)
    , m_mappingModel(this)
{
    createPlan();
}

QAbstractItemModel *VideoProjectionPlanController::planModel() const
{
    return const_cast<VariantListModel *>(&m_planModel);
}

QAbstractItemModel *VideoProjectionPlanController::captureModel() const
{
    return const_cast<VariantListModel *>(&m_captureModel);
}

QAbstractItemModel *VideoProjectionPlanController::mappingModel() const
{
    return const_cast<VariantListModel *>(&m_mappingModel);
}

QVariantList VideoProjectionPlanController::planValues() const
{
    QVariantList result;
    result.reserve(m_plans.size());
    for (int index = 0; index < m_plans.size(); ++index)
        result.append(planToMap(m_plans.at(index), index));
    return result;
}

QVariantList VideoProjectionPlanController::captureValues() const
{
    QVariantList result;
    const VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return result;

    result.reserve(plan->captures.size());
    for (int index = 0; index < plan->captures.size(); ++index)
        result.append(captureToMap(plan->captures.at(index), index));
    return result;
}

QVariantList VideoProjectionPlanController::mappingValues() const
{
    QVariantList result;
    const VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return result;

    result.reserve(plan->mappings.size());
    for (int index = 0; index < plan->mappings.size(); ++index)
        result.append(mappingToMap(plan->mappings.at(index), index));
    return result;
}

int VideoProjectionPlanController::currentPlanIndex() const
{
    return m_currentPlanIndex;
}

void VideoProjectionPlanController::setCurrentPlanIndex(int index)
{
    if (index < -1 || index >= m_plans.size())
        return;

    if (m_currentPlanIndex == index)
        return;

    m_currentPlanIndex = index;
    refreshPlanModel();
    refreshCurrentPlanModels();
    emit currentPlanChanged();
}

const QVector<VideoProjectionPlan> &VideoProjectionPlanController::planItems() const
{
    return m_plans;
}

VideoProjectionPlan *VideoProjectionPlanController::currentPlan()
{
    if (m_currentPlanIndex < 0 || m_currentPlanIndex >= m_plans.size())
        return nullptr;

    return &m_plans[m_currentPlanIndex];
}

const VideoProjectionPlan *VideoProjectionPlanController::currentPlan() const
{
    if (m_currentPlanIndex < 0 || m_currentPlanIndex >= m_plans.size())
        return nullptr;

    return &m_plans.at(m_currentPlanIndex);
}

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
    refreshPlanModel();
    refreshCurrentPlanModels();
    emit currentPlanChanged();
}

int VideoProjectionPlanController::createPlan(const QString &name)
{
    VideoProjectionPlan plan;
    plan.name = name.trimmed().isEmpty() ? defaultPlanName() : name.trimmed();
    plan.createdAt = QDateTime::currentDateTimeUtc();
    plan.updatedAt = plan.createdAt;

    const int row = m_plans.size();
    m_plans.append(plan);
    setCurrentPlanIndex(row);
    return row;
}

QVariantMap VideoProjectionPlanController::planAt(int index) const
{
    if (index < 0 || index >= m_plans.size())
        return {};

    return planToMap(m_plans.at(index), index);
}

QVariantMap VideoProjectionPlanController::currentPlanData() const
{
    return planAt(m_currentPlanIndex);
}

void VideoProjectionPlanController::setCurrentPlanName(const QString &name)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return;

    const QString trimmedName = name.trimmed();
    if (trimmedName.isEmpty() || plan->name == trimmedName)
        return;

    plan->name = trimmedName;
    touchCurrentPlan();
    refreshCurrentPlanRow();
}

void VideoProjectionPlanController::setProjectionWindowId(const QString &windowId)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return;

    const QString trimmedWindowId = windowId.trimmed();
    if (plan->projectionWindowId == trimmedWindowId)
        return;

    plan->projectionWindowId = trimmedWindowId;
    touchCurrentPlan();
    refreshCurrentPlanRow();
}

void VideoProjectionPlanController::setVideoSource(const QUrl &source)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan || plan->videoSource == source)
        return;

    plan->videoSource = source;
    touchCurrentPlan();
    refreshCurrentPlanRow();
}

void VideoProjectionPlanController::setVideoSize(int width, int height)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return;

    const QSize size(qMax(1, width), qMax(1, height));
    if (plan->videoSize == size)
        return;

    plan->videoSize = size;
    for (VideoProjectionCapture &capture : plan->captures)
        capture.rect = boundedRect(capture.rect.x(), capture.rect.y(), capture.rect.width(), capture.rect.height(), size);

    touchCurrentPlan();
    refreshCurrentPlanRow();
    m_captureModel.resetValues(captureValues());
}

int VideoProjectionPlanController::addCapture(const QString &name)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return -1;

    const int index = plan->captures.size();
    const QSize videoSize = plan->videoSize.isValid() ? plan->videoSize : QSize(1920, 1080);
    const int width = qMax(1, videoSize.width() / 3);
    const int height = qMax(1, videoSize.height() / 3);
    const int offset = 32 * index;

    VideoProjectionCapture capture;
    capture.name = name.trimmed().isEmpty() ? defaultCaptureName(index) : name.trimmed();
    capture.rect = boundedRect(offset, offset, width, height, videoSize);

    plan->captures.append(capture);
    touchCurrentPlan();
    m_captureModel.appendValue(captureToMap(capture, index));
    refreshCurrentPlanRow();
    return index;
}

void VideoProjectionPlanController::removeCapture(int index)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan || index < 0 || index >= plan->captures.size())
        return;

    plan->captures.removeAt(index);

    for (int mappingIndex = plan->mappings.size() - 1; mappingIndex >= 0; --mappingIndex) {
        VideoProjectionMapping &mapping = plan->mappings[mappingIndex];
        if (mapping.captureIndex == index) {
            plan->mappings.removeAt(mappingIndex);
            continue;
        }

        if (mapping.captureIndex > index)
            --mapping.captureIndex;
    }

    refreshTargetPcIds(*plan);
    touchCurrentPlan();
    m_captureModel.resetValues(captureValues());
    m_mappingModel.resetValues(mappingValues());
    refreshCurrentPlanRow();
}

QVariantMap VideoProjectionPlanController::captureAt(int index) const
{
    const VideoProjectionPlan *plan = currentPlan();
    if (!plan || index < 0 || index >= plan->captures.size())
        return {};

    return captureToMap(plan->captures.at(index), index);
}

void VideoProjectionPlanController::setCaptureName(int index, const QString &name)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan || index < 0 || index >= plan->captures.size())
        return;

    const QString trimmedName = name.trimmed();
    if (trimmedName.isEmpty() || plan->captures[index].name == trimmedName)
        return;

    plan->captures[index].name = trimmedName;
    touchCurrentPlan();
    m_captureModel.setValue(index, captureToMap(plan->captures.at(index), index));
    refreshCurrentPlanRow();
}

void VideoProjectionPlanController::setCaptureRect(int index, int x, int y, int width, int height)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan || index < 0 || index >= plan->captures.size())
        return;

    const QRect rect = boundedRect(x, y, width, height, plan->videoSize);
    if (plan->captures.at(index).rect == rect)
        return;

    plan->captures[index].rect = rect;
    touchCurrentPlan();
    m_captureModel.setValue(index, captureToMap(plan->captures.at(index), index));
    refreshCurrentPlanRow();
}

int VideoProjectionPlanController::addMapping(int captureIndex,
                                              const QString &pcId,
                                              int x,
                                              int y,
                                              int width,
                                              int height,
                                              int totalScreenWidth,
                                              int totalScreenHeight,
                                              int screenColumns,
                                              int screenRows,
                                              int screenWidth,
                                              int screenHeight)
{
    VideoProjectionPlan *plan = currentPlan();
    const QString trimmedPcId = pcId.trimmed();
    if (!plan || captureIndex < 0 || captureIndex >= plan->captures.size() || trimmedPcId.isEmpty())
        return -1;

    for (int index = plan->mappings.size() - 1; index >= 0; --index) {
        if (plan->mappings.at(index).captureIndex == captureIndex)
            plan->mappings.removeAt(index);
    }

    const int columns = qMax(1, screenColumns);
    const int rows = qMax(1, screenRows);
    const QSize totalSize(qMax(1, totalScreenWidth), qMax(1, totalScreenHeight));
    const QSize screenSize(qMax(1, screenWidth), qMax(1, screenHeight));
    const int tileWidth = qMax(1, totalSize.width() / columns);
    const int tileHeight = qMax(1, totalSize.height() / rows);
    const QRect outputRect = boundedRect(x, y, width, height, totalSize);

    VideoProjectionMapping mapping;
    mapping.captureIndex = captureIndex;
    mapping.pcId = trimmedPcId;
    mapping.outputRect = outputRect;
    mapping.screenTotalSize = totalSize;
    mapping.screenResolution = screenSize;
    mapping.screenLayout = QSize(columns, rows);
    mapping.screenColumn = qBound(0, outputRect.x() / tileWidth, columns - 1);
    mapping.screenRow = qBound(0, outputRect.y() / tileHeight, rows - 1);

    plan->mappings.append(mapping);
    refreshTargetPcIds(*plan);
    touchCurrentPlan();
    m_mappingModel.resetValues(mappingValues());
    refreshCurrentPlanRow();
    return plan->mappings.size() - 1;
}

void VideoProjectionPlanController::removeMapping(int index)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan || index < 0 || index >= plan->mappings.size())
        return;

    plan->mappings.removeAt(index);
    refreshTargetPcIds(*plan);
    touchCurrentPlan();
    m_mappingModel.resetValues(mappingValues());
    refreshCurrentPlanRow();
}

QVariantMap VideoProjectionPlanController::mappingAt(int index) const
{
    const VideoProjectionPlan *plan = currentPlan();
    if (!plan || index < 0 || index >= plan->mappings.size())
        return {};

    return mappingToMap(plan->mappings.at(index), index);
}

QVariantMap VideoProjectionPlanController::mappingForCapture(int captureIndex) const
{
    const VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return {};

    for (int index = 0; index < plan->mappings.size(); ++index) {
        const VideoProjectionMapping &mapping = plan->mappings.at(index);
        if (mapping.captureIndex == captureIndex)
            return mappingToMap(mapping, index);
    }

    return {};
}

int VideoProjectionPlanController::mappingCountForPc(const QString &pcId) const
{
    const VideoProjectionPlan *plan = currentPlan();
    const QString trimmedPcId = pcId.trimmed();
    if (!plan || trimmedPcId.isEmpty())
        return 0;

    int count = 0;
    for (const VideoProjectionMapping &mapping : std::as_const(plan->mappings)) {
        if (mapping.pcId == trimmedPcId)
            ++count;
    }
    return count;
}

void VideoProjectionPlanController::removeMappingsForPc(const QString &pcId)
{
    if (pcId.isEmpty())
        return;

    bool changed = false;
    for (VideoProjectionPlan &plan : m_plans) {
        const int oldCount = plan.mappings.size();
        for (int index = plan.mappings.size() - 1; index >= 0; --index) {
            if (plan.mappings.at(index).pcId == pcId)
                plan.mappings.removeAt(index);
        }
        if (plan.mappings.size() == oldCount)
            continue;

        refreshTargetPcIds(plan);
        plan.updatedAt = QDateTime::currentDateTimeUtc();
        changed = true;
    }

    if (!changed)
        return;

    refreshPlanModel();
    refreshCurrentPlanModels();
}

void VideoProjectionPlanController::setMappingRect(int index, int x, int y, int width, int height)
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan || index < 0 || index >= plan->mappings.size())
        return;

    VideoProjectionMapping &mapping = plan->mappings[index];
    const QRect rect = boundedRect(x, y, width, height, mapping.screenTotalSize);
    if (mapping.outputRect == rect)
        return;

    mapping.outputRect = rect;
    const int columns = qMax(1, mapping.screenLayout.width());
    const int rows = qMax(1, mapping.screenLayout.height());
    const int tileWidth = qMax(1, mapping.screenTotalSize.width() / columns);
    const int tileHeight = qMax(1, mapping.screenTotalSize.height() / rows);
    mapping.screenColumn = qBound(0, rect.x() / tileWidth, columns - 1);
    mapping.screenRow = qBound(0, rect.y() / tileHeight, rows - 1);

    touchCurrentPlan();
    m_mappingModel.setValue(index, mappingToMap(mapping, index));
    refreshCurrentPlanRow();
}

QString VideoProjectionPlanController::defaultPlanName() const
{
    return tr("投影方案 %1").arg(m_plans.size() + 1);
}

QVariantMap VideoProjectionPlanController::planToMap(const VideoProjectionPlan &plan, int index) const
{
    QVariantList captures;
    captures.reserve(plan.captures.size());
    for (int captureIndex = 0; captureIndex < plan.captures.size(); ++captureIndex)
        captures.append(captureToMap(plan.captures.at(captureIndex), captureIndex));

    QVariantList mappings;
    mappings.reserve(plan.mappings.size());
    for (int mappingIndex = 0; mappingIndex < plan.mappings.size(); ++mappingIndex)
        mappings.append(mappingToMap(plan.mappings.at(mappingIndex), mappingIndex));

    return QVariantMap{
        {QStringLiteral("index"), index},
        {QStringLiteral("selected"), index == m_currentPlanIndex},
        {QStringLiteral("name"), plan.name},
        {QStringLiteral("projectionWindowId"), plan.projectionWindowId},
        {QStringLiteral("targetPcIds"), plan.targetPcIds},
        {QStringLiteral("videoSource"), plan.videoSource},
        {QStringLiteral("videoSize"), sizeToMap(plan.videoSize)},
        {QStringLiteral("videoWidth"), plan.videoSize.width()},
        {QStringLiteral("videoHeight"), plan.videoSize.height()},
        {QStringLiteral("captures"), captures},
        {QStringLiteral("mappings"), mappings},
        {QStringLiteral("createdAt"), plan.createdAt.toString(Qt::ISODate)},
        {QStringLiteral("updatedAt"), plan.updatedAt.toString(Qt::ISODate)}
    };
}

QVariantMap VideoProjectionPlanController::captureToMap(const VideoProjectionCapture &capture, int index) const
{
    return QVariantMap{
        {QStringLiteral("index"), index},
        {QStringLiteral("name"), capture.name},
        {QStringLiteral("rect"), rectToMap(capture.rect)},
        {QStringLiteral("x"), capture.rect.x()},
        {QStringLiteral("y"), capture.rect.y()},
        {QStringLiteral("w"), capture.rect.width()},
        {QStringLiteral("h"), capture.rect.height()}
    };
}

QVariantMap VideoProjectionPlanController::mappingToMap(const VideoProjectionMapping &mapping, int index) const
{
    return QVariantMap{
        {QStringLiteral("index"), index},
        {QStringLiteral("captureIndex"), mapping.captureIndex},
        {QStringLiteral("pcId"), mapping.pcId},
        {QStringLiteral("outputRect"), rectToMap(mapping.outputRect)},
        {QStringLiteral("x"), mapping.outputRect.x()},
        {QStringLiteral("y"), mapping.outputRect.y()},
        {QStringLiteral("w"), mapping.outputRect.width()},
        {QStringLiteral("h"), mapping.outputRect.height()},
        {QStringLiteral("screenTotalSize"), sizeToMap(mapping.screenTotalSize)},
        {QStringLiteral("screenResolution"), sizeToMap(mapping.screenResolution)},
        {QStringLiteral("screenLayout"), sizeToMap(mapping.screenLayout)},
        {QStringLiteral("screenColumn"), mapping.screenColumn},
        {QStringLiteral("screenRow"), mapping.screenRow}
    };
}

QVariantMap VideoProjectionPlanController::rectToMap(const QRect &rect) const
{
    return QVariantMap{
        {QStringLiteral("x"), rect.x()},
        {QStringLiteral("y"), rect.y()},
        {QStringLiteral("w"), rect.width()},
        {QStringLiteral("h"), rect.height()}
    };
}

QVariantMap VideoProjectionPlanController::sizeToMap(const QSize &size) const
{
    return QVariantMap{
        {QStringLiteral("width"), size.width()},
        {QStringLiteral("height"), size.height()}
    };
}

QRect VideoProjectionPlanController::boundedRect(int x, int y, int width, int height, const QSize &bounds) const
{
    const int boundedWidth = qMax(1, bounds.width());
    const int boundedHeight = qMax(1, bounds.height());
    const int rectWidth = qBound(1, width, boundedWidth);
    const int rectHeight = qBound(1, height, boundedHeight);
    const int rectX = qBound(0, x, boundedWidth - rectWidth);
    const int rectY = qBound(0, y, boundedHeight - rectHeight);
    return QRect(rectX, rectY, rectWidth, rectHeight);
}

QString VideoProjectionPlanController::defaultCaptureName(int index) const
{
    return tr("取景 %1").arg(index + 1);
}

void VideoProjectionPlanController::touchCurrentPlan()
{
    VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return;

    plan->updatedAt = QDateTime::currentDateTimeUtc();
}

void VideoProjectionPlanController::refreshTargetPcIds(VideoProjectionPlan &plan)
{
    QStringList targetPcIds;
    for (const VideoProjectionMapping &mapping : std::as_const(plan.mappings)) {
        if (!mapping.pcId.isEmpty() && !targetPcIds.contains(mapping.pcId))
            targetPcIds.append(mapping.pcId);
    }
    plan.targetPcIds = targetPcIds;
}

void VideoProjectionPlanController::refreshPlanModel()
{
    m_planModel.resetValues(planValues());
}

void VideoProjectionPlanController::refreshCurrentPlanRow()
{
    const VideoProjectionPlan *plan = currentPlan();
    if (!plan)
        return;

    m_planModel.setValue(m_currentPlanIndex, planToMap(*plan, m_currentPlanIndex));
}

void VideoProjectionPlanController::refreshCurrentPlanModels()
{
    m_captureModel.resetValues(captureValues());
    m_mappingModel.resetValues(mappingValues());
}

