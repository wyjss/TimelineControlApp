#include <UICore/Task/TaskManager.h>

#include <UICore/Task/Task.h>

#include <QMetaObject>
#include <QMetaType>
#include <QPointer>
#include <QRunnable>
#include <QThread>

#include <atomic>
#include <functional>
#include <utility>

using namespace UICore;

struct TaskManager::DispatchState
{
    enum Phase {
        Queued,
        Started,
        CancelledBeforeStart,
        Finished,
    };

    std::atomic_int phase{Queued};
};

namespace
{
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

class ThreadRunnable : public QRunnable
{
public:
    explicit ThreadRunnable(std::function<void()> work)
        : m_work(std::move(work))
    {
    }

    void run() override
    {
        m_work();
    }

private:
    std::function<void()> m_work;
};
}

TaskManager::TaskManager(QObject* parent)
    : QObject(parent)
{
    qRegisterMetaType<QObjectList>("QObjectList");
    this->setAutoStart(true);
}

TaskManager::~TaskManager()
{
    m_shuttingDown = true;

    const QList<Task*> managedTasks = m_tasks;
    for (Task* task : managedTasks) {
        requestTaskCancellation(task);
    }

    m_threadPool.waitForDone();

    for (Task* task : managedTasks) {
        detachTask(task);
    }

    m_tasks.clear();
    m_scheduledTasks.clear();
    m_inFlightTasks.clear();
    m_cancelRequestedTasks.clear();
    m_pendingRemovalTasks.clear();
    m_dispatchStates.clear();
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
    if (!task
        || m_shuttingDown
        || QThread::currentThread() != thread()
        || task->thread() != thread()
        || isManagedTask(task)) {
        return false;
    }

    task->setParent(this);
    if (task->parent() != this) {
        return false;
    }

    attachTask(task);
    notifyTaskListChanged();
    tryAutoStart();
    return true;
}

bool TaskManager::unregisterTask(Task* task)
{
    if (QThread::currentThread() != thread() || !requestTaskRemoval(task)) {
        return false;
    }

    tryAutoStart();
    return true;
}

void TaskManager::clearTasks()
{
    if (QThread::currentThread() != thread() || m_tasks.isEmpty()) {
        return;
    }

    m_clearingTasks = true;

    const QList<Task*> managedTasks = m_tasks;
    for (Task* task : managedTasks) {
        requestTaskRemoval(task);
    }

    m_clearingTasks = false;
    tryAutoStart();
}

bool TaskManager::startTask(Task* task)
{
    if (QThread::currentThread() != thread()
        || !isManagedTask(task)
        || !canStartTask(task, scheduledTasks())) {
        return false;
    }

    if (invokeLifecycle(task, LifecycleAction::Start)) {
        return true;
    }

    return false;
}

bool TaskManager::cancelTask(Task* task)
{
    if (QThread::currentThread() != thread() || !isManagedTask(task)) {
        return false;
    }

    return requestTaskCancellation(task);
}

void TaskManager::onTaskDestroyed(QObject* object)
{
    removeTask(static_cast<Task*>(object), false, false);
    tryAutoStart();
}

void TaskManager::onTaskStateChanged()
{
    Task* task = qobject_cast<Task*>(sender());
    if (!isManagedTask(task)) {
        return;
    }

    emit taskStateChanged(task);
    updateTaskHistory(task);
    notifyTaskStatusChanged();

    if (task->finished()) {
        if (!taskHasPendingDispatch(task)) {
            m_cancelRequestedTasks.remove(task);
        }
    }

    if (task->phase() != Task::Ready && !taskHasPendingDispatch(task)) {
        m_scheduledTasks.remove(task);
    }

    if (m_pendingRemovalTasks.contains(task)
        && task->finished()
        && !taskHasPendingDispatch(task)) {
        removeTask(task);
    }

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

bool TaskManager::requestTaskRemoval(Task* task)
{
    if (!isManagedTask(task) || m_pendingRemovalTasks.contains(task)) {
        return false;
    }

    m_pendingRemovalTasks.insert(task);

    if (taskHasPendingDispatch(task) || task->running()) {
        requestTaskCancellation(task);

        if (taskHasPendingDispatch(task) || !task->finished()) {
            return true;
        }
    }

    removeTask(task);
    return true;
}

bool TaskManager::removeTask(Task* task, bool preserveFinishedHistory, bool deleteTask)
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
    m_scheduledTasks.remove(task);
    m_inFlightTasks.remove(task);
    m_cancelRequestedTasks.remove(task);
    m_pendingRemovalTasks.remove(task);

    const auto dispatchState = m_dispatchStates.take(task);
    if (dispatchState) {
        int expectedPhase = DispatchState::Queued;
        dispatchState->phase.compare_exchange_strong(expectedPhase, DispatchState::CancelledBeforeStart);
    }

    notifyTaskListChanged();

    if (deleteTask && task) {
        task->deleteLater();
    }

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
        && !m_scheduledTasks.contains(task)
        && !m_inFlightTasks.contains(task)
        && !m_pendingRemovalTasks.contains(task)
        && !hasSchedulingConflict(task, scheduledTasks);
}

