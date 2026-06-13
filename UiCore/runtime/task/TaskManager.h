#ifndef EARTH_TASK_TASKMANAGER_H
#define EARTH_TASK_TASKMANAGER_H

#include <QList>
#include <QObject>

#include "Task.h"

class TaskManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool autoStart READ autoStart WRITE setAutoStart NOTIFY autoStartChanged FINAL)
    Q_PROPERTY(QObjectList tasks READ tasks NOTIFY taskListChanged FINAL)
    Q_PROPERTY(int taskCount READ taskCount NOTIFY taskListChanged FINAL)
    Q_PROPERTY(int activeTaskCount READ activeTaskCount NOTIFY taskStatusChanged FINAL)

public:
    explicit TaskManager(QObject* parent = nullptr);

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
    enum class LifecycleAction {
        Start,
        Cancel,
    };

    bool isManagedTask(Task* task) const;
    void attachTask(Task* task);
    void detachTask(Task* task);
    bool removeTask(Task* task, bool preserveFinishedHistory = true);

    void notifyTaskListChanged();
    void notifyTaskStatusChanged();

    bool canStartTask(Task* task, const QList<Task*>& scheduledTasks) const;
    bool hasSchedulingConflict(Task* task, const QList<Task*>& scheduledTasks) const;
    bool invokeLifecycle(Task* task, LifecycleAction action);
    void updateTaskHistory(Task* task);

    QList<Task*> runningTasks() const;
    QList<Task*> readyTasks() const;
    QList<Task*> collectStartCandidates() const;

    int displayTaskCount() const;
    Task* displayTaskAt(int index) const;
    bool hasManagedTaskId(const QString& taskId) const;

    void tryAutoStart();

    QList<Task*> m_tasks;
    QList<Task*> m_historyTasks;
    bool m_autoStart = true;
    bool m_autoStarting = false;
    bool m_autoStartPending = false;
};

#endif // EARTH_TASK_TASKMANAGER_H
