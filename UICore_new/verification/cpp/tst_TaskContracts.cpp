#include <UICore/Task/Task.h>
#include <UICore/Task/TaskManager.h>

#include <QCoreApplication>
#include <QElapsedTimer>
#include <QEvent>
#include <QPointer>
#include <QSemaphore>
#include <QThread>
#include <QtTest>

#include <atomic>
#include <memory>

using namespace UICore;

namespace
{
struct TaskProbe
{
    std::atomic_int startCount{0};
    std::atomic_int cancelCount{0};
    std::atomic_int destructionCount{0};
    std::atomic_bool cancelled{false};
    std::atomic<QThread*> startThread{nullptr};
    std::atomic<QThread*> cancelThread{nullptr};
    QSemaphore entered;
    QSemaphore release;
    bool blockStart = false;
    bool publishRunning = true;
    bool publishCancelled = true;
    bool publishWorkerCancelled = true;
};

class ProbeTask : public Task
{
public:
    explicit ProbeTask(const std::shared_ptr<TaskProbe>& probe,
                       ExecutionMode executionMode = Parallel,
                       const QString& concurrencyKey = QString(),
                       DispatchHint dispatchHint = WorkerThread)
        : Task(QStringLiteral("Probe"), executionMode, concurrencyKey, dispatchHint)
        , m_probe(probe)
    {
    }

    ~ProbeTask() override
    {
        ++m_probe->destructionCount;
    }

protected:
    void start() override
    {
        ++m_probe->startCount;
        m_probe->startThread.store(QThread::currentThread());

        if (m_probe->publishRunning) {
            applyState(Running, 0.0f);
        }

        m_probe->entered.release();
        if (m_probe->blockStart) {
            m_probe->release.acquire();
        }

        if (m_probe->cancelled.load()) {
            if (m_probe->publishWorkerCancelled) {
                applyState(Cancelled, progress());
            }
        } else {
            applyState(Succeeded, 1.0f);
        }
    }

    void cancel() override
    {
        ++m_probe->cancelCount;
        m_probe->cancelThread.store(QThread::currentThread());
        m_probe->cancelled.store(true);
        if (m_probe->publishCancelled) {
            applyState(Cancelled, progress());
        }
        m_probe->release.release();
    }

private:
    std::shared_ptr<TaskProbe> m_probe;
};

void flushDeferredDeletes()
{
    QCoreApplication::sendPostedEvents(nullptr, QEvent::DeferredDelete);
    QCoreApplication::processEvents();
}
}

class TaskContractsTest : public QObject
{
    Q_OBJECT

private slots:
    void registrationTransfersOwnership();
    void registrationRejectsAnotherThread();
    void duplicateStartIsRejectedBeforeStateChanges();
    void schedulingHonorsSerialAndConcurrencyKey();
    void unregisterReadyTaskSkipsStart();
    void unregisterQueuedWorkerTaskSkipsStart();
    void unregisterRunningTaskWaitsForWorker();
    void repeatedCancellationIsRejected();
    void clearTasksSchedulesReentrantRegistration();
    void destructionCancelsAndWaitsForWorker();
};

void TaskContractsTest::registrationTransfersOwnership()
{
    TaskManager manager;
    manager.setAutoStart(false);

    const auto probe = std::make_shared<TaskProbe>();
    QPointer<ProbeTask> task = new ProbeTask(probe);

    QVERIFY(manager.registerTask(task));
    QCOMPARE(task->parent(), &manager);
    QVERIFY(!manager.registerTask(task));
    QVERIFY(manager.unregisterTask(task));
    QVERIFY(manager.taskList().isEmpty());

    flushDeferredDeletes();
    QVERIFY(task.isNull());
    QCOMPARE(probe->destructionCount.load(), 1);
}

void TaskContractsTest::registrationRejectsAnotherThread()
{
    TaskManager manager;
    manager.setAutoStart(false);

    QThread workerThread;
    const auto probe = std::make_shared<TaskProbe>();
    QPointer<ProbeTask> task = new ProbeTask(probe);
    task->moveToThread(&workerThread);
    workerThread.start();

    QVERIFY(!manager.registerTask(task));
    QVERIFY(task->parent() == nullptr);

    QMetaObject::invokeMethod(task, "deleteLater", Qt::QueuedConnection);
    QTRY_VERIFY(task.isNull());
    workerThread.quit();
    QVERIFY(workerThread.wait(5000));
}