bool TaskManager::invokeLifecycle(Task* task, LifecycleAction action)
{
    if (!task || !isManagedTask(task)) {
        return false;
    }

    if (action == LifecycleAction::Cancel) {
        task->cancel();
        return true;
    }

    if (task->dispatchHint() == Task::WorkerThread) {
        const auto state = std::make_shared<DispatchState>();
        m_dispatchStates.insert(task, state);
        m_scheduledTasks.insert(task);

        QPointer<TaskManager> manager(this);
        m_threadPool.start(new ThreadRunnable([manager, task, state]() {
            int expectedPhase = DispatchState::Queued;
            const bool shouldStart = state->phase.compare_exchange_strong(expectedPhase, DispatchState::Started);

            if (shouldStart && manager) {
                QMetaObject::invokeMethod(manager.data(), [manager, task, state]() {
                    if (manager) {
                        manager->markWorkerTaskStarted(task, state);
                    }
                }, Qt::QueuedConnection);
            }

            if (shouldStart) {
                task->start();
            }

            state->phase.store(DispatchState::Finished);

            if (manager) {
                QMetaObject::invokeMethod(manager.data(), [manager, task, state]() {
                    if (manager) {
                        manager->finishWorkerTask(task, state);
                    }
                }, Qt::QueuedConnection);
            }
        }));

        return true;
    }

    m_scheduledTasks.insert(task);
    m_inFlightTasks.insert(task);
    task->start();
    m_inFlightTasks.remove(task);

    if (task->phase() != Task::Ready) {
        m_scheduledTasks.remove(task);
    }

    if (m_pendingRemovalTasks.contains(task)) {
        if (task->finished()) {
            removeTask(task);
        }
    }

    return true;
}

bool TaskManager::requestTaskCancellation(Task* task)
{
    if (!isManagedTask(task)
        || m_cancelRequestedTasks.contains(task)
        || task->finished()
        || (!task->running() && !taskHasPendingDispatch(task))) {
        return false;
    }

    m_cancelRequestedTasks.insert(task);

    const auto state = m_dispatchStates.value(task);
    if (state) {
        int expectedPhase = DispatchState::Queued;
        if (state->phase.compare_exchange_strong(expectedPhase, DispatchState::CancelledBeforeStart)) {
            task->applyState(Task::Cancelled, task->progress(), task->message(), task->error());
            return true;
        }
    }

    return invokeLifecycle(task, LifecycleAction::Cancel);
}

bool TaskManager::taskHasPendingDispatch(Task* task) const
{
    return m_dispatchStates.contains(task) || m_inFlightTasks.contains(task);
}

void TaskManager::markWorkerTaskStarted(Task* task, const std::shared_ptr<DispatchState>& state)
{
    if (!isManagedTask(task) || m_dispatchStates.value(task) != state) {
        return;
    }

    m_inFlightTasks.insert(task);
    notifyTaskStatusChanged();
}

void TaskManager::finishWorkerTask(Task* task, const std::shared_ptr<DispatchState>& state)
{
    if (!isManagedTask(task) || m_dispatchStates.value(task) != state) {
        return;
    }

    m_inFlightTasks.remove(task);
    m_dispatchStates.remove(task);

    if (task->phase() != Task::Ready) {
        m_scheduledTasks.remove(task);
    }
    if (m_pendingRemovalTasks.contains(task)
        && m_cancelRequestedTasks.contains(task)
        && !task->finished()) {
        task->applyState(Task::Cancelled, task->progress(), task->message(), task->error());
    }
    if (task->finished()) {
        m_cancelRequestedTasks.remove(task);
    }
    notifyTaskStatusChanged();

    if (m_pendingRemovalTasks.contains(task)) {
        removeTask(task);
    }

    tryAutoStart();
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

QList<Task*> TaskManager::scheduledTasks() const
{
    QList<Task*> scheduled;
    scheduled.reserve(m_tasks.size());

    for (Task* task : m_tasks) {
        if (task->running()
            || m_scheduledTasks.contains(task)
            || m_inFlightTasks.contains(task)) {
            scheduled.append(task);
        }
    }

    return scheduled;
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
    QList<Task*> currentScheduledTasks = scheduledTasks();
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
    if (!m_autoStart || m_clearingTasks || m_shuttingDown) {
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
            if (!canStartTask(task, scheduledTasks())) {
                continue;
            }

            if (!invokeLifecycle(task, LifecycleAction::Start)) {
                continue;
            }
        }
    } while (m_autoStartPending);

    m_autoStarting = false;
}
