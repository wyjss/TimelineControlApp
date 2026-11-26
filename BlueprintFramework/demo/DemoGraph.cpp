#include "DemoGraph.h"

#include <Blueprint/BasicNodes.h>
#include <Blueprint/ObjectNodes.h>
#include <Blueprint/WaitNodes.h>

#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QMetaType>
#include <QRegularExpression>
#include <QScopedValueRollback>
#include <QSet>
#include <QtMath>

#include <algorithm>

using namespace Blueprint;

namespace {

const auto constantType = QStringLiteral("demo.constant");
const auto optionConstantType = QStringLiteral("demo.optionConstant");
const auto additionType = QStringLiteral("demo.add");
const auto greaterType = QStringLiteral("demo.greater");
const auto lessType = QStringLiteral("demo.less");
const auto equalType = QStringLiteral("demo.equal");
const auto resultType = QStringLiteral("demo.result");
const auto textResultType = QStringLiteral("demo.textResult");
const auto speakerType = QStringLiteral("demo.speaker");
const auto speakerReferenceType = QStringLiteral("demo.speakerReference");
const auto triggerType = QStringLiteral("demo.trigger");
const auto startType = QStringLiteral("demo.start");
const auto propertyEventType = QStringLiteral("demo.propertyChanged");
const auto waitType = QStringLiteral("demo.wait");
const auto waitUntilType = QStringLiteral("demo.waitUntil");
const auto forkType = QStringLiteral("demo.fork");
const auto deviceCommandType = QStringLiteral("demo.deviceCommand");
const auto readPropertyType = QStringLiteral("demo.readProperty");
const auto setType = QStringLiteral("demo.setProperty");
const auto callType = QStringLiteral("demo.call");
const auto boolResultType = QStringLiteral("demo.boolResult");
const auto objectCategory = QStringLiteral("objects");
const auto existingObjectCategory = QStringLiteral("existingObjects");
const auto valueCategory = QStringLiteral("values");
const auto logicCategory = QStringLiteral("logic");
const auto operationCategory = QStringLiteral("objectOperations");
const auto flowCategory = QStringLiteral("flow");
const auto entryCategory = QStringLiteral("entry");
const auto resultCategory = QStringLiteral("results");
const auto valueKey = QStringLiteral("value");
const auto inputA = QStringLiteral("A");
const auto inputB = QStringLiteral("B");
const auto numberType = QStringLiteral("number");
const auto stringType = QStringLiteral("string");
const auto boolType = QStringLiteral("bool");
const auto autoOption = QStringLiteral("auto");
const auto durationKey = QStringLiteral("testDurationMs");
const auto waitDurationKey = QStringLiteral("durationMs");
const auto playTestMethod = QStringLiteral("playTest");
const auto playForMethod = QStringLiteral("playFor");
const auto playedDurationKey = QStringLiteral("playedDurationMs");
const auto playingKey = QStringLiteral("playing");
const auto targetKey = QStringLiteral("target");
const auto objectIdKey = QStringLiteral("objectId");
const auto nameKey = QStringLiteral("name");
const auto memberKey = QStringLiteral("member");
const auto deviceNameKey = QStringLiteral("deviceName");
const auto commandNameKey = QStringLiteral("cmdName");
const auto commandLabelKey = QStringLiteral("simName");
const auto commandParametersKey = QStringLiteral("params");
const auto execIn = QStringLiteral("execIn");
const auto execOut = QStringLiteral("execOut");
const auto firstBranch = QStringLiteral("branch1");
const auto secondBranch = QStringLiteral("branch2");
constexpr int minDuration = 100;
constexpr int maxDuration = 10000;

// 对象引用同时包含所属作用域、类型和稳定标识，失效后仍能解析成员声明。
const struct {
    QString id;
    const char *label;
    int durationMs;
} existingSpeakers[] = {
    {QStringLiteral("host:demo.speaker:speaker-a"), QT_TRANSLATE_NOOP("DemoGraph", "音箱 A"), 2000},
    {QStringLiteral("host:demo.speaker:speaker-b"), QT_TRANSLATE_NOOP("DemoGraph", "音箱 B"), 4000}
};

QString displayValue(const QVariant &value)
{
    if (value.userType() == QMetaType::Bool)
        return value.toBool() ? DemoGraph::tr("是") : DemoGraph::tr("否");
    if (value.userType() == QMetaType::QString) {
        const auto text = value.toString();
        return text.isEmpty() ? DemoGraph::tr("（空字符串）") : text;
    }
    return QLocale::c().toString(value.toDouble(), 'g', 12);
}

} // namespace

DemoSpeaker::DemoSpeaker(const NodeTypeDefinition &definition, int durationMs, QObject *parent)
    : QObject(parent), m_definition(definition), m_durationMs(durationMs)
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, [this] {
        auto complete = std::move(m_complete);
        m_callId = {};
        emit stateChanged({playingKey});
        if (complete)
            complete({});
    });
}

QVariantMap DemoSpeaker::state() const
{
    return {{playingKey, m_timer.isActive()}, {durationKey, m_durationMs}};
}

Diagnostic DemoSpeaker::writeState(const QString &key, const QVariant &value)
{
    for (const auto &property : m_definition.properties) {
        if (property.value.key != key)
            continue;
        if (!property.writable)
            return {"demo.read_only_property", DemoGraph::tr("属性不可写：%1").arg(key), {}, key};
        const auto error = NodeRegistry::validateValues({property.value}, {{key, value}});
        if (!error.code.isEmpty())
            return error;
        if (m_durationMs != value.toInt()) {
            m_durationMs = value.toInt();
            emit stateChanged({key});
        }
        return {};
    }
    return {"demo.unknown_property", DemoGraph::tr("未知属性：%1").arg(key), {}, key};
}

