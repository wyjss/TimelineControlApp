#pragma once

#include <QByteArray>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVector>

class QDataStream;
class TimelineCommandModel;
class TimelineController;


//! 管理同一设备项目下的多套时间轴，并复用稳定的活动指令模型。
class TimelinePlanController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList plans READ plans NOTIFY plansChanged FINAL)
    Q_PROPERTY(int currentPlanIndex READ currentPlanIndex WRITE setCurrentPlanIndex NOTIFY currentPlanChanged FINAL)
    Q_PROPERTY(QString currentPlanName READ currentPlanName NOTIFY currentPlanChanged FINAL)
    Q_PROPERTY(QStringList selectedPlanIds READ selectedPlanIds NOTIFY selectedPlansChanged FINAL)

public:
    enum PlaybackState
    {
        Idle,
        Playing,
        Paused,
        Completed
    };
    Q_ENUM(PlaybackState)

    explicit TimelinePlanController(TimelineCommandModel *commandModel,
                                    TimelineController *timelineController,
                                    QObject *parent = nullptr);

    QVariantList plans() const;
    int currentPlanIndex() const;
    QString currentPlanName() const;
    QStringList selectedPlanIds() const;
    void setCurrentPlanIndex(int index);
    bool setCurrentPlanId(const QString &planId);
    void resetPlaybackStates();
    void setPlanPlaybackState(const QString &planId, PlaybackState state);

    Q_INVOKABLE int createPlan(const QString &name);
    Q_INVOKABLE int duplicateCurrentPlan(const QString &name);
    Q_INVOKABLE bool removeCurrentPlan();
    Q_INVOKABLE void togglePlanSelected(const QString &planId);

    void resetFromCurrentModel();
    void removeCommandsForDevice(const QString &deviceId);
    void writeToStream(QDataStream &stream) const;
    bool readFromStream(QDataStream &stream);

signals:
    void plansChanged();
    void currentPlanChanged();
    void selectedPlansChanged();

private:
    struct Plan
    {
        QString id;
        QString name;
        QByteArray commandData;
        PlaybackState playbackState = Idle;
    };

    QByteArray commandData(TimelineCommandModel *model) const;
    bool restoreCommandData(TimelineCommandModel *model, const QByteArray &data) const;
    void storeCurrentPlan();
    bool restoreCurrentPlan();
    bool canChangePlan() const;

    TimelineCommandModel *m_commandModel = nullptr;
    TimelineController *m_timelineController = nullptr;
    QVector<Plan> m_plans;
    QStringList m_selectedPlanIds;
    int m_currentPlanIndex = -1;
};


Q_DECLARE_METATYPE(TimelinePlanController *)
