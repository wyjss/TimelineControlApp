#ifndef UICORE_TASK_TASKMANAGER_H
#define UICORE_TASK_TASKMANAGER_H

#include <memory>

#include <QHash>
#include <QList>
#include <QObject>
#include <QSet>
#include <QThreadPool>

#include <UICore/Task/Task.h>

namespace UICore {

class TaskManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool autoStart READ autoStart WRITE setAutoStart NOTIFY autoStartChanged FINAL)
    Q_PROPERTY(QObjectList tasks READ tasks NOTIFY taskListChanged FINAL)
    Q_PROPERTY(int taskCount READ taskCount NOTIFY taskListChanged FINAL)
    Q_PROPERTY(int activeTaskCount READ activeTaskCount NOTIFY taskStatusChanged FINAL)

public:
    explicit TaskManager(QObject* parent = nullptr);
    ~TaskManager() override;

    QObjectList tasks() const;
    int activeTaskCount() const;

    QList<Task*> taskList() const;
    Task* taskAt(int index) const;

    bool autoStart() const;
    int taskCount() const;

    bool contains(Task* task) const;
    int indexOf(Task* task) const;

public slots:
    void setAutoStart(bool value);
    // Registered tasks must be heap allocated in the manager thread. Ownership is transferred.
    bool registerTask(Task* task);
    bool unregisterTask(Task* task);
    void clearTasks();

    bool startTask(Task* task);
    bool cancelTask(Task* task);

signals:
    void autoStartChanged();
    void taskAboutToBeRemoved(Task* task);
    void taskStateChanged(Task* task);
    void taskListChanged();
    void taskStatusChanged();

private slots:
    void onTaskDestroyed(QObject* object);
    void onTaskStateChanged();

private:
    struct DispatchState;

    enum class LifecycleAction {
        Start,
        Cancel,
    };

    bool isManagedTask(Task* task) const;
    void attachTask(Task* task);
    void detachTask(Task* task);
    bool requestTaskRemoval(Task* task);
    bool removeTask(Task* task, bool preserveFinishedHistory = true, bool deleteTask = true);

    void notifyTaskListChanged();
    void notifyTaskStatusChanged();

    bool canStartTask(Task* task, const QList<Task*>& scheduledTasks) const;
    bool hasSchedulingConflict(Task* task, const QList<Task*>& scheduledTasks) const;
    bool invokeLifecycle(Task* task, LifecycleAction action);
    bool requestTaskCancellation(Task* task);
    bool taskHasPendingDispatch(Task* task) const;
    void markWorkerTaskStarted(Task* task, const std::shared_ptr<DispatchState>& state);
    void finishWorkerTask(Task* task, const std::shared_ptr<DispatchState>& state);
    void updateTaskHistory(Task* task);

    QList<Task*> scheduledTasks() const;
    QList<Task*> readyTasks() const;
    QList<Task*> collectStartCandidates() const;

    int displayTaskCount() const;
    Task* displayTaskAt(int index) const;
    bool hasManagedTaskId(const QString& taskId) const;

    void tryAutoStart();

    QList<Task*> m_tasks;
    QList<Task*> m_historyTasks;
    QSet<Task*> m_scheduledTasks;
    QSet<Task*> m_inFlightTasks;
    QSet<Task*> m_cancelRequestedTasks;
    QSet<Task*> m_pendingRemovalTasks;
    QHash<Task*, std::shared_ptr<DispatchState>> m_dispatchStates;
    QThreadPool m_threadPool;
    bool m_autoStart = true;
    bool m_autoStarting = false;
    bool m_autoStartPending = false;
    bool m_clearingTasks = false;
    bool m_shuttingDown = false;
};

} // namespace UICore

#endif // UICORE_TASK_TASKMANAGER_H
