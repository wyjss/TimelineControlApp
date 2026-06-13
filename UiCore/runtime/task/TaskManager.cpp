#include "TaskManager.h"

#include "Task.h"

#include <QMetaType>

namespace
{
void ensureTaskManagerMetaTypes()
{
    qRegisterMetaType<QObjectList>("QObjectList");
}

class TaskHistoryItem : public Task
{
public:
    explicit TaskHistoryItem(const TaskInfo& info, QObject* parent = nullptr)
        : Task(info, parent)
    {
    }

    void updateInfo(const TaskInfo& info)
    {
        applyState(static_cast<Phase>(info.phase), info.progress, info.message, info.error);
    }

protected:
    void start() override {}
    void cancel() override {}
};
}

TaskManager::TaskManager(QObject* parent)
    : QObject(parent)
{
    ensureTaskManagerMetaTypes();
    this->setAutoStart(true);
}

QObjectList TaskManager::tasks() const
{
    QObjectList values;
    const int count = displayTaskCount();
    values.reserve(count);

    for (int index = 0; index < count; ++index) {
        Task* task = displayTaskAt(index);
        if (task) {
            values.append(task);
        }
    }

    return values;
}

int TaskManager::activeTaskCount() const
{
    int count = 0;
    for (Task* task : m_tasks) {
        if (!task->finished()) {
            ++count;
        }
    }

    return count;
}

QList<Task*> TaskManager::taskList() const
{
    return m_tasks;
}

Task* TaskManager::taskAt(int index) const
{
    if (index < 0 || index >= m_tasks.size()) {
        return nullptr;
    }

    return m_tasks.at(index);
}

bool TaskManager::autoStart() const
{
    return m_autoStart;
}

int TaskManager::taskCount() const
{
    return displayTaskCount();
}

bool TaskManager::contains(Task* task) const
{
    return isManagedTask(task);
}

int TaskManager::indexOf(Task* task) const
{
    return m_tasks.indexOf(task);
}

void TaskManager::setAutoStart(bool value)
{
    if (m_autoStart == value) {
        return;
    }

    m_autoStart = value;
    emit autoStartChanged();

    if (m_autoStart) {
        tryAutoStart();
    }
}

bool TaskManager::registerTask(Task* task)
{
    if (!task || isManagedTask(task)) {
        return false;
    }

    attachTask(task);
    notifyTaskListChanged();
    tryAutoStart();
    return true;
}

bool TaskManager::unregisterTask(Task* task)
{
    if (!removeTask(task)) {
        return false;
    }

    tryAutoStart();
    return true;
}

void TaskManager::clearTasks()
{
    if (m_tasks.isEmpty()) {
        return;
    }

    for (Task* task : m_tasks) {
        detachTask(task);
    }

    m_tasks.clear();

    notifyTaskListChanged();
}

bool TaskManager::startTask(Task* task)
{
    if (!isManagedTask(task) || !canStartTask(task, runningTasks())) {
        return false;
    }

    if (invokeLifecycle(task, LifecycleAction::Start)) {
        return true;
    }

    return false;
}

bool TaskManager::cancelTask(Task* task)
{
    if (!isManagedTask(task) || !task->running()) {
        return false;
    }

    return invokeLifecycle(task, LifecycleAction::Cancel);
}

void TaskManager::onTaskDestroyed(QObject* object)
{
    removeTask(static_cast<Task*>(object), false);
    tryAutoStart();
}

void TaskManager::onTaskStateChanged()
{
    Task* task = qobject_cast<Task*>(sender());
    emit taskStateChanged(task);
    updateTaskHistory(task);
    notifyTaskStatusChanged();
    tryAutoStart();
}

bool TaskManager::isManagedTask(Task* task) const
{
    return task && m_tasks.contains(task);
}

void TaskManager::attachTask(Task* task)
{
    m_tasks.append(task);
    connect(task, &QObject::destroyed, this, &TaskManager::onTaskDestroyed);
    connect(task, &Task::stateChanged, this, &TaskManager::onTaskStateChanged);
}

void TaskManager::detachTask(Task* task)
{
    if (!task) {
        return;
    }

    disconnect(task, nullptr, this, nullptr);
}

bool TaskManager::removeTask(Task* task, bool preserveFinishedHistory)
{
    const int index = indexOf(task);
    if (index < 0) {
        return false;
    }

    if (preserveFinishedHistory) {
        updateTaskHistory(task);
    }

    emit taskAboutToBeRemoved(task);
    detachTask(task);
    m_tasks.removeAt(index);
    notifyTaskListChanged();
    return true;
}

void TaskManager::notifyTaskListChanged()
{
    emit taskListChanged();
    notifyTaskStatusChanged();
}

void TaskManager::notifyTaskStatusChanged()
{
    emit taskStatusChanged();
}

