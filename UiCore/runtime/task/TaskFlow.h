#ifndef EARTH_TASK_TASKFLOW_H
#define EARTH_TASK_TASKFLOW_H

#include <QAbstractTransition>
#include <QEvent>
#include <QPointer>
#include <QState>
#include <QStateMachine>
#include <QtGlobal>
#include <QVector>

#include "Task.h"
#include "TaskManager.h"

class TaskFlow : public Task
{
public:
    struct Step
    {
        QPointer<Task> task;
        QString name;
    };

    explicit TaskFlow(const QString& taskName,
                      ExecutionMode executionMode = Serial,
                      const QString& concurrencyKey = QString(),
                      DispatchHint dispatchHint = Direct,
                      const QString& detail = QString(),
                      QObject* parent = nullptr)
        : Task(taskName, executionMode, concurrencyKey, dispatchHint, detail, parent)
    {
        m_stepManager.setAutoStart(false);
        setupStateMachine();
        m_machine.start();
    }

    bool appendStep(Task* task, const QString& stepName = QString())
    {
        if (!task || phase() != Ready || m_waitingForAdvance)
            return false;

        if (m_machine.configuration().contains(m_runningState)
            || m_machine.configuration().contains(m_waitingState)
            || finished()) {
            return false;
        }

        if (task->phase() != Task::Ready)
            return false;

        if (!m_stepManager.registerTask(task))
            return false;

        Step step;
        step.task = task;
        step.name = stepName;
        m_steps.append(step);

        QObject::connect(task, &Task::stateChanged, this, [this, task]() { onStepStateChanged(task); });
        QObject::connect(task, &QObject::destroyed, this, [this, task]() { onStepDestroyed(task); });

        refreshReadySnapshot();
        return true;
    }

    void clearSteps()
    {
        if (phase() != Ready || m_machine.configuration().contains(m_runningState)
            || m_machine.configuration().contains(m_waitingState) || finished()) {
            return;
        }

        for (const Step& step : m_steps) {
            if (!step.task)
                continue;

            QObject::disconnect(step.task, nullptr, this, nullptr);
            m_stepManager.unregisterTask(step.task);
        }

        m_steps.clear();
        m_currentStepIndex = -1;
        m_pendingStepIndex = -1;
        m_waitingForAdvance = false;
        m_stepOutcomePosted = false;
        refreshReadySnapshot();
    }

    int stepCount() const
    {
        return m_steps.size();
    }

    int currentStepIndex() const
    {
        return m_currentStepIndex;
    }

    Task* currentStep() const
    {
        if (m_currentStepIndex < 0 || m_currentStepIndex >= m_steps.size())
            return nullptr;

        return m_steps.at(m_currentStepIndex).task;
    }

    QString currentStepName() const
    {
        if (m_currentStepIndex < 0 || m_currentStepIndex >= m_steps.size())
            return QString();

        return stepDisplayName(m_steps.at(m_currentStepIndex));
    }

    bool waitingForAdvance() const
    {
        return m_waitingForAdvance;
    }

    bool canAdvance() const
    {
        return m_waitingForAdvance && currentStep() != nullptr;
    }

    bool advance()
    {
        if (!canAdvance())
            return false;

        m_waitingForAdvance = false;

        const int nextStepIndex = m_currentStepIndex + 1;
        if (nextStepIndex < m_steps.size()) {
            m_pendingStepIndex = nextStepIndex;
            postEvent(EventAdvance);
        } else {
            m_pendingStepIndex = -1;
            postEvent(EventComplete);
        }

        return true;
    }

protected:
    void start() override
    {
        if (phase() != Ready || finished())
            return;

        if (m_steps.isEmpty()) {
            postEvent(EventComplete);
            return;
        }

        if (m_currentStepIndex < 0)
            m_currentStepIndex = 0;

        m_pendingStepIndex = -1;
        m_waitingForAdvance = false;
        m_stepOutcomePosted = false;
        postEvent(EventBegin);
    }