Diagnostic DemoSpeaker::invoke(const QString &key, const QUuid &callId, const QVariantMap &inputs,
                               std::function<void(QVariantMap, Diagnostic)> complete)
{
    const auto method = std::find_if(m_definition.methods.cbegin(), m_definition.methods.cend(),
                                    [&](const MethodDefinition &definition) { return definition.key == key; });
    if (method == m_definition.methods.cend())
        return {"demo.unknown_method", DemoGraph::tr("未知接口：%1").arg(key), {}, key};
    if (const auto error = NodeRegistry::validateValues(method->inputs, inputs); !error.code.isEmpty())
        return error;

    if (key == playTestMethod || key == playForMethod) {
        if (m_timer.isActive())
            return {"demo.speaker_busy", DemoGraph::tr("正在测试，请先停止或等待结束。")};
        const int duration = key == playForMethod
            ? inputs.value(durationKey, method->inputs.first().defaultValue).toInt() : m_durationMs;
        QVariantMap outputs;
        if (key == playForMethod)
            outputs.insert(playedDurationKey, duration);
        m_callId = callId;
        m_complete = [complete = std::move(complete), outputs = std::move(outputs)](const Diagnostic &error) {
            complete(error.code.isEmpty() ? outputs : QVariantMap{}, error);
        };
        m_timer.start(duration);
        emit stateChanged({playingKey});
    } else if (key == QStringLiteral("stop")) {
        if (m_timer.isActive())
            cancel(m_callId);
        complete({}, {});
    } else {
        return {"demo.unknown_method", DemoGraph::tr("未知接口：%1").arg(key), {}, key};
    }
    return {};
}

void DemoSpeaker::cancel(const QUuid &callId)
{
    if (m_callId != callId || !m_timer.isActive())
        return;
    m_timer.stop();
    m_callId = {};
    auto complete = std::move(m_complete);
    emit stateChanged({playingKey});
    if (complete)
        complete({QStringLiteral("demo.cancelled"), DemoGraph::tr("播放已停止。")});
}

