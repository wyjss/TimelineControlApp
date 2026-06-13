#ifndef EARTH_TASK_TASK_H
#define EARTH_TASK_TASK_H

#include <functional>

#include <QObject>
#include <QMutex>
#include <QString>

class TaskManager;

//! 任务状态快照，供实时任务与历史记录共用字段定义。
struct TaskInfo
{
    enum ExecutionMode {
        Serial,
        Parallel,
    };

    enum DispatchHint {
        Direct,
        WorkerThread,
    };

    enum Phase {
        Ready,
        Running,
        Succeeded,
        Failed,
        Cancelled,
    };

    bool running() const;
    bool finished() const;

    QString taskId;
    QString taskName;
    QString detail;
    ExecutionMode executionMode = Serial;
    QString concurrencyKey;
    DispatchHint dispatchHint = Direct;
    Phase phase = Ready;
    float progress = 0.0f;
    QString message;
    QString error;
    bool archived = false;
};

class Task : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString taskId READ taskId CONSTANT FINAL)
    Q_PROPERTY(QString taskName READ taskName CONSTANT FINAL)
    Q_PROPERTY(QString detail READ detail CONSTANT FINAL)
    Q_PROPERTY(ExecutionMode executionMode READ executionMode CONSTANT FINAL)
    Q_PROPERTY(QString concurrencyKey READ concurrencyKey CONSTANT FINAL)
    Q_PROPERTY(DispatchHint dispatchHint READ dispatchHint CONSTANT FINAL)
    Q_PROPERTY(Phase phase READ phase NOTIFY stateChanged FINAL)
    Q_PROPERTY(float progress READ progress NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString message READ message NOTIFY stateChanged FINAL)
    Q_PROPERTY(QString error READ error NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool running READ running NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool finished READ finished NOTIFY stateChanged FINAL)
    Q_PROPERTY(bool archived READ archived NOTIFY stateChanged FINAL)

public:
    enum ExecutionMode {
        Serial = TaskInfo::Serial,
        Parallel = TaskInfo::Parallel,
    };
    Q_ENUM(ExecutionMode)

    enum DispatchHint {
        Direct = TaskInfo::Direct,
        WorkerThread = TaskInfo::WorkerThread,
    };
    Q_ENUM(DispatchHint)

    enum Phase {
        Ready = TaskInfo::Ready,
        Running = TaskInfo::Running,
        Succeeded = TaskInfo::Succeeded,
        Failed = TaskInfo::Failed,
        Cancelled = TaskInfo::Cancelled,
    };
    Q_ENUM(Phase)

    explicit Task(const QString& taskName,
                  ExecutionMode executionMode = Serial,
                  const QString& concurrencyKey = QString(),
                  DispatchHint dispatchHint = Direct,
                  const QString& detail = QString(),
                  QObject* parent = nullptr);
    const QString& taskId() const;
    const QString& taskName() const;
    const QString& detail() const;
    ExecutionMode executionMode() const;
    const QString& concurrencyKey() const;
    DispatchHint dispatchHint() const;

    Phase phase() const;
    float progress() const;
    QString message() const;
    QString error() const;

    bool running() const;
    bool finished() const;
    bool archived() const;
    TaskInfo info() const;

public:
    // Dispatches work to the global thread pool for WorkerThread tasks.
    static bool runInThread(const std::function<void()>& work);

protected slots:
    // Lifecycle entrypoints are owned by TaskManager scheduling.
    // WorkerThread tasks may run start/cancel on thread-pool threads.
    virtual void start() = 0;
    virtual void cancel() = 0;

signals:
    void stateChanged();

protected:
    explicit Task(const TaskInfo& info, QObject* parent = nullptr);

    void applyState(Phase phase,
                    float progress,
                    const QString& message = QString(),
                    const QString& error = QString());
    void setPhase(Phase phase);
    void setProgress(float value);
    void setMessage(const QString& value);
    void setError(const QString& value);
    void clearError();

private slots:
    void emitStateChanged();
private:
    friend class TaskManager;

    TaskInfo m_info;

    QAtomicInt m_taskChanged = 0;
    mutable QMutex m_mutex;
};

#endif // EARTH_TASK_TASK_H
