#include "projection/ProjectionInstructionManager.h"

#include <QHash>
#include <QUuid>
#include <QtMath>

namespace TimelineControl {
namespace {

QString makeId(const QString &prefix)
{
    return prefix + QStringLiteral("-") + QUuid::createUuid().toString(QUuid::Id128).left(12);
}

QRect boundedRect(int x, int y, int width, int height, const QSize &bounds)
{
    const int boundedWidth = qBound(1, width, qMax(1, bounds.width()));
    const int boundedHeight = qBound(1, height, qMax(1, bounds.height()));
    const int boundedX = qBound(0, x, qMax(0, bounds.width() - boundedWidth));
    const int boundedY = qBound(0, y, qMax(0, bounds.height() - boundedHeight));
    return QRect(boundedX, boundedY, boundedWidth, boundedHeight);
}

double normalized(int value, int total)
{
    return total > 0 ? static_cast<double>(value) / static_cast<double>(total) : 0.0;
}

QVariantMap rectToMap(const QRect &rect)
{
    return QVariantMap{
        {QStringLiteral("x"), rect.x()},
        {QStringLiteral("y"), rect.y()},
        {QStringLiteral("w"), rect.width()},
        {QStringLiteral("h"), rect.height()}
    };
}

QVariantMap sizeToMap(const QSize &size)
{
    return QVariantMap{
        {QStringLiteral("width"), size.width()},
        {QStringLiteral("height"), size.height()}
    };
}

} // namespace

ProjectionInstructionManager::ProjectionInstructionManager(QObject *parent)
    : QObject(parent)
{
    createInstruction(tr("投影指令 1"));
}

QVariantList ProjectionInstructionManager::instructions() const
{
    return instructionData();
}

QVariantList ProjectionInstructionManager::captures() const
{
    QVariantList result;
    const auto *instruction = currentInstruction();
    if (!instruction)
        return result;

    result.reserve(instruction->captures.size());
    for (const auto &capture : instruction->captures)
        result.append(captureToMap(*instruction, capture));

    return result;
}

QVariantList ProjectionInstructionManager::mappings() const
{
    QVariantList result;
    const auto *instruction = currentInstruction();
    if (!instruction)
        return result;

    result.reserve(instruction->mappings.size());
    for (const auto &mapping : instruction->mappings)
        result.append(mappingToMap(*instruction, mapping));

    return result;
}

QAbstractItemModel *ProjectionInstructionManager::instructionModel() const
{
    return const_cast<VariantListModel *>(&m_instructionModel);
}

QAbstractItemModel *ProjectionInstructionManager::captureModel() const
{
    return const_cast<VariantListModel *>(&m_captureModel);
}

QAbstractItemModel *ProjectionInstructionManager::mappingModel() const
{
    return const_cast<VariantListModel *>(&m_mappingModel);
}

int ProjectionInstructionManager::instructionCount() const
{
    return m_instructions.size();
}

int ProjectionInstructionManager::captureCount() const
{
    const auto *instruction = currentInstruction();
    return instruction ? instruction->captures.size() : 0;
}

int ProjectionInstructionManager::mappingCount() const
{
    const auto *instruction = currentInstruction();
    return instruction ? instruction->mappings.size() : 0;
}

int ProjectionInstructionManager::currentInstructionIndex() const
{
    return m_currentInstructionIndex;
}

QString ProjectionInstructionManager::currentInstructionId() const
{
    const auto *instruction = currentInstruction();
    return instruction ? instruction->id : QString();
}

QString ProjectionInstructionManager::currentInstructionName() const
{
    const auto *instruction = currentInstruction();
    return instruction ? instruction->name : QString();
}

void ProjectionInstructionManager::setCurrentInstructionName(const QString &name)
{
    auto *instruction = currentInstruction();
    if (!instruction)
        return;

    const QString normalizedName = name.trimmed().isEmpty()
        ? tr("投影指令 %1").arg(m_currentInstructionIndex + 1)
        : name.trimmed();
    if (instruction->name == normalizedName)
        return;

    instruction->name = normalizedName;
    touchCurrentInstruction();
    emit currentInstructionNameChanged();
    emitInstructionListChanged();
}

QUrl ProjectionInstructionManager::videoSource() const
{
    const auto *instruction = currentInstruction();
    return instruction ? instruction->videoSource : QUrl();
}

void ProjectionInstructionManager::setVideoSource(const QUrl &source)
{
    auto *instruction = currentInstruction();
    if (!instruction || instruction->videoSource == source)
        return;

    instruction->videoSource = source;
    touchCurrentInstruction();
    emit videoSourceChanged();
    emitInstructionListChanged();
}

QSize ProjectionInstructionManager::videoSize() const
{
    const auto *instruction = currentInstruction();
    return instruction && instruction->videoSize.isValid() ? instruction->videoSize : QSize(1920, 1080);
}

int ProjectionInstructionManager::createInstruction(const QString &name)
{
    Instruction instruction;
    instruction.id = makeId(QStringLiteral("projection"));
    instruction.name = name.trimmed().isEmpty()
        ? tr("投影指令 %1").arg(m_instructions.size() + 1)
        : name.trimmed();
    instruction.videoSize = QSize(1920, 1080);
    instruction.createdAt = QDateTime::currentDateTimeUtc();
    instruction.updatedAt = instruction.createdAt;

    for (int captureIndex = 0; captureIndex < 2; ++captureIndex) {
        const double offset = qMin(0.24, captureIndex * 0.055);
        Capture capture;
        capture.id = makeId(QStringLiteral("capture"));
        capture.name = tr("取景 %1").arg(captureIndex + 1);
        capture.color = captureColor(captureIndex);
        capture.rect = boundedRect(qRound((0.12 + offset) * instruction.videoSize.width()),
                                   qRound((0.14 + offset * 0.7) * instruction.videoSize.height()),
                                   qRound(0.34 * instruction.videoSize.width()),
                                   qRound(0.28 * instruction.videoSize.height()),
                                   instruction.videoSize);
        instruction.captures.append(capture);
    }

    const int row = m_instructions.size();
    m_instructions.append(instruction);
    emit instructionCountChanged();
    emitInstructionListChanged();

    selectInstruction(row);
    return row;
}

int ProjectionInstructionManager::duplicateCurrentInstruction()
{
    const auto *current = currentInstruction();
    if (!current)
        return -1;

    Instruction copy = *current;
    copy.id = makeId(QStringLiteral("projection"));
    copy.name = tr("%1 副本").arg(current->name);
    copy.createdAt = QDateTime::currentDateTimeUtc();
    copy.updatedAt = copy.createdAt;

    QHash<QString, QString> captureIds;
    for (auto &capture : copy.captures) {
        const QString previousId = capture.id;
        capture.id = makeId(QStringLiteral("capture"));
        captureIds.insert(previousId, capture.id);
    }

    for (auto &mapping : copy.mappings) {
        mapping.id = makeId(QStringLiteral("mapping"));
        mapping.captureId = captureIds.value(mapping.captureId, mapping.captureId);
    }

    const int row = m_instructions.size();
    m_instructions.append(copy);
    emit instructionCountChanged();
    emitInstructionListChanged();

    selectInstruction(row);
    return row;
}

void ProjectionInstructionManager::removeCurrentInstruction()
{
    if (m_instructions.size() <= 1 || m_currentInstructionIndex < 0 || m_currentInstructionIndex >= m_instructions.size())
        return;

    const int removedRow = m_currentInstructionIndex;
    m_instructions.removeAt(removedRow);
    emit instructionCountChanged();

    m_currentInstructionIndex = qBound(0, removedRow, m_instructions.size() - 1);
    emit currentInstructionChanged();
    emit currentInstructionNameChanged();
    emit videoSourceChanged();
    emit videoSizeChanged();
    emit captureCountChanged();
    emit mappingCountChanged();
    emitInstructionListChanged();
    emitCaptureListChanged();
    emitMappingListChanged();
}

void ProjectionInstructionManager::selectInstruction(int index)
{
    if (index < 0 || index >= m_instructions.size() || index == m_currentInstructionIndex)
        return;

    m_currentInstructionIndex = index;
    emit currentInstructionChanged();
    emit currentInstructionNameChanged();
    emit videoSourceChanged();
    emit videoSizeChanged();
    emit captureCountChanged();
    emit mappingCountChanged();
    emitInstructionListChanged();
    emitCaptureListChanged();
    emitMappingListChanged();
}

void ProjectionInstructionManager::selectInstructionById(const QString &id)
{
    for (int index = 0; index < m_instructions.size(); ++index) {
        if (m_instructions.at(index).id == id) {
            selectInstruction(index);
            return;
        }
    }
}

int ProjectionInstructionManager::addCapture()
{
    auto *instruction = currentInstruction();
    if (!instruction)
        return -1;

    const QSize size = videoSize();
    const int index = instruction->captures.size();
    const double offset = qMin(0.24, index * 0.055);
    Capture capture;
    capture.id = makeId(QStringLiteral("capture"));
    capture.name = tr("取景 %1").arg(index + 1);
    capture.color = captureColor(index);
    capture.rect = boundedRect(qRound((0.12 + offset) * size.width()),
                               qRound((0.14 + offset * 0.7) * size.height()),
                               qRound(0.34 * size.width()),
                               qRound(0.28 * size.height()),
                               size);

    instruction->captures.append(capture);
    touchCurrentInstruction();
    emit captureCountChanged();
    emitCaptureListChanged();
    emitInstructionListChanged();
    return index;
}

void ProjectionInstructionManager::removeCapture(int index)
{
    auto *instruction = currentInstruction();
    if (!instruction || instruction->captures.size() <= 1 || index < 0 || index >= instruction->captures.size())
        return;

    const QString removedId = instruction->captures.at(index).id;
    instruction->captures.removeAt(index);
    const bool mappingsChanged = removeMappingsForCaptureId(removedId);
    touchCurrentInstruction();

    emit captureCountChanged();
    emitCaptureListChanged();
    if (mappingsChanged)
        emit mappingCountChanged();

    if (mappingsChanged || !instruction->mappings.isEmpty())
        emitMappingListChanged();

    emitInstructionListChanged();
}

QVariantMap ProjectionInstructionManager::captureAt(int index) const
{
    const auto *instruction = currentInstruction();
    if (!instruction || index < 0 || index >= instruction->captures.size())
        return {};

    return captureToMap(*instruction, instruction->captures.at(index));
}

QVariantMap ProjectionInstructionManager::mappingAt(int index) const
{
    const auto *instruction = currentInstruction();
    if (!instruction || index < 0 || index >= instruction->mappings.size())
        return {};

    return mappingToMap(*instruction, instruction->mappings.at(index));
}

void ProjectionInstructionManager::setVideoSize(int width, int height)
{
    auto *instruction = currentInstruction();
    const QSize size(qMax(1, width), qMax(1, height));
    if (!instruction || instruction->videoSize == size)
        return;

    instruction->videoSize = size;
    touchCurrentInstruction();
    emit videoSizeChanged();
    emitCaptureListChanged();
    emitInstructionListChanged();
}

void ProjectionInstructionManager::setCaptureGeometryNormalized(int index,
                                                                double x,
                                                                double y,
                                                                double width,
                                                                double height)
{
    auto *instruction = currentInstruction();
    if (!instruction || index < 0 || index >= instruction->captures.size())
        return;

    const QRect rect = normalizedCaptureRect(x, y, width, height);
    if (instruction->captures[index].rect == rect)
        return;

    instruction->captures[index].rect = rect;
    touchCurrentInstruction();
    refreshCaptureRow(index);
    refreshInstructionRow(m_currentInstructionIndex);
}

void ProjectionInstructionManager::setMappingGeometryNormalized(int index,
                                                                double x,
                                                                double y,
                                                                double width,
                                                                double height,
                                                                int totalScreenWidth,
                                                                int totalScreenHeight)
{
    auto *instruction = currentInstruction();
    if (!instruction || index < 0 || index >= instruction->mappings.size())
        return;

    const QSize totalSize(qMax(1, totalScreenWidth), qMax(1, totalScreenHeight));
    const QRect rect = normalizedMappingRect(x, y, width, height, totalSize);
    auto &mapping = instruction->mappings[index];
    if (mapping.rect == rect && mapping.screenTotalSize == totalSize)
        return;

    mapping.rect = rect;
    mapping.screenTotalSize = totalSize;
    touchCurrentInstruction();
    refreshMappingRow(index);
    refreshInstructionRow(m_currentInstructionIndex);
}

void ProjectionInstructionManager::createMappingAtScreenPoint(int captureIndex,
                                                              const QString &pcId,
                                                              double normalizedX,
                                                              double normalizedY,
                                                              int totalScreenWidth,
                                                              int totalScreenHeight,
                                                              int screenColumns,
                                                              int screenRows,
                                                              int screenWidth,
                                                              int screenHeight)
{
    auto *instruction = currentInstruction();
    if (!instruction || captureIndex < 0 || captureIndex >= instruction->captures.size())
        return;

    const QSize totalSize(qMax(1, totalScreenWidth), qMax(1, totalScreenHeight));
    const int columns = qMax(1, screenColumns);
    const int rows = qMax(1, screenRows);
    const int column = qBound(0, static_cast<int>(qFloor(normalizedX * columns)), columns - 1);
    const int row = qBound(0, static_cast<int>(qFloor(normalizedY * rows)), rows - 1);
    const int tileX = qRound(static_cast<double>(column) * totalSize.width() / columns);
    const int tileY = qRound(static_cast<double>(row) * totalSize.height() / rows);
    const int tileW = qMax(1, qRound(static_cast<double>(totalSize.width()) / columns));
    const int tileH = qMax(1, qRound(static_cast<double>(totalSize.height()) / rows));
    const auto &capture = instruction->captures.at(captureIndex);
    const int rectW = qBound(1, capture.rect.width(), tileW);
    const int rectH = qBound(1, capture.rect.height(), tileH);
    const int centerX = qRound(qBound(0.0, normalizedX, 1.0) * totalSize.width());
    const int centerY = qRound(qBound(0.0, normalizedY, 1.0) * totalSize.height());

    Mapping mapping;
    mapping.id = makeId(QStringLiteral("mapping"));
    mapping.captureId = capture.id;
    mapping.captureName = capture.name;
    mapping.color = capture.color;
    mapping.pcId = pcId;
    mapping.screenColumn = column;
    mapping.screenRow = row;
    mapping.screenTotalSize = totalSize;
    mapping.screenResolution = QSize(qMax(1, screenWidth), qMax(1, screenHeight));
    mapping.screenLayout = QSize(columns, rows);
    mapping.rect = QRect(qBound(tileX, centerX - rectW / 2, tileX + tileW - rectW),
                         qBound(tileY, centerY - rectH / 2, tileY + tileH - rectH),
                         rectW,
                         rectH);

    const int oldMappingCount = instruction->mappings.size();
    removeMappingsForCaptureId(capture.id);
    instruction->mappings.append(mapping);
    touchCurrentInstruction();

    if (oldMappingCount != instruction->mappings.size())
        emit mappingCountChanged();

    emitMappingListChanged();
    emitInstructionListChanged();
}

QVariantMap ProjectionInstructionManager::currentInstructionData() const
{
    const auto *instruction = currentInstruction();
    return instruction ? instructionToMap(*instruction) : QVariantMap();
}

QVariantList ProjectionInstructionManager::instructionData() const
{
    QVariantList result;
    result.reserve(m_instructions.size());
    for (const auto &instruction : m_instructions)
        result.append(instructionToMap(instruction));

    return result;
}

ProjectionInstructionManager::Instruction *ProjectionInstructionManager::currentInstruction()
{
    if (m_currentInstructionIndex < 0 || m_currentInstructionIndex >= m_instructions.size())
        return nullptr;

    return &m_instructions[m_currentInstructionIndex];
}

const ProjectionInstructionManager::Instruction *ProjectionInstructionManager::currentInstruction() const
{
    if (m_currentInstructionIndex < 0 || m_currentInstructionIndex >= m_instructions.size())
        return nullptr;

    return &m_instructions.at(m_currentInstructionIndex);
}

int ProjectionInstructionManager::captureIndexForId(const Instruction &instruction, const QString &captureId) const
{
    for (int index = 0; index < instruction.captures.size(); ++index) {
        if (instruction.captures.at(index).id == captureId)
            return index;
    }

    return -1;
}

QString ProjectionInstructionManager::captureColor(int index) const
{
    static const QStringList colors{
        QStringLiteral("#7cb4ff"),
        QStringLiteral("#36d399"),
        QStringLiteral("#fbbf24"),
        QStringLiteral("#f472b6"),
        QStringLiteral("#a78bfa")
    };
    return colors.at(index % colors.size());
}

QRect ProjectionInstructionManager::normalizedCaptureRect(double x, double y, double width, double height) const
{
    const QSize size = videoSize();
    return boundedRect(qRound(x * size.width()),
                       qRound(y * size.height()),
                       qRound(width * size.width()),
                       qRound(height * size.height()),
                       size);
}

QRect ProjectionInstructionManager::normalizedMappingRect(double x,
                                                          double y,
                                                          double width,
                                                          double height,
                                                          const QSize &totalSize) const
{
    return boundedRect(qRound(x * totalSize.width()),
                       qRound(y * totalSize.height()),
                       qRound(width * totalSize.width()),
                       qRound(height * totalSize.height()),
                       totalSize);
}

QVariantMap ProjectionInstructionManager::instructionToMap(const Instruction &instruction) const
{
    QVariantList captures;
    captures.reserve(instruction.captures.size());
    for (const auto &capture : instruction.captures)
        captures.append(captureToMap(instruction, capture));

    QVariantList mappings;
    mappings.reserve(instruction.mappings.size());
    for (const auto &mapping : instruction.mappings)
        mappings.append(mappingToMap(instruction, mapping));

    return QVariantMap{
        {QStringLiteral("id"), instruction.id},
        {QStringLiteral("instructionId"), instruction.id},
        {QStringLiteral("name"), instruction.name},
        {QStringLiteral("instructionName"), instruction.name},
        {QStringLiteral("videoSource"), instruction.videoSource},
        {QStringLiteral("videoSize"), sizeToMap(instruction.videoSize)},
        {QStringLiteral("videoWidth"), instruction.videoSize.width()},
        {QStringLiteral("videoHeight"), instruction.videoSize.height()},
        {QStringLiteral("captureCount"), instruction.captures.size()},
        {QStringLiteral("mappingCount"), instruction.mappings.size()},
        {QStringLiteral("selected"), instruction.id == currentInstructionId()},
        {QStringLiteral("captures"), captures},
        {QStringLiteral("mappings"), mappings},
        {QStringLiteral("createdAt"), instruction.createdAt.toString(Qt::ISODate)},
        {QStringLiteral("updatedAt"), instruction.updatedAt.toString(Qt::ISODate)}
    };
}

QVariantMap ProjectionInstructionManager::captureToMap(const Instruction &instruction, const Capture &capture) const
{
    const QSize size = instruction.videoSize.isValid() ? instruction.videoSize : QSize(1920, 1080);
    return QVariantMap{
        {QStringLiteral("id"), capture.id},
        {QStringLiteral("captureId"), capture.id},
        {QStringLiteral("name"), capture.name},
        {QStringLiteral("captureName"), capture.name},
        {QStringLiteral("rect"), rectToMap(capture.rect)},
        {QStringLiteral("x"), capture.rect.x()},
        {QStringLiteral("y"), capture.rect.y()},
        {QStringLiteral("w"), capture.rect.width()},
        {QStringLiteral("h"), capture.rect.height()},
        {QStringLiteral("pixelX"), capture.rect.x()},
        {QStringLiteral("pixelY"), capture.rect.y()},
        {QStringLiteral("pixelW"), capture.rect.width()},
        {QStringLiteral("pixelH"), capture.rect.height()},
        {QStringLiteral("rectX"), normalized(capture.rect.x(), size.width())},
        {QStringLiteral("rectY"), normalized(capture.rect.y(), size.height())},
        {QStringLiteral("rectW"), normalized(capture.rect.width(), size.width())},
        {QStringLiteral("rectH"), normalized(capture.rect.height(), size.height())},
        {QStringLiteral("color"), capture.color},
        {QStringLiteral("strokeColor"), capture.color}
    };
}

QVariantMap ProjectionInstructionManager::mappingToMap(const Instruction &instruction, const Mapping &mapping) const
{
    const QSize totalSize = mapping.screenTotalSize.isValid() ? mapping.screenTotalSize : QSize(1920, 1080);
    return QVariantMap{
        {QStringLiteral("id"), mapping.id},
        {QStringLiteral("mappingId"), mapping.id},
        {QStringLiteral("captureId"), mapping.captureId},
        {QStringLiteral("captureIndex"), captureIndexForId(instruction, mapping.captureId)},
        {QStringLiteral("name"), mapping.captureName},
        {QStringLiteral("captureName"), mapping.captureName},
        {QStringLiteral("color"), mapping.color},
        {QStringLiteral("strokeColor"), mapping.color},
        {QStringLiteral("pcId"), mapping.pcId},
        {QStringLiteral("screenColumn"), mapping.screenColumn},
        {QStringLiteral("screenRow"), mapping.screenRow},
        {QStringLiteral("rect"), rectToMap(mapping.rect)},
        {QStringLiteral("x"), mapping.rect.x()},
        {QStringLiteral("y"), mapping.rect.y()},
        {QStringLiteral("w"), mapping.rect.width()},
        {QStringLiteral("h"), mapping.rect.height()},
        {QStringLiteral("pixelX"), mapping.rect.x()},
        {QStringLiteral("pixelY"), mapping.rect.y()},
        {QStringLiteral("pixelW"), mapping.rect.width()},
        {QStringLiteral("pixelH"), mapping.rect.height()},
        {QStringLiteral("rectX"), normalized(mapping.rect.x(), totalSize.width())},
        {QStringLiteral("rectY"), normalized(mapping.rect.y(), totalSize.height())},
        {QStringLiteral("rectW"), normalized(mapping.rect.width(), totalSize.width())},
        {QStringLiteral("rectH"), normalized(mapping.rect.height(), totalSize.height())},
        {QStringLiteral("screenTotalSize"), sizeToMap(totalSize)},
        {QStringLiteral("screenResolution"), sizeToMap(mapping.screenResolution)},
        {QStringLiteral("screenLayout"), sizeToMap(mapping.screenLayout)},
        {QStringLiteral("screenWidth"), mapping.screenResolution.width()},
        {QStringLiteral("screenHeight"), mapping.screenResolution.height()},
        {QStringLiteral("screenColumns"), mapping.screenLayout.width()},
        {QStringLiteral("screenRows"), mapping.screenLayout.height()},
        {QStringLiteral("screenTotalWidth"), totalSize.width()},
        {QStringLiteral("screenTotalHeight"), totalSize.height()}
    };
}

void ProjectionInstructionManager::touchCurrentInstruction()
{
    auto *instruction = currentInstruction();
    if (!instruction)
        return;

    instruction->updatedAt = QDateTime::currentDateTimeUtc();
}

bool ProjectionInstructionManager::removeMappingsForCaptureId(const QString &captureId)
{
    auto *instruction = currentInstruction();
    if (!instruction)
        return false;

    bool removed = false;
    for (int index = instruction->mappings.size() - 1; index >= 0; --index) {
        if (instruction->mappings.at(index).captureId != captureId)
            continue;

        instruction->mappings.removeAt(index);
        removed = true;
    }

    return removed;
}

void ProjectionInstructionManager::emitInstructionListChanged()
{
    m_instructionModel.resetValues(instructions());
    emit instructionsChanged();
}

void ProjectionInstructionManager::emitCaptureListChanged()
{
    m_captureModel.resetValues(captures());
    emit capturesChanged();
}

void ProjectionInstructionManager::emitMappingListChanged()
{
    m_mappingModel.resetValues(mappings());
    emit mappingsChanged();
}

void ProjectionInstructionManager::refreshInstructionRow(int index)
{
    if (index < 0 || index >= m_instructions.size())
        return;

    m_instructionModel.setValue(index, instructionToMap(m_instructions.at(index)));
    emit instructionsChanged();
}

void ProjectionInstructionManager::refreshCaptureRow(int index)
{
    const auto *instruction = currentInstruction();
    if (!instruction || index < 0 || index >= instruction->captures.size())
        return;

    m_captureModel.setValue(index, captureToMap(*instruction, instruction->captures.at(index)));
    emit capturesChanged();
}

void ProjectionInstructionManager::refreshMappingRow(int index)
{
    const auto *instruction = currentInstruction();
    if (!instruction || index < 0 || index >= instruction->mappings.size())
        return;

    m_mappingModel.setValue(index, mappingToMap(*instruction, instruction->mappings.at(index)));
    emit mappingsChanged();
}

} // namespace TimelineControl