    void cancel() override
    {
        if (finished())
            return;

        Task* step = currentStep();
        if (step && step->running() && m_stepManager.cancelTask(step))
            return;

        postEvent(EventCancel);
    }

private:
    enum EventId {
        EventBegin = QEvent::User + 201,
        EventStepSucceeded,
        EventStepFailed,
        EventStepCancelled,
        EventAdvance,
        EventComplete,
        EventCancel,
    };

    class FlowTransition : public QAbstractTransition
    {
    public:
        explicit FlowTransition(QEvent::Type eventType)
            : m_eventType(eventType)
        {
        }

    protected:
        bool eventTest(QEvent* event) override
        {
            return event && event->type() == m_eventType;
        }

        void onTransition(QEvent*) override
        {
        }

    private:
        QEvent::Type m_eventType;
    };

    static QEvent::Type toEventType(EventId id)
    {
        return static_cast<QEvent::Type>(id);
    }

    void postEvent(EventId id)
    {
        m_machine.postEvent(new QEvent(toEventType(id)));
    }

    static void addTransition(QState* source, EventId id, QAbstractState* target)
    {
        FlowTransition* transition = new FlowTransition(toEventType(id));
        transition->setTargetState(target);
        source->addTransition(transition);
    }

    void setupStateMachine()
    {
        m_readyState = new QState(&m_machine);
        m_runningState = new QState(&m_machine);
        m_waitingState = new QState(&m_machine);
        m_succeededState = new QState(&m_machine);
        m_failedState = new QState(&m_machine);
        m_cancelledState = new QState(&m_machine);

        m_machine.setInitialState(m_readyState);

        addTransition(m_readyState, EventBegin, m_runningState);
        addTransition(m_readyState, EventComplete, m_succeededState);
        addTransition(m_readyState, EventCancel, m_cancelledState);

        addTransition(m_runningState, EventStepSucceeded, m_waitingState);
        addTransition(m_runningState, EventStepFailed, m_failedState);
        addTransition(m_runningState, EventStepCancelled, m_cancelledState);
        addTransition(m_runningState, EventCancel, m_cancelledState);

        addTransition(m_waitingState, EventAdvance, m_runningState);
        addTransition(m_waitingState, EventComplete, m_succeededState);
        addTransition(m_waitingState, EventCancel, m_cancelledState);

        QObject::connect(m_readyState, &QState::entered, this, [this]() { refreshReadySnapshot(); });
        QObject::connect(m_runningState, &QState::entered, this, [this]() { enterRunningState(); });
        QObject::connect(m_waitingState, &QState::entered, this, [this]() { enterWaitingState(); });
        QObject::connect(m_succeededState, &QState::entered, this, [this]() { enterSucceededState(); });
        QObject::connect(m_failedState, &QState::entered, this, [this]() { enterFailedState(); });
        QObject::connect(m_cancelledState, &QState::entered, this, [this]() { enterCancelledState(); });
    }

    void refreshReadySnapshot()
    {
        if (finished())
            return;

        if (m_steps.isEmpty()) {
            applyState(Ready, 0.0f, QStringLiteral("未配置步骤"), QString());
            return;
        }

        applyState(Ready, 0.0f, QStringLiteral("流程已就绪"), QString());
    }

    void enterRunningState()
    {
        if (m_pendingStepIndex >= 0) {
            m_currentStepIndex = m_pendingStepIndex;
            m_pendingStepIndex = -1;
        } else if (m_currentStepIndex < 0) {
            m_currentStepIndex = 0;
        }

        m_waitingForAdvance = false;
        m_stepOutcomePosted = false;

        Task* step = currentStep();
        if (!step) {
            postEvent(EventStepFailed);
            return;
        }

        updateRunningSnapshot();
        if (!m_stepManager.startTask(step))
            postEvent(EventStepFailed);
    }

    void enterWaitingState()
    {
        m_waitingForAdvance = true;

        Task* step = currentStep();
        const QString name = currentStepName();
        const float progress = completedProgress();
        const QString message = step && !step->message().isEmpty()
            ? step->message()
            : QStringLiteral("步骤已完成，请调用 advance() 继续");

        applyState(Running,
                   progress,
                   name.isEmpty() ? message : QStringLiteral("%1: %2").arg(name, message),
                   QString());
    }

