#include "Task.h"
#include <QtGlobal>
#include <QRunnable>
#include <QThreadPool>
#include <QMutexLocker>
#include <QTimer>

#include <atomic>

namespace
{
    std::atomic_ullong g_nextTaskId{1};

    QString createTaskId()
    {
        return QStringLiteral("task-%1").arg(g_nextTaskId.fetch_add(1));
    }

    class ThreadRunnable : public QRunnable
    {
    public:
        ThreadRunnable(std::function<void()> work)
            : m_work(work){}
        virtual void run() {
            m_work();
        }

        std::function<void()> m_work;
    };
}

Task::Task(const QString& taskName,
           ExecutionMode executionMode,
           const QString& concurrencyKey,
           DispatchHint dispatchHint,
           const QString& detail,
           QObject* parent)
    : QObject(parent)
{
    m_info.taskId = createTaskId();
    m_info.taskName = taskName;
    m_info.detail = detail;
    m_info.executionMode = static_cast<TaskInfo::ExecutionMode>(executionMode);
    m_info.concurrencyKey = concurrencyKey;
    m_info.dispatchHint = static_cast<TaskInfo::DispatchHint>(dispatchHint);
}

Task::Task(const TaskInfo& info, QObject* parent)
    : QObject(parent)
    , m_info(info)
{
    if (m_info.taskId.isEmpty()) {
        m_info.taskId = createTaskId();
    }
}

bool TaskInfo::running() const
{
    return phase == Running;
}

bool TaskInfo::finished() const
{
    return phase == Succeeded || phase == Failed || phase == Cancelled;
}

const QString& Task::taskId() const
{
    return m_info.taskId;
}

const QString& Task::taskName() const
{
    return m_info.taskName;
}

const QString& Task::detail() const
{
    return m_info.detail;
}

Task::ExecutionMode Task::executionMode() const
{
    return static_cast<ExecutionMode>(m_info.executionMode);
}

const QString& Task::concurrencyKey() const
{
    return m_info.concurrencyKey;
}

Task::DispatchHint Task::dispatchHint() const
{
    return static_cast<DispatchHint>(m_info.dispatchHint);
}

bool Task::runInThread(const std::function<void()>& work)
{
    QThreadPool::globalInstance()->start(new ThreadRunnable(work));
    return true;
}

Task::Phase Task::phase() const
{
    QMutexLocker locker(&m_mutex);
    return static_cast<Phase>(m_info.phase);
}

float Task::progress() const
{
    QMutexLocker locker(&m_mutex);
    return m_info.progress;
}

QString Task::message() const
{
    QMutexLocker locker(&m_mutex);
    return m_info.message;
}

QString Task::error() const
{
    QMutexLocker locker(&m_mutex);
    return m_info.error;
}

bool Task::running() const
{
    QMutexLocker locker(&m_mutex);
    return m_info.running();
}

bool Task::finished() const
{
    QMutexLocker locker(&m_mutex);
    return m_info.finished();
}

bool Task::archived() const
{
    QMutexLocker locker(&m_mutex);
    return m_info.archived;
}

TaskInfo Task::info() const
{
    QMutexLocker locker(&m_mutex);
    return m_info;
}

void Task::applyState(Phase phase,
                      float progress,
                      const QString& message,
                      const QString& error)
{
    bool changed = false;
    {
        QMutexLocker locker(&m_mutex);

        const TaskInfo::Phase nextPhase = static_cast<TaskInfo::Phase>(phase);
        if (m_info.phase != nextPhase) {
            m_info.phase = nextPhase;
            changed = true;
        }

        const float clampedProgress = qBound(0.0f, progress, 1.0f);
        if (!qFuzzyCompare(m_info.progress + 1.0f, clampedProgress + 1.0f)) {
            m_info.progress = clampedProgress;
            changed = true;
        }

        if (m_info.message != message) {
            m_info.message = message;
            changed = true;
        }

        if (m_info.error != error) {
            m_info.error = error;
            changed = true;
        }
    }

    if (changed && m_taskChanged.testAndSetOrdered(0, 1)) {
        QTimer::singleShot(33, this, &Task::emitStateChanged);
        //LOG_INFO("[" << m_info.taskName << "]" << this->phase() << this->message() << this->progress());
    }
}

void Task::setPhase(Phase phase)
{
    applyState(phase, progress(), message(), error());
}

void Task::setProgress(float value)
{
    applyState(phase(), value, message(), error());
}

void Task::setMessage(const QString& value)
{
    applyState(phase(), progress(), value, error());
}

void Task::setError(const QString& value)
{
    applyState(phase(), progress(), message(), value);
}

void Task::clearError()
{
    if (error().isEmpty())
        return;

    applyState(phase(), progress(), message(), QString());
}

void Task::emitStateChanged()
{
    if (m_taskChanged.testAndSetOrdered(1, 0)) {
        emit stateChanged();
    }
}