DemoGraph::DemoGraph(QObject *parent)
    : QObject(parent), m_document(m_registry), m_session(m_document)
{
    const PortDefinition execute{execIn, PortDirection::Input, {}, tr("执行"), PortKind::Execution};
    const PortDefinition next{execOut, PortDirection::Output, {}, tr("继续"), PortKind::Execution};
    const ParameterDefinition target{targetKey, stringType, QStringLiteral("")};
    const ParameterDefinition name{nameKey, stringType, QStringLiteral(""), {}, tr("对象名称")};
    const ParameterDefinition duration{durationKey, numberType, 2000.0, {}, tr("测试时长"), {},
                                       minDuration, maxDuration, true};
    const ParameterDefinition propertyMember{memberKey, stringType, QStringLiteral("")};
    ParameterDefinition durationInput = duration;
    durationInput.key = valueKey;
    durationInput.defaultValue = 3000.0;
    ParameterDefinition playForInput = duration;
    playForInput.displayName = tr("时长（毫秒）");
    QVector<NodeTypeDefinition> definitions{
        {resultType, tr("结果"), {{valueKey, PortDirection::Input, numberType, tr("输入")}}, {}, resultCategory,
         InstancePolicy::Multiple, {}, tr("显示收到的数值"), "="},
        {textResultType, tr("文本结果"), {{valueKey, PortDirection::Input, stringType, tr("输入")}}, {}, resultCategory,
         InstancePolicy::Multiple, {}, tr("显示收到的文本"), "="},
        {speakerType, tr("模拟音箱"), {}, {duration, name}, objectCategory,
         InstancePolicy::Multiple, {}, tr("测试和停止播放"), "♪",
         {{{playingKey, boolType, false, {}, tr("播放状态")}, false}, {duration, true}},
         {{playTestMethod, tr("测试播放")}, {QStringLiteral("stop"), tr("停止")},
          {playForMethod, tr("按指定时长播放"), {playForInput},
           {{playedDurationKey, numberType, {}, {}, tr("播放时长")}}}}},
        {speakerReferenceType, tr("已有音箱"), {}, {{objectIdKey, stringType, {}}}, existingObjectCategory,
         InstancePolicy::UniqueByParameter, objectIdKey, tr("显示和控制已有音箱"), "♪"},
        {startType, tr("开始（自动）"), {next}, {}, entryCategory,
         InstancePolicy::SinglePerDocument, {}, tr("蓝图触发时开始执行"), "▶"},
        {triggerType, tr("开始（手动）"), {next}, {}, entryCategory,
         InstancePolicy::Multiple, {}, tr("点击运行后开始执行"), "▶"},
        {propertyEventType, tr("属性变化"), {}, {target, propertyMember}, entryCategory,
         InstancePolicy::Multiple, {}, tr("指定对象的属性变化时触发"), "↗"},
        // 保留旧图中的分支端口，节点库使用普通执行输出直接分流。
        {forkType, tr("同时触发"),
         {execute, {firstBranch, PortDirection::Output, {}, tr("分支 1"), PortKind::Execution},
          {secondBranch, PortDirection::Output, {}, tr("分支 2"), PortKind::Execution}}, {}, flowCategory,
         InstancePolicy::Multiple, {}, tr("触发所有已连接的分支"), "↗"},
        {deviceCommandType, tr("设备指令"),
         {{execIn, PortDirection::Input, {}, tr("安排"), PortKind::Execution}},
         {{deviceNameKey, stringType, QStringLiteral(""), {}, tr("设备名称")},
          {commandNameKey, stringType, QStringLiteral(""), {}, tr("指令名称")},
          {commandLabelKey, stringType, QStringLiteral(""), {}, tr("显示名称")},
          {commandParametersKey, stringType, QStringLiteral("{}"), {}, tr("参数")}},
         operationCategory, InstancePolicy::Multiple, {}, tr("记录时间点上的设备指令"), "◇"},
        {boolResultType, tr("状态结果"), {{valueKey, PortDirection::Input, boolType, tr("输入")}}, {}, resultCategory,
         InstancePolicy::Multiple, {}, tr("显示布尔值"), "="}
    };
    for (auto &definition : definitions) {
        if (definition.typeId == propertyEventType) {
            definition.resolvePorts = [this](const NodeData &node) {
                const QString typeId = targetType(node.parameterOverrides.value(targetKey).toString());
                const QString member = node.parameterOverrides.value(memberKey).toString();
                QString valueType;
                const auto *object = m_registry.find(typeId);
                if (object) {
                    for (const auto &property : object->properties) {
                        if (property.value.key == member) {
                            valueType = property.value.valueTypeId;
                            break;
                        }
                    }
                }
                return QVector<PortDefinition>{{valueKey, PortDirection::Output, valueType,
                                                tr("变化后的值"), PortKind::DataAndExecution}};
            };
        }
        const auto error = m_registry.add(definition);
        if (!error.code.isEmpty())
            qFatal("Invalid demo definition: %s", qPrintable(error.message));
    }
    const auto waitNodesError = registerWaitNodes(m_registry);
    if (!waitNodesError.code.isEmpty())
        qFatal("Invalid wait node definition: %s", qPrintable(waitNodesError.message));
    const auto basicNodesError = registerBasicNodes(m_registry, m_basicImplementations);
    if (!basicNodesError.code.isEmpty())
        qFatal("Invalid basic node definition: %s", qPrintable(basicNodesError.message));

    // 旧图的设置节点使用测试时长属性和 3000 毫秒初始输入。
    auto writeDefault = durationInput;
    writeDefault.key = durationKey;
    const auto objectNodesError = registerObjectNodes(m_registry, &DemoGraph::targetType, writeDefault, playTestMethod);
    if (!objectNodesError.code.isEmpty())
        qFatal("Invalid object node definition: %s", qPrintable(objectNodesError.message));

    for (const auto &entry : existingSpeakers) {
        auto *speaker = new DemoSpeaker(*m_registry.find(speakerType), entry.durationMs, this);
        m_speakers.insert(entry.id, speaker);
        connect(speaker, &DemoSpeaker::stateChanged, this, [this, id = entry.id](const QStringList &keys) {
            speakerChanged(id, keys);
        });
    }
    const QUuid first = QUuid::createUuid();
    const QUuid second = QUuid::createUuid();
    const QUuid addition = QUuid::createUuid();
    const QUuid result = QUuid::createUuid();
    const QUuid speaker = QUuid::createUuid();
    const QUuid trigger = QUuid::createUuid();
    const QUuid set = QUuid::createUuid();
    const QUuid call = QUuid::createUuid();
    const QUuid read = QUuid::createUuid();
    const QUuid status = QUuid::createUuid();
    const QString speakerTarget = QStringLiteral("node:%1:%2").arg(speakerType, speaker.toString(QUuid::WithoutBraces));
    const QVariantMap bound{{targetKey, speakerTarget}};
    const auto initial = m_document.replaceData({m_document.data().id, {
        {first, constantType, {42, 104}, {{valueKey, 12.0}}},
        {second, constantType, {42, 294}, {{valueKey, 30.0}}},
        {addition, additionType, {300, 192}, {}},
        {result, resultType, {558, 192}, {}},
        {speaker, speakerType, {800, 42}, {{nameKey, tr("模拟音箱 1")}}},
        {QUuid::createUuid(), speakerType, {800, 294}, {{durationKey, 4000.0}, {nameKey, tr("模拟音箱 2")}}},
        {trigger, triggerType, {42, 420}, {}},
        {set, setType, {300, 420}, bound},
        {call, callType, {558, 420}, bound},
        {read, readPropertyType, {300, 580}, {{targetKey, speakerTarget}, {memberKey, playingKey}}},
        {status, boolResultType, {558, 580}, {}}
    }, {
        {QUuid::createUuid(), {first, valueKey}, {addition, inputA}},
        {QUuid::createUuid(), {second, valueKey}, {addition, inputB}},
        {QUuid::createUuid(), {addition, valueKey}, {result, valueKey}},
        {QUuid::createUuid(), {trigger, execOut}, {set, execIn}},
        {QUuid::createUuid(), {set, execOut}, {call, execIn}},
        {QUuid::createUuid(), {read, valueKey}, {status, valueKey}}
    }});
    if (!initial.code.isEmpty())
        qFatal("Invalid demo graph: %s", qPrintable(initial.message));
    syncSpeakers();
    updateValues();
    connect(&m_registry, &NodeRegistry::typeAdded, this, [this] { emit paletteChanged(); });
    for (auto *runtime : {&m_runtime, &m_automaticRuntime}) {
        connect(runtime, &GraphRuntime::nodeExecutionChanged, this, &DemoGraph::nodeExecutionChanged);
        connect(runtime, &GraphRuntime::executionOutputsPublished, this,
                [this, runtime](const QUuid &, const QVariantMap &, quint64 revision) {
            captureResultValues(*runtime, revision);
        });
        connect(runtime, &GraphRuntime::executionFinished, this, [this, runtime](const QUuid &, const Diagnostic &error) {
            executionFinished(runtime, error);
        });
    }
    connect(&m_document, &GraphDocument::changed, this, [this](const GraphChangeSet &change) {
        const bool configurationChanged = change.reset || !change.addedNodeIds.isEmpty()
            || !change.removedNodeIds.isEmpty()
            || std::any_of(change.changedNodes.cbegin(), change.changedNodes.cend(), [](const NodeChange &node) {
                return !node.parameterKeys.isEmpty();
            });
        const bool valuesChanged = configurationChanged
            || !change.addedConnectionIds.isEmpty() || !change.removedConnectionIds.isEmpty();
        if (valuesChanged) {
            m_resultRevision = change.revision;
            m_executionResultValues.clear();
            if (!m_deviceCommandResults.isEmpty()) {
                m_deviceCommandResults.clear();
                emit deviceCommandResultsChanged();
            }
        }
        report({});
        if (configurationChanged) {
            syncSpeakers(change);
            emit placedObjectsChanged();
            emit readTargetsChanged();
        }
        if (valuesChanged)
            updateValues();
    });
}

DemoGraph::~DemoGraph()
{
    stop();
    m_previewRuntime.stop();
}

QObject *DemoGraph::session() { return &m_session; }
QVariantMap DemoGraph::previewValues() const { return m_values; }
QVariantMap DemoGraph::deviceCommandResults() const { return m_deviceCommandResults; }
QVariantMap DemoGraph::nodeStates() const
{
    QVariantMap states;
    for (const auto &nodeId : m_activeCalls) {
        const auto *node = m_document.findNode(nodeId);
        states.insert(nodeId.toString(QUuid::WithoutBraces),
                      node && (node->typeId == waitType || node->typeId == waitUntilType)
                          ? QStringLiteral("waiting") : QStringLiteral("running"));
    }
    return states;
}
QString DemoGraph::error() const { return m_error; }
QString DemoGraph::errorNodeId() const { return m_errorNodeId.toString(QUuid::WithoutBraces); }
QString DemoGraph::fileName() const { return m_fileName; }
bool DemoGraph::running() const { return !m_executions.isEmpty(); }