void TaskContractsTest::duplicateStartIsRejectedBeforeStateChanges()
{
    TaskManager manager;
    manager.setAutoStart(false);

    const auto probe = std::make_shared<TaskProbe>();
    probe->blockStart = true;
    probe->publishRunning = false;
    auto* task = new ProbeTask(probe);

    QVERIFY(manager.registerTask(task));
    QVERIFY(manager.startTask(task));
    QVERIFY(!manager.startTask(task));
    QVERIFY(probe->entered.tryAcquire(1, 5000));
    QVERIFY(!manager.startTask(task));

    probe->release.release();
    QTRY_VERIFY(task->finished());
    QCOMPARE(probe->startCount.load(), 1);
}

void TaskContractsTest::schedulingHonorsSerialAndConcurrencyKey()
{
    TaskManager manager;
    manager.setAutoStart(false);

    const auto firstProbe = std::make_shared<TaskProbe>();
    firstProbe->blockStart = true;
    auto* first = new ProbeTask(firstProbe, Task::Parallel, QStringLiteral("shared"));

    const auto sameKeyProbe = std::make_shared<TaskProbe>();
    auto* sameKey = new ProbeTask(sameKeyProbe, Task::Parallel, QStringLiteral("shared"));

    const auto serialProbe = std::make_shared<TaskProbe>();
    auto* serial = new ProbeTask(serialProbe, Task::Serial, QStringLiteral("serial"));

    QVERIFY(manager.registerTask(first));
    QVERIFY(manager.registerTask(sameKey));
    QVERIFY(manager.registerTask(serial));
    QVERIFY(manager.startTask(first));
    QVERIFY(firstProbe->entered.tryAcquire(1, 5000));
    QVERIFY(!manager.startTask(sameKey));
    QVERIFY(!manager.startTask(serial));

    firstProbe->release.release();
    QTRY_VERIFY(first->finished());

    bool sameKeyStarted = false;
    QElapsedTimer waitTimer;
    waitTimer.start();
    do {
        QCoreApplication::processEvents();
        sameKeyStarted = manager.startTask(sameKey);
        if (!sameKeyStarted)
            QTest::qWait(10);
    } while (!sameKeyStarted && waitTimer.elapsed() < 5000);
    QVERIFY(sameKeyStarted);
    QTRY_VERIFY(sameKey->finished());

    bool serialStarted = false;
    waitTimer.restart();
    do {
        QCoreApplication::processEvents();
        serialStarted = manager.startTask(serial);
        if (!serialStarted)
            QTest::qWait(10);
    } while (!serialStarted && waitTimer.elapsed() < 5000);
    QVERIFY(serialStarted);
    QTRY_VERIFY(serial->finished());
}

void TaskContractsTest::unregisterReadyTaskSkipsStart()
{
    TaskManager manager;
    manager.setAutoStart(false);

    const auto probe = std::make_shared<TaskProbe>();
    QPointer<ProbeTask> task = new ProbeTask(probe);

    QVERIFY(manager.registerTask(task));
    QVERIFY(manager.unregisterTask(task));
    QVERIFY(!manager.unregisterTask(task));
    flushDeferredDeletes();

    QVERIFY(task.isNull());
    QCOMPARE(probe->startCount.load(), 0);
    QCOMPARE(probe->cancelCount.load(), 0);
}

void TaskContractsTest::unregisterQueuedWorkerTaskSkipsStart()
{
    TaskManager manager;
    manager.setAutoStart(false);

    QList<std::shared_ptr<TaskProbe>> blockingProbes;
    const int workerCount = qMax(1, QThread::idealThreadCount());
    blockingProbes.reserve(workerCount);
    for (int index = 0; index < workerCount; ++index) {
        const auto probe = std::make_shared<TaskProbe>();
        probe->blockStart = true;
        auto* task = new ProbeTask(probe);
        blockingProbes.append(probe);
        QVERIFY(manager.registerTask(task));
        QVERIFY(manager.startTask(task));
    }

    for (const auto& probe : blockingProbes) {
        QVERIFY(probe->entered.tryAcquire(1, 5000));
    }

    const auto queuedProbe = std::make_shared<TaskProbe>();
    QPointer<ProbeTask> queuedTask = new ProbeTask(queuedProbe);
    QVERIFY(manager.registerTask(queuedTask));
    QVERIFY(manager.startTask(queuedTask));
    QVERIFY(manager.unregisterTask(queuedTask));

    for (const auto& probe : blockingProbes) {
        probe->release.release();
    }

    QTRY_VERIFY(queuedTask.isNull());
    QCOMPARE(queuedProbe->startCount.load(), 0);
    QCOMPARE(queuedProbe->cancelCount.load(), 0);
}

