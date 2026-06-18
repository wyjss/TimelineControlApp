#pragma once

#include <QDateTime>
#include <QAbstractItemModel>
#include <QObject>
#include <QRect>
#include <QSize>
#include <QUrl>
#include <QVariantList>
#include <QVector>

#include "models/VariantListModel.h"

namespace TimelineControl {

class ProjectionInstructionManager final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QAbstractItemModel *instructionModel READ instructionModel CONSTANT FINAL)
    Q_PROPERTY(QAbstractItemModel *captureModel READ captureModel CONSTANT FINAL)
    Q_PROPERTY(QAbstractItemModel *mappingModel READ mappingModel CONSTANT FINAL)
    Q_PROPERTY(QVariantList instructions READ instructions NOTIFY instructionsChanged FINAL)
    Q_PROPERTY(QVariantList captures READ captures NOTIFY capturesChanged FINAL)
    Q_PROPERTY(QVariantList mappings READ mappings NOTIFY mappingsChanged FINAL)
    Q_PROPERTY(int instructionCount READ instructionCount NOTIFY instructionCountChanged FINAL)
    Q_PROPERTY(int captureCount READ captureCount NOTIFY captureCountChanged FINAL)
    Q_PROPERTY(int mappingCount READ mappingCount NOTIFY mappingCountChanged FINAL)
    Q_PROPERTY(int currentInstructionIndex READ currentInstructionIndex NOTIFY currentInstructionChanged FINAL)
    Q_PROPERTY(QString currentInstructionId READ currentInstructionId NOTIFY currentInstructionChanged FINAL)
    Q_PROPERTY(QString currentInstructionName READ currentInstructionName WRITE setCurrentInstructionName NOTIFY currentInstructionNameChanged FINAL)
    Q_PROPERTY(QUrl videoSource READ videoSource WRITE setVideoSource NOTIFY videoSourceChanged FINAL)
    Q_PROPERTY(QSize videoSize READ videoSize NOTIFY videoSizeChanged FINAL)

public:
    explicit ProjectionInstructionManager(QObject *parent = nullptr);

    QVariantList instructions() const;
    QVariantList captures() const;
    QVariantList mappings() const;
    QAbstractItemModel *instructionModel() const;
    QAbstractItemModel *captureModel() const;
    QAbstractItemModel *mappingModel() const;

    int instructionCount() const;
    int captureCount() const;
    int mappingCount() const;
    int currentInstructionIndex() const;
    QString currentInstructionId() const;
    QString currentInstructionName() const;
    void setCurrentInstructionName(const QString &name);
    QUrl videoSource() const;
    void setVideoSource(const QUrl &source);
    QSize videoSize() const;

    Q_INVOKABLE int createInstruction(const QString &name = QString());
    Q_INVOKABLE int duplicateCurrentInstruction();
    Q_INVOKABLE void removeCurrentInstruction();
    Q_INVOKABLE void selectInstruction(int index);
    Q_INVOKABLE void selectInstructionById(const QString &id);
    Q_INVOKABLE int addCapture();
    Q_INVOKABLE void removeCapture(int index);
    Q_INVOKABLE QVariantMap captureAt(int index) const;
    Q_INVOKABLE QVariantMap mappingAt(int index) const;
    Q_INVOKABLE void setVideoSize(int width, int height);
    Q_INVOKABLE void setCaptureGeometryNormalized(int index, double x, double y, double width, double height);
    Q_INVOKABLE void setMappingGeometryNormalized(int index,
                                                  double x,
                                                  double y,
                                                  double width,
                                                  double height,
                                                  int totalScreenWidth,
                                                  int totalScreenHeight);
    Q_INVOKABLE void createMappingAtScreenPoint(int captureIndex,
                                                const QString &pcId,
                                                double normalizedX,
                                                double normalizedY,
                                                int totalScreenWidth,
                                                int totalScreenHeight,
                                                int screenColumns,
                                                int screenRows,
                                                int screenWidth,
                                                int screenHeight);
    Q_INVOKABLE QVariantMap currentInstructionData() const;
    Q_INVOKABLE QVariantList instructionData() const;

signals:
    void instructionsChanged();
    void capturesChanged();
    void mappingsChanged();
    void instructionCountChanged();
    void captureCountChanged();
    void mappingCountChanged();
    void currentInstructionChanged();
    void currentInstructionNameChanged();
    void videoSourceChanged();
    void videoSizeChanged();

private:
    struct Capture
    {
        QString id;
        QString name;
        QRect rect;
        QString color;
    };

    struct Mapping
    {
        QString id;
        QString captureId;
        QString captureName;
        QString color;
        QString pcId;
        QRect rect;
        QSize screenTotalSize;
        QSize screenResolution;
        QSize screenLayout;
        int screenColumn = 0;
        int screenRow = 0;
    };

    struct Instruction
    {
        QString id;
        QString name;
        QUrl videoSource;
        QSize videoSize = QSize(1920, 1080);
        QVector<Capture> captures;
        QVector<Mapping> mappings;
        QDateTime createdAt;
        QDateTime updatedAt;
    };

    Instruction *currentInstruction();
    const Instruction *currentInstruction() const;
    int captureIndexForId(const Instruction &instruction, const QString &captureId) const;
    QString captureColor(int index) const;
    QRect normalizedCaptureRect(double x, double y, double width, double height) const;
    QRect normalizedMappingRect(double x, double y, double width, double height, const QSize &totalSize) const;
    QVariantMap instructionToMap(const Instruction &instruction) const;
    QVariantMap captureToMap(const Instruction &instruction, const Capture &capture) const;
    QVariantMap mappingToMap(const Instruction &instruction, const Mapping &mapping) const;
    void touchCurrentInstruction();
    bool removeMappingsForCaptureId(const QString &captureId);
    void emitInstructionListChanged();
    void emitCaptureListChanged();
    void emitMappingListChanged();
    void refreshInstructionRow(int index);
    void refreshCaptureRow(int index);
    void refreshMappingRow(int index);

    QVector<Instruction> m_instructions;
    VariantListModel m_instructionModel;
    VariantListModel m_captureModel;
    VariantListModel m_mappingModel;
    int m_currentInstructionIndex = -1;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::ProjectionInstructionManager *)