QVariantList DemoGraph::palette() const
{
    QHash<QString, QVariantList> nodesByCategory;
    QStringList categoryIds{existingObjectCategory, objectCategory, valueCategory, logicCategory,
                            operationCategory, entryCategory, flowCategory, resultCategory};
    const QHash<QString, QString> categoryTitles{
        {existingObjectCategory, tr("已有对象")}, {objectCategory, tr("对象")}, {valueCategory, tr("值")},
        {logicCategory, tr("运算与判断")}, {operationCategory, tr("对象操作")},
        {entryCategory, tr("入口与事件")}, {flowCategory, tr("流程控制")}, {resultCategory, tr("结果与调试")}
    };
    for (const auto &definition : m_registry.definitions()) {
        if (definition.typeId == speakerReferenceType || definition.typeId == forkType || definition.typeId == greaterType
            || definition.typeId == lessType || definition.typeId == equalType)
            continue;
        if (!categoryIds.contains(definition.categoryId))
            categoryIds.append(definition.categoryId);
        nodesByCategory[definition.categoryId].append(QVariantMap{
            {QStringLiteral("type"), definition.typeId}, {QStringLiteral("title"), definition.displayName},
            {QStringLiteral("description"), definition.description}, {QStringLiteral("symbol"), definition.symbol}
        });
    }
    const auto *reference = m_registry.find(speakerReferenceType);
    for (const auto &entry : existingSpeakers) {
        nodesByCategory[existingObjectCategory].append(QVariantMap{
            {QStringLiteral("type"), reference->typeId}, {QStringLiteral("title"), tr(entry.label)},
            {QStringLiteral("description"), reference->description}, {QStringLiteral("symbol"), reference->symbol},
            {QStringLiteral("parameters"), QVariantMap{{objectIdKey, entry.id}}}
        });
    }
    QVariantList groups;
    for (const auto &category : categoryIds) {
        const auto nodes = nodesByCategory.value(category);
        if (!nodes.isEmpty()) {
            groups.append(QVariantMap{{QStringLiteral("id"), category},
                                      {QStringLiteral("title"), categoryTitles.value(category, category)},
                                      {QStringLiteral("nodes"), nodes}});
        }
    }
    return groups;
}

QStringList DemoGraph::placedObjectIds() const
{
    QStringList ids;
    for (const NodeData &node : m_document.data().nodes) {
        if (node.typeId == speakerReferenceType)
            ids.append(m_document.parameterValue(node.id, objectIdKey).toString());
    }
    return ids;
}

QVariantList DemoGraph::constantOptions() const
{
    QVariantList options;
    const auto *definition = m_registry.find(optionConstantType);
    for (const auto &option : definition->parameters.first().allowedValues) {
        const auto label = option == autoOption ? tr("自动") : tr("手动");
        options.append(QVariantMap{{QStringLiteral("label"), label}, {QStringLiteral("value"), option}});
    }
    return options;
}

bool DemoGraph::setConstantInput(const QString &nodeId, const QString &text)
{
    QVariant value = text;
    const auto *node = m_document.findNode(QUuid(nodeId));
    if (node && node->typeId == constantType) {
        bool ok = false;
        const double number = text.trimmed().toDouble(&ok);
        if (!ok || !qIsFinite(number))
            return report(tr("请输入有效数值。"));
        value = number;
    }
    report({});
    return m_session.setParameter(nodeId, valueKey, value);
}

QVariantList DemoGraph::existingSpeakerOptions() const
{
    QVariantList options;
    for (const auto &entry : existingSpeakers) {
        options.append(QVariantMap{{QStringLiteral("value"), entry.id},
                                   {QStringLiteral("name"), tr(entry.label)},
                                   {QStringLiteral("label"), tr(entry.label)}});
    }
    return options;
}

QVariantList DemoGraph::speakerOptions() const
{
    QVariantList options = existingSpeakerOptions();
    for (const NodeData &node : m_document.data().nodes) {
        if (node.typeId != speakerType)
            continue;
        const auto id = node.id.toString(QUuid::WithoutBraces);
        const auto name = m_document.parameterValue(node.id, nameKey).toString().trimmed();
        options.append(QVariantMap{{QStringLiteral("value"), QStringLiteral("node:%1:%2").arg(node.typeId, id)},
                                   {QStringLiteral("label"), name.isEmpty() ? tr("模拟音箱") : name}});
    }
    return options;
}

QVariantList DemoGraph::readTargetOptions() const
{
    QVariantList options = existingSpeakerOptions();
    for (const NodeData &node : m_document.data().nodes) {
        const auto *definition = m_registry.find(node.typeId);
        if (definition->properties.isEmpty())
            continue;
        const auto id = node.id.toString(QUuid::WithoutBraces);
        const auto name = node.typeId == speakerType
            ? m_document.parameterValue(node.id, nameKey).toString().trimmed() : QString{};
        const auto label = name.isEmpty() ? definition->displayName : name;
        options.append(QVariantMap{{QStringLiteral("value"), QStringLiteral("node:%1:%2").arg(node.typeId, id)},
                                   {QStringLiteral("name"), label},
                                   {QStringLiteral("label"), label}});
    }
    return options;
}

QVariantMap DemoGraph::speakerState(const QString &targetId) const
{
    const auto *speaker = m_speakers.value(targetId);
    return speaker ? speaker->state() : QVariantMap{};
}

bool DemoGraph::invokeSpeaker(const QString &targetId, const QString &actionKey)
{
    auto *speaker = m_speakers.value(targetId);
    if (!speaker)
        return report(tr("音箱对象已失效。"));
    const auto error = speaker->invoke(actionKey, QUuid::createUuid(), {}, [this](const QVariantMap &, const Diagnostic &result) {
        if (!result.code.isEmpty() && result.code != QStringLiteral("demo.cancelled"))
            report(result.message);
    });
    return report(error.message);
}