bool TaskManager::canStartTask(Task* task, const QList<Task*>& scheduledTasks) const
{
    return task
        && isManagedTask(task)
        && task->phase() == Task::Ready
        && !hasSchedulingConflict(task, scheduledTasks);
}

bool TaskManager::invokeLifecycle(Task* task, LifecycleAction action)
{
    if (!task) {
        return false;
    }

    auto invoke = [task, action]() {
        if (action == LifecycleAction::Start) {
            task->start();
        } else {
            task->cancel();
        }
    };

    if (task->dispatchHint() == Task::WorkerThread) {
        return Task::runInThread(invoke);
    }

    invoke();

    return true;
}

void TaskManager::updateTaskHistory(Task* task)
{
    if (!task || !task->finished()) {
        return;
    }

    TaskInfo info = task->info();
    info.archived = true;

    for (Task* historyTask : m_historyTasks) {
        if (!historyTask || historyTask->taskId() != info.taskId) {
            continue;
        }

        auto* historyItem = dynamic_cast<TaskHistoryItem*>(historyTask);
        if (historyItem) {
            historyItem->updateInfo(info);
        }
        return;
    }

    m_historyTasks.prepend(new TaskHistoryItem(info, this));

    while (m_historyTasks.size() > 128) {
        Task* removedTask = m_historyTasks.takeLast();
        if (removedTask) {
            removedTask->deleteLater();
        }
    }
}

QList<Task*> TaskManager::runningTasks() const
{
    QList<Task*> running;
    running.reserve(m_tasks.size());
    for (Task* task : m_tasks) {
        if (task->running()) {
            running.append(task);
        }
    }

    return running;
}

QList<Task*> TaskManager::readyTasks() const
{
    QList<Task*> ready;
    ready.reserve(m_tasks.size());

    for (Task* task : m_tasks) {
        if (task->phase() == Task::Ready) {
            ready.append(task);
        }
    }

    return ready;
}

QList<Task*> TaskManager::collectStartCandidates() const
{
    const QList<Task*> orderedReadyTasks = readyTasks();
    QList<Task*> currentScheduledTasks = runningTasks();
    QList<Task*> candidates;
    candidates.reserve(orderedReadyTasks.size());

    for (Task* task : orderedReadyTasks) {
        if (!canStartTask(task, currentScheduledTasks)) {
            continue;
        }

        candidates.append(task);
        currentScheduledTasks.append(task);
    }

    return candidates;
}

bool TaskManager::hasSchedulingConflict(Task* task, const QList<Task*>& scheduledTasks) const
{
    if (!task) {
        return true;
    }

    for (Task* scheduledTask : scheduledTasks) {
        if (!scheduledTask || scheduledTask == task) {
            continue;
        }

        if (task->executionMode() == Task::Serial || scheduledTask->executionMode() == Task::Serial) {
            return true;
        }

        if (!task->concurrencyKey().isEmpty() && task->concurrencyKey() == scheduledTask->concurrencyKey()) {
            return true;
        }
    }

    return false;
}

int TaskManager::displayTaskCount() const
{
    int count = m_tasks.size();
    for (Task* historyTask : m_historyTasks) {
        if (!historyTask || hasManagedTaskId(historyTask->taskId())) {
            continue;
        }

        ++count;
    }

    return count;
}

Task* TaskManager::displayTaskAt(int index) const
{
    if (index < 0) {
        return nullptr;
    }

    if (index < m_tasks.size()) {
        return m_tasks.at(m_tasks.size() - 1 - index);
    }

    int historyIndex = index - m_tasks.size();
    for (Task* historyTask : m_historyTasks) {
        if (!historyTask || hasManagedTaskId(historyTask->taskId())) {
            continue;
        }

        if (historyIndex == 0) {
            return historyTask;
        }

        --historyIndex;
    }

    return nullptr;
}

bool TaskManager::hasManagedTaskId(const QString& taskId) const
{
    if (taskId.isEmpty()) {
        return false;
    }

    for (Task* task : m_tasks) {
        if (task && task->taskId() == taskId) {
            return true;
        }
    }

    return false;
}

void TaskManager::tryAutoStart()
{
    if (!m_autoStart) {
        return;
    }

    if (m_autoStarting) {
        m_autoStartPending = true;
        return;
    }

    m_autoStarting = true;

    do {
        m_autoStartPending = false;

        const QList<Task*> candidates = collectStartCandidates();
        if (candidates.isEmpty()) {
            continue;
        }

        for (Task* task : candidates) {
            if (!canStartTask(task, runningTasks())) {
                continue;
            }

            if (!invokeLifecycle(task, LifecycleAction::Start)) {
                continue;
            }
        }
    } while (m_autoStartPending);

    m_autoStarting = false;
}