    void enterSucceededState()
    {
        m_waitingForAdvance = false;
        m_stepOutcomePosted = true;
        applyState(Succeeded, 1.0f, QStringLiteral("流程已完成"), QString());
    }

    void enterFailedState()
    {
        m_waitingForAdvance = false;
        m_stepOutcomePosted = true;

        Task* step = currentStep();
        const QString error = step && !step->error().isEmpty()
            ? step->error()
            : QStringLiteral("步骤失败");
        const QString name = currentStepName();

        applyState(Failed,
                   currentProgress(),
                   name.isEmpty() ? QStringLiteral("流程失败") : QStringLiteral("%1 失败").arg(name),
                   error);
    }

    void enterCancelledState()
    {
        m_waitingForAdvance = false;
        m_stepOutcomePosted = true;

        Task* step = currentStep();
        const QString message = step && !step->message().isEmpty()
            ? step->message()
            : QStringLiteral("流程已取消");

        applyState(Cancelled, currentProgress(), message, QString());
    }

    void onStepStateChanged(Task* task)
    {
        if (!task || task != currentStep())
            return;

        if (phase() == Running && !m_waitingForAdvance)
            updateRunningSnapshot();

        if (!task->finished() || m_stepOutcomePosted)
            return;

        m_stepOutcomePosted = true;

        switch (task->phase()) {
        case Task::Succeeded:
            postEvent(EventStepSucceeded);
            break;
        case Task::Cancelled:
            postEvent(EventStepCancelled);
            break;
        case Task::Failed:
        default:
            postEvent(EventStepFailed);
            break;
        }
    }

    void onStepDestroyed(Task*)
    {
        if (finished() || m_waitingForAdvance)
            return;

        if (m_currentStepIndex >= 0 && m_currentStepIndex < m_steps.size()
            && m_steps.at(m_currentStepIndex).task.isNull()) {
            postEvent(EventStepFailed);
        }
    }

    void updateRunningSnapshot()
    {
        Task* step = currentStep();
        if (!step) {
            applyState(Failed, currentProgress(), QStringLiteral("当前步骤缺失"), QStringLiteral("当前步骤缺失"));
            return;
        }

        const QString name = currentStepName();
        const QString stepMessage = step->message().isEmpty()
            ? QStringLiteral("运行中")
            : step->message();

        applyState(Running,
                   currentProgress(),
                   name.isEmpty() ? stepMessage : QStringLiteral("%1: %2").arg(name, stepMessage),
                   step->error());
    }

    float currentProgress() const
    {
        if (m_steps.isEmpty() || m_currentStepIndex < 0)
            return 0.0f;

        Task* step = currentStep();
        const float stepProgress = step ? step->progress() : 0.0f;
        return qBound(0.0f,
                      (static_cast<float>(m_currentStepIndex) + qBound(0.0f, stepProgress, 1.0f))
                          / static_cast<float>(m_steps.size()),
                      1.0f);
    }

    float completedProgress() const
    {
        if (m_steps.isEmpty() || m_currentStepIndex < 0)
            return 0.0f;

        return qBound(0.0f,
                      static_cast<float>(m_currentStepIndex + 1) / static_cast<float>(m_steps.size()),
                      1.0f);
    }

    QString stepDisplayName(const Step& step) const
    {
        if (!step.name.isEmpty())
            return step.name;

        if (step.task && !step.task->taskName().isEmpty())
            return step.task->taskName();

        if (step.task && !step.task->detail().isEmpty())
            return step.task->detail();

        return QString();
    }

    TaskManager m_stepManager;
    QVector<Step> m_steps;
    QStateMachine m_machine;
    QState* m_readyState = nullptr;
    QState* m_runningState = nullptr;
    QState* m_waitingState = nullptr;
    QState* m_succeededState = nullptr;
    QState* m_failedState = nullptr;
    QState* m_cancelledState = nullptr;
    int m_currentStepIndex = -1;
    int m_pendingStepIndex = -1;
    bool m_waitingForAdvance = false;
    bool m_stepOutcomePosted = false;
};

#endif // EARTH_TASK_TASKFLOW_H