QVariantList DemoGraph::operationMembers(const QString &typeId, const QString &targetId) const
{
    if (typeId == propertyEventType)
        return m_speakers.contains(targetId) ? readMembers(targetId) : QVariantList{};

    QVariantList members;
    const auto *object = m_registry.find(targetType(targetId));
    if (!object)
        return members;
    if (typeId == setType) {
        for (const auto &property : object->properties) {
            if (property.writable) {
                members.append(QVariantMap{{QStringLiteral("label"), property.value.displayName},
                                           {QStringLiteral("value"), property.value.key}});
            }
        }
    } else if (typeId == callType) {
        for (const auto &method : object->methods) {
            members.append(QVariantMap{{QStringLiteral("label"), method.displayName},
                                       {QStringLiteral("value"), method.key}});
        }
    }
    return members;
}

QVariantList DemoGraph::objectMembers(const QString &targetId) const
{
    QVariantList members;
    const auto *object = m_registry.find(targetType(targetId));
    if (!object)
        return members;
    for (const auto &property : object->properties) {
        members.append(QVariantMap{{QStringLiteral("label"), property.value.displayName},
                                   {QStringLiteral("key"), property.value.key},
                                   {QStringLiteral("writable"), property.writable},
                                   {QStringLiteral("type"), readPropertyType}});
    }
    for (const auto &method : object->methods) {
        members.append(QVariantMap{{QStringLiteral("label"), method.displayName},
                                   {QStringLiteral("key"), method.key},
                                   {QStringLiteral("writable"), false}, {QStringLiteral("type"), callType}});
    }
    return members;
}

QString DemoGraph::targetType(const QString &targetId)
{
    const auto parts = targetId.split(QLatin1Char(':'));
    if (parts.size() != 3 || (parts.first() != QStringLiteral("node") && parts.first() != QStringLiteral("host"))
        || parts.last().isEmpty())
        return {};
    return parts.at(1);
}

const MethodDefinition *DemoGraph::callMethod(const QString &targetId, const QString &member) const
{
    const auto *type = m_registry.find(targetType(targetId));
    if (!type)
        return nullptr;
    const auto method = std::find_if(type->methods.cbegin(), type->methods.cend(),
                                    [&](const MethodDefinition &definition) { return definition.key == member; });
    return method == type->methods.cend() ? nullptr : &*method;
}

QVariantList DemoGraph::readMembers(const QString &targetId) const
{
    QVariantList members;
    const auto *object = m_registry.find(targetType(targetId));
    if (object) {
        for (const auto &property : object->properties) {
            members.append(QVariantMap{{QStringLiteral("label"), property.value.displayName},
                                       {QStringLiteral("value"), property.value.key}});
        }
    }
    return members;
}

bool DemoGraph::bindRead(const QString &nodeId, const QString &targetId, const QString &member)
{
    const auto *node = m_document.findNode(QUuid(nodeId));
    if (!node || node->typeId != readPropertyType || targetType(targetId).isEmpty())
        return report(tr("读取节点或目标已失效。"));
    bool found = member.isEmpty();
    for (const auto &entry : readMembers(targetId))
        found = found || entry.toMap().value(QStringLiteral("value")).toString() == member;
    if (!found)
        return report(tr("所选目标没有此属性。"));
    report({});
    return m_session.setParameters(nodeId, {{targetKey, targetId}, {memberKey, member}});
}

QString DemoGraph::addOperation(const QString &typeId, const QString &targetId, const QString &member, QPointF position)
{
    const auto members = typeId == readPropertyType ? readMembers(targetId) : operationMembers(typeId, targetId);
    bool found = false;
    for (const auto &entry : members)
        found = found || entry.toMap().value(QStringLiteral("value")).toString() == member;
    if (!found) {
        report(tr("所选目标没有此属性或接口。"));
        return {};
    }
    report({});
    return m_session.placeNode(typeId, position, {{targetKey, targetId}, {memberKey, member}});
}

bool DemoGraph::setDurationInput(const QString &nodeId, const QString &text)
{
    bool ok = false;
    const double duration = text.trimmed().toDouble(&ok);
    if (!ok)
        return report(tr("请输入有效数值。"));
    report({});
    return m_session.setParameter(nodeId, valueKey, duration);
}

bool DemoGraph::bindCall(const QString &nodeId, const QString &targetId, const QString &member)
{
    const QUuid id(nodeId);
    const auto *node = m_document.findNode(id);
    if (!node || node->typeId != callType)
        return report(tr("调用节点已失效。"), id);
    if (!m_speakers.contains(targetId))
        return report(tr("请选择有效的目标对象。"), id);
    if (!member.isEmpty() && !callMethod(targetId, member))
        return report(tr("所选目标没有此接口。"), id);

    report({});
    if (m_session.setParameters(nodeId, {{targetKey, targetId}, {memberKey, member}}))
        return true;

    const auto diagnostic = m_session.diagnostic();
    if (diagnostic.value(QStringLiteral("code")).toString() == QStringLiteral("graph.connected_port_change")) {
        const auto key = diagnostic.value(QStringLiteral("key")).toString();
        for (const auto &port : m_document.nodePorts(id)) {
            if (port.key == key)
                return report(tr("请先断开「%1」的连线，再更换接口。").arg(port.displayName), id);
        }
    }
    return report(m_session.error(), id);
}

QVariantList DemoGraph::callInputs(const QString &nodeId) const
{
    const QUuid id(nodeId);
    const auto *node = m_document.findNode(id);
    if (!node || node->typeId != callType)
        return {};
    const auto target = m_document.parameterValue(id, targetKey).toString();
    const auto member = m_document.parameterValue(id, memberKey).toString();
    const auto *method = callMethod(target, member);
    if (!method)
        return {};

    QVariantList inputs;
    const auto type = targetType(target);
    for (const auto &input : method->inputs) {
        const auto key = objectCallPortKey(PortDirection::Input, type, member, input.key);
        inputs.append(QVariantMap{{QStringLiteral("key"), key},
                                  {QStringLiteral("label"), input.displayName},
                                  {QStringLiteral("value"), node->parameterOverrides.value(key, input.defaultValue)},
                                  {QStringLiteral("edited"), node->parameterOverrides.contains(key)}});
    }
    return inputs;
}