void TaskContractsTest::unregisterRunningTaskWaitsForWorker()
{
    TaskManager manager;
    manager.setAutoStart(false);

    const auto probe = std::make_shared<TaskProbe>();
    probe->blockStart = true;
    probe->publishCancelled = false;
    probe->publishWorkerCancelled = false;
    QPointer<ProbeTask> task = new ProbeTask(probe);

    QVERIFY(manager.registerTask(task));
    QVERIFY(manager.startTask(task));
    QVERIFY(probe->entered.tryAcquire(1, 5000));
    QVERIFY(manager.unregisterTask(task));
    QVERIFY(manager.contains(task));
    QCOMPARE(probe->cancelCount.load(), 1);
    QCOMPARE(probe->cancelThread.load(), QThread::currentThread());

    QTRY_VERIFY(manager.taskList().isEmpty());
    QCOMPARE(manager.taskCount(), 1);
    auto* historyTask = qobject_cast<Task*>(manager.tasks().first());
    QVERIFY(historyTask);
    QCOMPARE(historyTask->phase(), Task::Cancelled);
    QVERIFY(historyTask->archived());
    flushDeferredDeletes();
    QVERIFY(task.isNull());
    QCOMPARE(probe->destructionCount.load(), 1);
}

void TaskContractsTest::repeatedCancellationIsRejected()
{
    TaskManager manager;
    manager.setAutoStart(false);

    const auto probe = std::make_shared<TaskProbe>();
    probe->blockStart = true;
    auto* task = new ProbeTask(probe);

    QVERIFY(manager.registerTask(task));
    QVERIFY(manager.startTask(task));
    QVERIFY(probe->entered.tryAcquire(1, 5000));
    QVERIFY(manager.cancelTask(task));
    QVERIFY(!manager.cancelTask(task));
    QCOMPARE(probe->cancelCount.load(), 1);
    QCOMPARE(probe->cancelThread.load(), QThread::currentThread());
    QTRY_VERIFY(task->finished());
}

void TaskContractsTest::clearTasksSchedulesReentrantRegistration()
{
    TaskManager manager;
    manager.setAutoStart(false);

    const auto removedProbe = std::make_shared<TaskProbe>();
    auto* removedTask = new ProbeTask(removedProbe);
    QVERIFY(manager.registerTask(removedTask));

    const auto replacementProbe = std::make_shared<TaskProbe>();
    QPointer<ProbeTask> replacementTask;
    bool registered = false;
    connect(&manager,
            &TaskManager::taskAboutToBeRemoved,
            &manager,
            [&](Task* task) {
                if (task != removedTask)
                    return;

                manager.setAutoStart(true);
                replacementTask = new ProbeTask(replacementProbe);
                registered = manager.registerTask(replacementTask);
            });

    manager.clearTasks();

    QVERIFY(registered);
    QTRY_VERIFY(replacementTask && replacementTask->finished());
    QCOMPARE(replacementProbe->startCount.load(), 1);
}

void TaskContractsTest::destructionCancelsAndWaitsForWorker()
{
    const auto probe = std::make_shared<TaskProbe>();
    probe->blockStart = true;

    auto* manager = new TaskManager;
    manager->setAutoStart(false);
    auto* task = new ProbeTask(probe);
    QVERIFY(manager->registerTask(task));
    QVERIFY(manager->startTask(task));
    QVERIFY(probe->entered.tryAcquire(1, 5000));

    delete manager;

    QCOMPARE(probe->startCount.load(), 1);
    QCOMPARE(probe->cancelCount.load(), 1);
    QCOMPARE(probe->cancelThread.load(), QThread::currentThread());
    QVERIFY(probe->startThread.load() != QThread::currentThread());
    QCOMPARE(probe->destructionCount.load(), 1);
}

int runTaskContracts(int argc, char **argv)
{
    TaskContractsTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_TaskContracts.moc"
