#pragma once

#include <Blueprint/GraphEditSession.h>
#include <Blueprint/GraphRuntime.h>

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
    Blueprint::Diagnostic invoke(const QString &key, const QUuid &callId,
                                 std::function<void(Blueprint::Diagnostic)> complete);
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
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY fileNameChanged)

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
    QString error() const;
    QString fileName() const;

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
    Q_INVOKABLE bool run(const QString &triggerId);
    Q_INVOKABLE bool open(const QUrl &url);
    Q_INVOKABLE bool save(const QUrl &url);

signals:
    void paletteChanged();
    void placedObjectsChanged();
    void previewValuesChanged();
    void errorChanged();
    void fileNameChanged();
    void speakerStateChanged(const QString &targetId);
    void speakerNodesChanged();
    void readTargetsChanged();

private:
    QString targetType(const QString &targetId) const;
    Blueprint::RuntimeImplementations runtimeImplementations(const Blueprint::GraphSnapshot &snapshot);
    void updateValues();
    void syncSpeakers(const Blueprint::GraphChangeSet &change = {});
    bool report(const QString &error);

    Blueprint::NodeRegistry m_registry;
    Blueprint::GraphDocument m_document;
    Blueprint::GraphEditSession m_session;
    Blueprint::GraphRuntime m_runtime;
    Blueprint::GraphRuntime m_previewRuntime;
    QHash<QString, DemoSpeaker *> m_speakers;
    QVariantMap m_values;
    QString m_error;
    QString m_fileName;
};