bool DemoGraph::setCallInput(const QString &nodeId, const QString &portKey, const QString &text)
{
    const QUuid id(nodeId);
    const auto *node = m_document.findNode(id);
    if (!node || node->typeId != callType)
        return report(tr("调用节点已失效。"), id);
    const auto target = m_document.parameterValue(id, targetKey).toString();
    const auto member = m_document.parameterValue(id, memberKey).toString();
    const auto *method = callMethod(target, member);
    if (!method)
        return report(tr("请选择有效的接口。"), id);

    const auto type = targetType(target);
    for (const auto &input : method->inputs) {
        if (objectCallPortKey(PortDirection::Input, type, member, input.key) != portKey)
            continue;
        const auto trimmed = text.trimmed();
        QVariant overrideValue;
        if (!trimmed.isEmpty()) {
            bool ok = false;
            const double value = trimmed.toDouble(&ok);
            if (!ok || !NodeRegistry::acceptsParameterValue(input, value))
                return report(tr("「%1」必须是 %2 到 %3 的整数。").arg(input.displayName,
                                                                     input.minimum.toString(), input.maximum.toString()), id);
            // 接口默认值来自签名；没有本地覆盖时直接使用它。
            if (!input.defaultValue.isValid() || value != input.defaultValue.toDouble())
                overrideValue = value;
        }
        report({});
        return m_session.setParameter(nodeId, portKey, overrideValue) || report(m_session.error(), id);
    }
    return report(tr("接口参数已变更。"), id);
}

bool DemoGraph::bindPropertyEvent(const QString &nodeId, const QString &targetId, const QString &member)
{
    const QUuid id(nodeId);
    const auto *node = m_document.findNode(id);
    if (!node || node->typeId != propertyEventType || !m_speakers.contains(targetId))
        return report(tr("请选择有效的事件节点和目标对象。"), id);
    const auto properties = operationMembers(propertyEventType, targetId);
    if (!member.isEmpty() && std::none_of(properties.cbegin(), properties.cend(), [&](const QVariant &property) {
            return property.toMap().value(QStringLiteral("value")).toString() == member;
        }))
        return report(tr("所选目标没有此属性。"), id);
    report({});
    return m_session.setParameters(nodeId, {{targetKey, targetId}, {memberKey, member}});
}

bool DemoGraph::setWaitDuration(const QString &nodeId, const QString &text)
{
    const QUuid id(nodeId);
    const auto *node = m_document.findNode(id);
    if (!node || (node->typeId != waitType && node->typeId != waitUntilType))
        return report(tr("等待节点已失效。"), id);
    const auto &parameter = m_registry.find(node->typeId)->parameters.first();
    const qint64 maximum = parameter.maximum.toLongLong();
    bool ok = false;
    double duration = 0;
    if (text.contains(QLatin1Char(':'))) {
        static const QRegularExpression timePattern(QStringLiteral(
            R"(\A(?:([0-9]+):)?([0-9]+):([0-9]{1,2})(?:\.([0-9]{1,3}))?\z)"));
        const auto match = timePattern.match(text);
        if (match.hasMatch()) {
            const auto hoursText = match.captured(1);
            const auto minutesText = match.captured(2);
            const qint64 hours = hoursText.toLongLong(&ok);
            bool minutesOk = false;
            const qint64 minutes = minutesText.toLongLong(&minutesOk);
            // 两段式显示使用总分钟，三段式保留小时和分钟的取值规则。
            ok = (hoursText.isEmpty() || (ok && minutesText.size() <= 2 && minutes < 60))
                && minutesOk && hours <= maximum / 3600000 && minutes <= maximum / 60000
                && match.captured(3).toInt() < 60;
            if (ok) {
                const auto milliseconds = match.captured(4).leftJustified(3, QLatin1Char('0')).toInt();
                duration = hours * 3600000 + minutes * 60000
                    + match.captured(3).toInt() * 1000 + milliseconds;
            }
        }
    } else {
        duration = text.trimmed().toDouble(&ok);
    }
    if (!ok || !NodeRegistry::acceptsParameterValue(parameter, duration))
        return report(tr("请输入时间（如 06:27.060）或 0 到 %1 的整数毫秒。").arg(maximum), id);
    report({});
    return m_session.setParameter(nodeId, waitDurationKey, duration);
}

RuntimeImplementations DemoGraph::runtimeImplementations(const GraphSnapshot &snapshot)
{
    auto implementations = m_basicImplementations;
    QHash<QString, QVariantMap> configurations;
    for (const auto &node : snapshot.nodes) {
        configurations.insert(QStringLiteral("node:%1:%2").arg(node.typeId, node.id.toString(QUuid::WithoutBraces)),
                              node.parameters);
    }
    implementations.evaluators.insert(propertyEventType, [](const QVariantMap &, const QVariantMap &) {
        return EvaluationResult{{}, {"runtime.output_unavailable",
                                     tr("事件值仅在该属性变化触发的流程中可用。")}};
    });
    implementations.actions.insert(forkType, [](const ExecutionContext &, RuntimeImplementations::Completion complete) {
        complete({{}, {}, {}, {firstBranch, secondBranch}});
    });
    ObjectNodeBindings bindings;
    bindings.targetType = &DemoGraph::targetType;
    bindings.read = [this, configurations = std::move(configurations)](const QString &target, const QString &member) -> ValueResult {
        const auto *speaker = m_speakers.value(target);
        const auto value = targetType(target) == speakerType
            ? (speaker ? speaker->state().value(member) : QVariant{})
            : configurations.value(target).value(member);
        if (!value.isValid()) {
            return {{}, {"demo.unavailable_property",
                         tr("目标对象或属性不可用：%1 / %2").arg(target, member), {}, member}};
        }
        return {value, {}};
    };
    bindings.write = [this](const QString &target, const QString &member, const QVariant &value) -> Diagnostic {
        auto *speaker = m_speakers.value(target);
        return speaker ? speaker->writeState(member, value)
                       : Diagnostic{"demo.unavailable_object", tr("音箱对象已失效。"), {}, targetKey};
    };
    bindings.invoke = [this](const QString &target, const QString &member, const QUuid &callId,
                             const QVariantMap &inputs, ObjectNodeBindings::MethodCompletion complete) -> Diagnostic {
        auto *speaker = m_speakers.value(target);
        return speaker ? speaker->invoke(member, callId, inputs, std::move(complete))
                       : Diagnostic{"demo.unavailable_object", tr("音箱对象已失效。"), {}, targetKey};
    };
    bindings.cancel = [this](const QUuid &callId) {
        for (auto *speaker : m_speakers)
            speaker->cancel(callId);
    };
    addObjectImplementations(implementations, m_registry, bindings);
    return implementations;
}

