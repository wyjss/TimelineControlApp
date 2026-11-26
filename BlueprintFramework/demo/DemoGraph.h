#pragma once

#include <Blueprint/GraphEditSession.h>
#include <Blueprint/GraphRuntime.h>

#include <QElapsedTimer>
#include <QSet>
#include <QTimer>
#include <QUrl>

//! 由示例宿主持有的模拟资源，接口完成与属性变化分别通知。
class DemoSpeaker final : public QObject
{
    Q_OBJECT

public:
    DemoSpeaker(const Blueprint::NodeTypeDefinition &definition, int durationMs, QObject *parent);
    QVariantMap state() const;
    Blueprint::Diagnostic writeState(const QString &key, const QVariant &value);
    Blueprint::Diagnostic invoke(const QString &key, const QUuid &callId, const QVariantMap &inputs,
                                 std::function<void(QVariantMap, Blueprint::Diagnostic)> complete);
    void cancel(const QUuid &callId);

signals:
    void stateChanged(const QStringList &keys);

private:
    const Blueprint::NodeTypeDefinition &m_definition;
    int m_durationMs;
    QTimer m_timer;
    QUuid m_callId;
    std::function<void(Blueprint::Diagnostic)> m_complete;
};

//! 示例节点、计算预览和宿主文件操作。
class DemoGraph final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *session READ session CONSTANT)
    Q_PROPERTY(QVariantList palette READ palette NOTIFY paletteChanged)
    Q_PROPERTY(QStringList placedObjectIds READ placedObjectIds NOTIFY placedObjectsChanged)
    Q_PROPERTY(QVariantList constantOptions READ constantOptions CONSTANT)
    Q_PROPERTY(QVariantList existingSpeakerOptions READ existingSpeakerOptions CONSTANT)
    Q_PROPERTY(QVariantList speakerOptions READ speakerOptions NOTIFY speakerNodesChanged)
    Q_PROPERTY(QVariantList readTargetOptions READ readTargetOptions NOTIFY readTargetsChanged)
    Q_PROPERTY(QVariantMap previewValues READ previewValues NOTIFY previewValuesChanged)
    Q_PROPERTY(QVariantMap deviceCommandResults READ deviceCommandResults NOTIFY deviceCommandResultsChanged)
    Q_PROPERTY(QVariantMap nodeStates READ nodeStates NOTIFY nodeStatesChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString errorNodeId READ errorNodeId NOTIFY errorChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY fileNameChanged)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit DemoGraph(QObject *parent = nullptr);
    ~DemoGraph() override;

    QObject *session();
    QVariantList palette() const;
    QStringList placedObjectIds() const;
    QVariantList constantOptions() const;
    QVariantList existingSpeakerOptions() const;
    QVariantList speakerOptions() const;
    QVariantList readTargetOptions() const;
    QVariantMap previewValues() const;
    QVariantMap deviceCommandResults() const;
    QVariantMap nodeStates() const;
    QString error() const;
    QString errorNodeId() const;
    QString fileName() const;
    bool running() const;

    Q_INVOKABLE bool setConstantInput(const QString &nodeId, const QString &text);
    Q_INVOKABLE QVariantMap speakerState(const QString &targetId) const;
    Q_INVOKABLE bool invokeSpeaker(const QString &targetId, const QString &actionKey);
    Q_INVOKABLE QVariantList operationMembers(const QString &typeId, const QString &targetId) const;
    Q_INVOKABLE QVariantList objectMembers(const QString &targetId) const;
    Q_INVOKABLE QVariantList readMembers(const QString &targetId) const;
    Q_INVOKABLE bool bindRead(const QString &nodeId, const QString &targetId, const QString &member);
    Q_INVOKABLE QString addOperation(const QString &typeId, const QString &targetId,
                                     const QString &member, QPointF position);
    Q_INVOKABLE bool setDurationInput(const QString &nodeId, const QString &text);
    Q_INVOKABLE bool bindCall(const QString &nodeId, const QString &targetId, const QString &member);
    Q_INVOKABLE QVariantList callInputs(const QString &nodeId) const;
    Q_INVOKABLE bool setCallInput(const QString &nodeId, const QString &portKey, const QString &text);
    Q_INVOKABLE bool bindPropertyEvent(const QString &nodeId, const QString &targetId, const QString &member);
    Q_INVOKABLE bool setWaitDuration(const QString &nodeId, const QString &text);
    Q_INVOKABLE bool trigger();
    Q_INVOKABLE bool run(const QString &triggerId);
    Q_INVOKABLE void stop();
    Q_INVOKABLE bool open(const QUrl &url);
    Q_INVOKABLE bool save(const QUrl &url);

signals:
    void paletteChanged();
    void placedObjectsChanged();
    void previewValuesChanged();
    void deviceCommandResultsChanged();
    void nodeStatesChanged();
    void errorChanged();
    void fileNameChanged();
    void runningChanged();
    void speakerStateChanged(const QString &targetId);
    void speakerNodesChanged();
    void readTargetsChanged();

private slots:
    void nodeExecutionChanged(const QUuid &nodeId, const QUuid &callId, bool running);

private:
    static QString targetType(const QString &targetId);
    //! 使用稳定的对象类型声明解析签名，设备失效时仍保留端口。
    const Blueprint::MethodDefinition *callMethod(const QString &targetId, const QString &member) const;
    Blueprint::RuntimeImplementations runtimeImplementations(const Blueprint::GraphSnapshot &snapshot);
    bool startExecution(Blueprint::GraphRuntime &runtime, const Blueprint::GraphSnapshot &snapshot,
                        QUuid entry, const QVariantMap &entryOutputs = {});
    void executionFinished(Blueprint::GraphRuntime *runtime, const Blueprint::Diagnostic &error);
    void speakerChanged(const QString &targetId, const QStringList &keys);
    void captureResultValues(Blueprint::GraphRuntime &runtime, quint64 revision);
    void updateValues();
    void syncSpeakers(const Blueprint::GraphChangeSet &change = {});
    bool report(const QString &error, const QUuid &nodeId = {});

    Blueprint::NodeRegistry m_registry;
    Blueprint::GraphDocument m_document;
    Blueprint::GraphEditSession m_session;
    Blueprint::RuntimeImplementations m_basicImplementations;
    Blueprint::GraphRuntime m_runtime;
    Blueprint::GraphRuntime m_automaticRuntime;
    Blueprint::GraphRuntime m_previewRuntime;
    QHash<QString, DemoSpeaker *> m_speakers;
    QSet<Blueprint::GraphRuntime *> m_executions;
    QHash<QUuid, QUuid> m_activeCalls;
    bool m_suppressPropertyEvents = false;
    QVariantMap m_values;
    QHash<QUuid, QVariant> m_executionResultValues;
    QVariantMap m_deviceCommandResults;
    quint64 m_resultRevision = 0;
    QString m_error;
    QUuid m_errorNodeId;
    QString m_fileName;
};