bool DemoGraph::trigger()
{
    const auto &nodes = m_document.data().nodes;
    const auto entry = std::find_if(nodes.cbegin(), nodes.cend(), [](const NodeData &node) {
        return node.typeId == startType;
    });
    if (entry == nodes.cend())
        return report(tr("请先在画布中添加「开始（自动）」节点。"));
    return startExecution(m_automaticRuntime, m_document.snapshot(), entry->id);
}

bool DemoGraph::run(const QString &triggerId)
{
    const QUuid triggerNodeId(triggerId);
    const auto *trigger = m_document.findNode(triggerNodeId);
    if (!trigger || trigger->typeId != triggerType)
        return report(tr("开始节点已失效。"));
    return startExecution(m_runtime, m_document.snapshot(), triggerNodeId);
}

bool DemoGraph::startExecution(GraphRuntime &runtime, const GraphSnapshot &snapshot, QUuid entry,
                               const QVariantMap &entryOutputs)
{
    if (&runtime == &m_runtime || &runtime == &m_automaticRuntime) {
        QScopedValueRollback<bool> suppress(m_suppressPropertyEvents, true);
        runtime.stop();
        report({});
    }
    QElapsedTimer executionClock;
    executionClock.start();
    auto implementations = runtimeImplementations(snapshot);
    addWaitImplementations(implementations, runtime,
                           &runtime == &m_automaticRuntime ? executionClock : QElapsedTimer{});
    implementations.actions.insert(deviceCommandType, [this, executionClock, revision = snapshot.revision](
            const ExecutionContext &context, RuntimeImplementations::Completion complete) {
        const auto deviceName = context.parameters.value(deviceNameKey).toString().trimmed();
        const auto commandName = context.parameters.value(commandNameKey).toString().trimmed();
        if (deviceName.isEmpty() || commandName.isEmpty()) {
            complete({{}, {}, {"demo.device_command_name_required", tr("请填写设备名称和指令名称。"),
                               context.nodeId, deviceName.isEmpty() ? deviceNameKey : commandNameKey}});
            return;
        }

        const auto parameters = QJsonDocument::fromJson(context.parameters.value(commandParametersKey).toString().toUtf8());
        if (!parameters.isObject()) {
            complete({{}, {}, {"demo.invalid_device_command_params", tr("设备指令参数必须是 JSON 对象。"),
                               context.nodeId, commandParametersKey}});
            return;
        }

        if (revision >= m_resultRevision) {
            m_deviceCommandResults.insert(context.nodeId.toString(QUuid::WithoutBraces), QVariantMap{
                {deviceNameKey, deviceName},
                {commandNameKey, commandName},
                {commandLabelKey, context.parameters.value(commandLabelKey)},
                {commandParametersKey, parameters.object().toVariantMap()},
                {QStringLiteral("elapsedMs"), executionClock.elapsed()}
            });
            emit deviceCommandResultsChanged();
        }
        complete({});
    });
    const auto error = runtime.start(snapshot, implementations);
    if (!error.code.isEmpty())
        return report(error.message, error.nodeId.isNull() ? entry : error.nodeId);
    const auto result = runtime.execute({entry, entryOutputs.contains(valueKey) ? valueKey : execOut}, entryOutputs);
    if (!result.error.code.isEmpty()) {
        runtime.stop();
        return report(result.error.message, result.error.nodeId.isNull() ? entry : result.error.nodeId);
    }
    const bool wasRunning = running();
    m_executions.insert(&runtime);
    if (!wasRunning)
        emit runningChanged();
    return true;
}

void DemoGraph::nodeExecutionChanged(const QUuid &nodeId, const QUuid &callId, bool running)
{
    if (running)
        m_activeCalls.insert(callId, nodeId);
    else
        m_activeCalls.remove(callId);
    emit nodeStatesChanged();
}

void DemoGraph::executionFinished(GraphRuntime *runtime, const Diagnostic &error)
{
    if (!m_executions.remove(runtime))
        return;
    if (runtime != &m_runtime && runtime != &m_automaticRuntime)
        runtime->deleteLater();
    if (!running())
        emit runningChanged();
    if (!m_suppressPropertyEvents && !error.code.isEmpty())
        report(error.message, error.nodeId);
    updateValues();
}

void DemoGraph::stop()
{
    QScopedValueRollback<bool> suppress(m_suppressPropertyEvents, true);
    const auto executions = m_executions;
    for (auto *runtime : executions)
        runtime->stop();
    report({});
}

bool DemoGraph::open(const QUrl &url)
{
    const auto error = m_document.loadFile(url.toLocalFile());
    if (!error.code.isEmpty())
        return report(error.message);
    stop();
    m_fileName = QFileInfo(url.toLocalFile()).fileName();
    emit fileNameChanged();
    return true;
}

bool DemoGraph::save(const QUrl &url)
{
    if (!report(m_document.saveFile(url.toLocalFile()).message))
        return false;
    m_session.markSaved();
    m_fileName = QFileInfo(url.toLocalFile()).fileName();
    emit fileNameChanged();
    return true;
}

void DemoGraph::captureResultValues(GraphRuntime &runtime, quint64 revision)
{
    // 编辑语义后，仍在运行的旧快照不能再提交结果。
    if (revision < m_resultRevision)
        return;

    bool changed = false;
    for (const auto &node : m_document.data().nodes) {
        bool hasValuePort = false;
        for (const auto &port : m_document.nodePorts(node.id))
            hasValuePort = hasValuePort || (port.key == valueKey && port.kind == PortKind::Data);
        if (!hasValuePort || node.typeId == setType)
            continue;

        // 只使用发布方本次执行的数据，避免把不同事件的输出拼接成一次计算。
        const auto result = runtime.evaluate({node.id, valueKey});
        if (result.error.code == QStringLiteral("runtime.output_unavailable")
            || result.error.code == QStringLiteral("runtime.unconnected_input")
            || result.error.code == QStringLiteral("runtime.unconfigured_port"))
            continue;
        // 此缓存仅供回显；本次计算失败时覆盖旧值，保留可见诊断。
        const QVariant value = result.error.code.isEmpty() ? result.value : QVariant(result.error.message);
        m_executionResultValues.insert(node.id, value);
        const auto targetId = node.id.toString(QUuid::WithoutBraces);
        const auto display = displayValue(value);
        if (m_values.value(targetId).toString() != display) {
            m_values.insert(targetId, display);
            changed = true;
        }
    }
    if (changed)
        emit previewValuesChanged();
}

void DemoGraph::updateValues()
{
    const auto snapshot = m_document.snapshot();
    m_previewRuntime.stop();
    const auto error = m_previewRuntime.start(snapshot, runtimeImplementations(snapshot));
    QVariantMap formatted;
    if (error.code.isEmpty()) {
        for (const auto &node : snapshot.nodes) {
            bool hasValuePort = false;
            for (const auto &port : node.ports)
                hasValuePort = hasValuePort || (port.key == valueKey && port.kind == PortKind::Data);
            if (!hasValuePort || node.typeId == setType)
                continue;
            const auto result = m_previewRuntime.evaluate({node.id, valueKey});
            auto value = result.value;
            if (result.error.code == QStringLiteral("runtime.output_unavailable")) {
                value = m_executionResultValues.value(node.id);
                if (!value.isValid())
                    continue;
            } else if (!result.error.code.isEmpty()) {
                if (result.error.code != QStringLiteral("runtime.unconnected_input")
                    && result.error.code != QStringLiteral("runtime.unconfigured_port")) {
                    formatted.insert(node.id.toString(QUuid::WithoutBraces), result.error.message);
                }
                continue;
            }
            formatted.insert(node.id.toString(QUuid::WithoutBraces), displayValue(value));
        }
    } else {
        report(error.message);
    }
    if (m_values != formatted) {
        m_values.swap(formatted);
        emit previewValuesChanged();
    }
}

void DemoGraph::speakerChanged(const QString &targetId, const QStringList &keys)
{
    if (!m_suppressPropertyEvents) {
        const auto *speaker = m_speakers.value(targetId);
        if (speaker) {
            const auto state = speaker->state();
            const auto nodes = m_document.data().nodes;
            const auto connections = m_document.data().connections;
            GraphSnapshot snapshot;
            for (const auto &node : nodes) {
                if (node.typeId != propertyEventType || node.parameterOverrides.value(targetKey) != targetId)
                    continue;
                const auto member = node.parameterOverrides.value(memberKey).toString();
                if (!keys.contains(member) || !state.contains(member))
                    continue;
                if (std::none_of(connections.cbegin(), connections.cend(), [&](const ConnectionData &connection) {
                        return connection.source.nodeId == node.id && connection.source.portKey == valueKey;
                    }))
                    continue;
                if (snapshot.graphId.isNull())
                    snapshot = m_document.snapshot();
                auto *runtime = new GraphRuntime(this);
                connect(runtime, &GraphRuntime::nodeExecutionChanged, this, &DemoGraph::nodeExecutionChanged);
                connect(runtime, &GraphRuntime::executionOutputsPublished, this,
                        [this, runtime](const QUuid &, const QVariantMap &, quint64 revision) {
                    captureResultValues(*runtime, revision);
                });
                connect(runtime, &GraphRuntime::executionFinished, this, [this, runtime](const QUuid &, const Diagnostic &error) {
                    executionFinished(runtime, error);
                });
                if (!startExecution(*runtime, snapshot, node.id, {{valueKey, state.value(member)}}))
                    runtime->deleteLater();
            }
        }
    }
    emit speakerStateChanged(targetId);
    updateValues();
}

void DemoGraph::syncSpeakers(const GraphChangeSet &change)
{
    // 编辑、加载和撤销在这里同步对象配置，不产生业务事件。
    QScopedValueRollback<bool> suppress(m_suppressPropertyEvents, true);
    QSet<QString> current;
    for (const auto &entry : existingSpeakers)
        current.insert(entry.id);
    for (const auto &node : m_document.data().nodes) {
        if (node.typeId != speakerType)
            continue;
        const auto target = QStringLiteral("node:%1:%2").arg(node.typeId, node.id.toString(QUuid::WithoutBraces));
        current.insert(target);
        auto *speaker = m_speakers.value(target);
        if (!speaker) {
            speaker = new DemoSpeaker(*m_registry.find(speakerType), m_document.parameterValue(node.id, durationKey).toInt(), this);
            m_speakers.insert(target, speaker);
            connect(speaker, &DemoSpeaker::stateChanged, this, [this, target](const QStringList &keys) {
                speakerChanged(target, keys);
            });
        } else {
            bool durationChanged = change.reset;
            for (const auto &entry : change.changedNodes)
                durationChanged = durationChanged || (entry.nodeId == node.id && entry.parameterKeys.contains(durationKey));
            if (durationChanged)
                report(speaker->writeState(durationKey, m_document.parameterValue(node.id, durationKey)).message);
        }
    }
    for (auto it = m_speakers.begin(); it != m_speakers.end();) {
        if (current.contains(it.key())) {
            ++it;
        } else {
            auto *speaker = it.value();
            it = m_speakers.erase(it);
            speaker->invoke(QStringLiteral("stop"), QUuid::createUuid(), {}, [](const QVariantMap &, const Diagnostic &) {});
            speaker->deleteLater();
        }
    }
    emit speakerNodesChanged();
}

bool DemoGraph::report(const QString &error, const QUuid &nodeId)
{
    const auto errorNodeId = error.isEmpty() ? QUuid{} : nodeId;
    if (m_error != error || m_errorNodeId != errorNodeId) {
        m_error = error;
        m_errorNodeId = errorNodeId;
        emit errorChanged();
    }
    return error.isEmpty();
}
