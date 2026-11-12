#include "DemoGraph.h"

#include <QFileInfo>
#include <QLocale>
#include <QMetaType>
#include <QSet>
#include <QtMath>

using namespace Blueprint;

namespace {

const auto constantType = QStringLiteral("demo.constant");
const auto stringConstantType = QStringLiteral("demo.stringConstant");
const auto optionConstantType = QStringLiteral("demo.optionConstant");
const auto boolConstantType = QStringLiteral("demo.boolConstant");
const auto additionType = QStringLiteral("demo.add");
const auto compareType = QStringLiteral("demo.compare");
const auto greaterType = QStringLiteral("demo.greater");
const auto lessType = QStringLiteral("demo.less");
const auto equalType = QStringLiteral("demo.equal");
const auto andType = QStringLiteral("demo.and");
const auto orType = QStringLiteral("demo.or");
const auto notType = QStringLiteral("demo.not");
const auto resultType = QStringLiteral("demo.result");
const auto textResultType = QStringLiteral("demo.textResult");
const auto speakerType = QStringLiteral("demo.speaker");
const auto speakerReferenceType = QStringLiteral("demo.speakerReference");
const auto triggerType = QStringLiteral("demo.trigger");
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
const auto resultCategory = QStringLiteral("results");
const auto operatorKey = QStringLiteral("operator");
const auto valueKey = QStringLiteral("value");
const auto inputA = QStringLiteral("A");
const auto inputB = QStringLiteral("B");
const auto numberType = QStringLiteral("number");
const auto stringType = QStringLiteral("string");
const auto boolType = QStringLiteral("bool");
const auto autoOption = QStringLiteral("auto");
const auto manualOption = QStringLiteral("manual");
const auto durationKey = QStringLiteral("testDurationMs");
const auto playingKey = QStringLiteral("playing");
const auto targetKey = QStringLiteral("target");
const auto objectIdKey = QStringLiteral("objectId");
const auto memberKey = QStringLiteral("member");
const auto execIn = QStringLiteral("execIn");
const auto execOut = QStringLiteral("execOut");
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
            return {QStringLiteral("demo.read_only_property"), DemoGraph::tr("属性不可写：%1").arg(key), {}, key};
        const auto error = NodeRegistry::validateValues({property.value}, {{key, value}});
        if (!error.code.isEmpty())
            return error;
        if (m_durationMs != value.toInt()) {
            m_durationMs = value.toInt();
            emit stateChanged({key});
        }
        return {};
    }
    return {QStringLiteral("demo.unknown_property"), DemoGraph::tr("未知属性：%1").arg(key), {}, key};
}

Diagnostic DemoSpeaker::invoke(const QString &key, const QUuid &callId,
                               std::function<void(Diagnostic)> complete)
{
    if (key == QStringLiteral("playTest")) {
        if (m_timer.isActive())
            return {QStringLiteral("demo.speaker_busy"), DemoGraph::tr("正在测试，请先停止或等待结束。")};
        m_callId = callId;
        m_complete = std::move(complete);
        m_timer.start(m_durationMs);
        emit stateChanged({playingKey});
    } else if (key == QStringLiteral("stop")) {
        if (m_timer.isActive())
            cancel(m_callId);
        complete({});
    } else {
        return {QStringLiteral("demo.unknown_method"), DemoGraph::tr("未知接口：%1").arg(key), {}, key};
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
    const PortDefinition output{valueKey, PortDirection::Output, numberType, tr("输出")};
    const PortDefinition textOutput{valueKey, PortDirection::Output, stringType, tr("输出")};
    const PortDefinition boolOutput{valueKey, PortDirection::Output, boolType, tr("输出")};
    const PortDefinition numberA{inputA, PortDirection::Input, numberType};
    const PortDefinition numberB{inputB, PortDirection::Input, numberType};
    const PortDefinition boolA{inputA, PortDirection::Input, boolType};
    const PortDefinition boolB{inputB, PortDirection::Input, boolType};
    const PortDefinition execute{execIn, PortDirection::Input, {}, tr("执行"), PortKind::Execution};
    const PortDefinition next{execOut, PortDirection::Output, {}, tr("继续"), PortKind::Execution};
    const ParameterDefinition target{targetKey, stringType, QStringLiteral("")};
    const ParameterDefinition duration{durationKey, numberType, 2000.0, {}, tr("测试时长"), {},
                                       minDuration, maxDuration, true};
    ParameterDefinition durationInput = duration;
    durationInput.key = valueKey;
    durationInput.defaultValue = 3000.0;
    QVector<NodeTypeDefinition> definitions{
        {constantType, tr("数值常量"), {output}, {{valueKey, numberType, 0.0, {}, tr("数值")}}, valueCategory,
         InstancePolicy::Multiple, {}, tr("输出可编辑的数值"), QStringLiteral("#")},
        {stringConstantType, tr("字符串常量"), {textOutput},
         {{valueKey, stringType, tr("示例文本"), {}, tr("文本")}}, valueCategory,
         InstancePolicy::Multiple, {}, tr("输出文本"), QStringLiteral("T")},
        {optionConstantType, tr("选项常量"), {textOutput},
         {{valueKey, stringType, autoOption, {autoOption, manualOption}, tr("选项")}}, valueCategory,
         InstancePolicy::Multiple, {}, tr("输出所选选项的值"), QStringLiteral("▾")},
        {boolConstantType, tr("布尔常量"), {boolOutput}, {{valueKey, boolType, false, {}, tr("布尔值")}}, valueCategory,
         InstancePolicy::Multiple, {}, tr("输出真或假"), QStringLiteral("✓")},
        {additionType, tr("加法"), {numberA, numberB, output}, {}, logicCategory,
         InstancePolicy::Multiple, {}, tr("相加两个数值输入"), QStringLiteral("+")},
        {compareType, tr("比较"),
         {{inputA, PortDirection::Input, anyValueType}, {inputB, PortDirection::Input, anyValueType}, boolOutput},
         {{operatorKey, stringType, QStringLiteral("eq"),
           {QStringLiteral("gt"), QStringLiteral("ge"), QStringLiteral("lt"), QStringLiteral("le"),
            QStringLiteral("eq"), QStringLiteral("ne")}, tr("运算符")}}, logicCategory,
         InstancePolicy::Multiple, {}, tr("选择运算符比较两个输入"), QStringLiteral("≷")},
        {greaterType, tr("大于"), {numberA, numberB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, tr("判断 A 是否大于 B"), QStringLiteral(">")},
        {lessType, tr("小于"), {numberA, numberB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, tr("判断 A 是否小于 B"), QStringLiteral("<")},
        {equalType, tr("等于"), {numberA, numberB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, tr("判断 A 是否等于 B"), QStringLiteral("=")},
        {andType, tr("且"), {boolA, boolB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, tr("两个输入都为真"), QStringLiteral("∧")},
        {orType, tr("或"), {boolA, boolB, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, tr("至少一个输入为真"), QStringLiteral("∨")},
        {notType, tr("非"), {boolA, boolOutput}, {}, logicCategory,
         InstancePolicy::Multiple, {}, tr("对输入取反"), QStringLiteral("¬")},
        {resultType, tr("结果"), {{valueKey, PortDirection::Input, numberType, tr("输入")}}, {}, resultCategory,
         InstancePolicy::Multiple, {}, tr("显示收到的数值"), QStringLiteral("=")},
        {textResultType, tr("文本结果"), {{valueKey, PortDirection::Input, stringType, tr("输入")}}, {}, resultCategory,
         InstancePolicy::Multiple, {}, tr("显示收到的文本"), QStringLiteral("=")},
        {speakerType, tr("模拟音箱"), {}, {duration}, objectCategory,
         InstancePolicy::Multiple, {}, tr("测试和停止播放"), QStringLiteral("♪"),
         {{{playingKey, boolType, false, {}, tr("播放状态")}, false}, {duration, true}},
         {{QStringLiteral("playTest"), tr("测试播放")}, {QStringLiteral("stop"), tr("停止")}}},
        {speakerReferenceType, tr("已有音箱"), {}, {{objectIdKey, stringType, {}}}, existingObjectCategory,
         InstancePolicy::UniqueByParameter, objectIdKey, tr("显示和控制已有音箱"), QStringLiteral("♪")},
        {triggerType, tr("手动触发"), {next}, {}, flowCategory,
         InstancePolicy::Multiple, {}, tr("开始执行流程"), QStringLiteral("▶")},
        {readPropertyType, tr("读取属性"), {},
         {target, {memberKey, stringType, QStringLiteral("")}}, operationCategory,
         InstancePolicy::Multiple, {}, tr("读取所选对象的属性"), QStringLiteral("↗")},
        {setType, tr("设置属性"), {execute, {valueKey, PortDirection::Input, numberType}, next},
         {target, {memberKey, stringType, durationKey, {durationKey}}, durationInput}, operationCategory,
         InstancePolicy::Multiple, {}, tr("写入运行时测试时长"), QStringLiteral("↘")},
        {callType, tr("调用接口"), {execute, next},
         {target, {memberKey, stringType, QStringLiteral("playTest")}}, operationCategory,
         InstancePolicy::Multiple, {}, tr("测试播放或停止"), QStringLiteral("▷")},
        {boolResultType, tr("状态结果"), {{valueKey, PortDirection::Input, boolType, tr("输入")}}, {}, resultCategory,
         InstancePolicy::Multiple, {}, tr("显示布尔值"), QStringLiteral("=")}
    };
    for (auto &definition : definitions) {
        if (definition.categoryId == valueCategory) {
            for (const auto &parameter : definition.parameters)
                definition.properties.append({parameter, false});
        }
        if (definition.typeId == readPropertyType) {
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
                return QVector<PortDefinition>{{valueKey, PortDirection::Output, valueType, tr("输出")}};
            };
        } else if (definition.typeId == setType) {
            definition.resolvePorts = [execute, next, durationInput](const NodeData &node) {
                PortDefinition input{valueKey, PortDirection::Input, numberType, DemoGraph::tr("输入")};
                input.defaultValue = node.parameterOverrides.value(valueKey, durationInput.defaultValue);
                return QVector<PortDefinition>{execute, input, next};
            };
        }
        const auto error = m_registry.add(definition);
        if (!error.code.isEmpty())
            qFatal("Invalid demo definition: %s", qPrintable(error.message));
    }
    for (const auto &entry : existingSpeakers) {
        auto *speaker = new DemoSpeaker(*m_registry.find(speakerType), entry.durationMs, this);
        m_speakers.insert(entry.id, speaker);
        connect(speaker, &DemoSpeaker::stateChanged, this, [this, id = entry.id] {
            emit speakerStateChanged(id);
            updateValues();
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
        {speaker, speakerType, {800, 42}, {}},
        {QUuid::createUuid(), speakerType, {800, 294}, {{durationKey, 4000.0}}},
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
    connect(&m_runtime, &GraphRuntime::executionFinished, this, [this](const QUuid &, const Diagnostic &error) {
        report(error.message);
        updateValues();
    });
    connect(&m_document, &GraphDocument::changed, this, [this](const GraphChangeSet &change) {
        report({});
        if (change.reset)
            m_runtime.stop();
        if (change.reset || !change.addedNodeIds.isEmpty() || !change.removedNodeIds.isEmpty()
            || !change.changedNodes.isEmpty()) {
            syncSpeakers(change);
            emit placedObjectsChanged();
            emit readTargetsChanged();
        }
        if (change.reset || !change.addedNodeIds.isEmpty() || !change.removedNodeIds.isEmpty()
            || !change.addedConnectionIds.isEmpty() || !change.removedConnectionIds.isEmpty()
            || (!change.changedNodes.isEmpty() && !change.changedNodes.first().parameterKeys.isEmpty())) {
            updateValues();
        }
    });
}

DemoGraph::~DemoGraph()
{
    m_runtime.stop();
    m_previewRuntime.stop();
}

QObject *DemoGraph::session() { return &m_session; }
QVariantMap DemoGraph::previewValues() const { return m_values; }
QString DemoGraph::error() const { return m_error; }
QString DemoGraph::fileName() const { return m_fileName; }

QVariantList DemoGraph::palette() const
{
    QHash<QString, QVariantList> nodesByCategory;
    QStringList categoryIds{existingObjectCategory, objectCategory, valueCategory, logicCategory,
                            operationCategory, flowCategory, resultCategory};
    const QHash<QString, QString> categoryTitles{
        {existingObjectCategory, tr("已有对象")}, {objectCategory, tr("对象")}, {valueCategory, tr("值")},
        {logicCategory, tr("运算与判断")}, {operationCategory, tr("对象操作")},
        {flowCategory, tr("流程控制")}, {resultCategory, tr("结果与调试")}
    };
    for (const auto &definition : m_registry.definitions()) {
        if (definition.typeId == speakerReferenceType || definition.typeId == greaterType
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
        options.append(QVariantMap{{QStringLiteral("value"), QStringLiteral("node:%1:%2").arg(node.typeId, id)},
                                   {QStringLiteral("label"), tr("模拟音箱 · %1").arg(id.left(8))}});
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
        options.append(QVariantMap{{QStringLiteral("value"), QStringLiteral("node:%1:%2").arg(node.typeId, id)},
                                   {QStringLiteral("label"), tr("%1 · %2").arg(definition->displayName, id.left(8))}});
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
    const auto error = speaker->invoke(actionKey, QUuid::createUuid(), [this](const Diagnostic &result) {
        if (!result.code.isEmpty() && result.code != QStringLiteral("demo.cancelled"))
            report(result.message);
    });
    return report(error.message);
}

QVariantList DemoGraph::operationMembers(const QString &typeId, const QString &targetId) const
{
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

QString DemoGraph::targetType(const QString &targetId) const
{
    const auto parts = targetId.split(QLatin1Char(':'));
    if (parts.size() != 3 || (parts.first() != QStringLiteral("node") && parts.first() != QStringLiteral("host"))
        || parts.last().isEmpty())
        return {};
    return parts.at(1);
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

RuntimeImplementations DemoGraph::runtimeImplementations(const GraphSnapshot &snapshot)
{
    RuntimeImplementations implementations;
    for (const auto &node : snapshot.nodes) {
        if (node.typeId == constantType || node.typeId == stringConstantType || node.typeId == optionConstantType
            || node.typeId == boolConstantType) {
            implementations.evaluators.insert(node.typeId, [](const QVariantMap &parameters, const QVariantMap &) {
                return EvaluationResult{{{valueKey, parameters.value(valueKey)}}, {}};
            });
        } else if (node.typeId == additionType || node.typeId == compareType || node.typeId == greaterType
                   || node.typeId == lessType || node.typeId == equalType || node.typeId == andType
                   || node.typeId == orType || node.typeId == notType) {
            implementations.evaluators.insert(node.typeId, [typeId = node.typeId](const QVariantMap &parameters, const QVariantMap &inputs) {
                const auto a = inputs.value(inputA);
                const auto b = inputs.value(inputB);
                QVariant output;
                if (typeId == additionType)
                    output = a.toDouble() + b.toDouble();
                else if (typeId == compareType) {
                    const auto operation = parameters.value(operatorKey).toString();
                    bool result = false;
                    if (NodeRegistry::acceptsValue(numberType, a) && NodeRegistry::acceptsValue(numberType, b)) {
                        const double left = a.toDouble();
                        const double right = b.toDouble();
                        if (operation == QStringLiteral("gt"))
                            result = left > right;
                        else if (operation == QStringLiteral("ge"))
                            result = left >= right;
                        else if (operation == QStringLiteral("lt"))
                            result = left < right;
                        else if (operation == QStringLiteral("le"))
                            result = left <= right;
                        else if (operation == QStringLiteral("eq"))
                            result = left == right;
                        else if (operation == QStringLiteral("ne"))
                            result = left != right;
                    } else if (a.userType() == b.userType()
                               && (a.userType() == QMetaType::QString || a.userType() == QMetaType::Bool)) {
                        if (operation == QStringLiteral("eq"))
                            result = a == b;
                        else if (operation == QStringLiteral("ne"))
                            result = a != b;
                    }
                    // 异类值及尚未支持的同类运算保留 false，不做隐式转换。
                    output = result;
                } else if (typeId == greaterType)
                    output = a.toDouble() > b.toDouble();
                else if (typeId == lessType)
                    output = a.toDouble() < b.toDouble();
                else if (typeId == equalType)
                    output = a.toDouble() == b.toDouble();
                else if (typeId == andType)
                    output = a.toBool() && b.toBool();
                else if (typeId == orType)
                    output = a.toBool() || b.toBool();
                else
                    output = !a.toBool();
                return EvaluationResult{{{valueKey, output}}, {}};
            });
        }
    }
    QHash<QString, QVariantMap> configurations;
    for (const auto &node : snapshot.nodes) {
        configurations.insert(QStringLiteral("node:%1:%2").arg(node.typeId, node.id.toString(QUuid::WithoutBraces)),
                              node.parameters);
    }
    implementations.evaluators.insert(readPropertyType,
        [this, configurations](const QVariantMap &parameters, const QVariantMap &) {
            const auto target = parameters.value(targetKey).toString();
            const auto member = parameters.value(memberKey).toString();
            const auto *speaker = m_speakers.value(target);
            const auto state = targetType(target) == speakerType ? (speaker ? speaker->state() : QVariantMap{}) : configurations.value(target);
            const auto value = state.value(member);
            if (!value.isValid()) {
                return EvaluationResult{{}, {QStringLiteral("demo.unavailable_property"),
                    tr("目标对象或属性不可用：%1 / %2").arg(target, member), {}, member}};
            }
            return EvaluationResult{{{valueKey, value}}, {}};
        });
    implementations.actions.insert(setType, [this](const ExecutionContext &context, std::function<void(ActionResult)> complete) {
        const auto target = context.parameters.value(targetKey).toString();
        auto *speaker = m_speakers.value(target);
        const auto error = speaker
            ? speaker->writeState(context.parameters.value(memberKey).toString(), context.inputs.value(valueKey))
            : Diagnostic{QStringLiteral("demo.unavailable_object"), tr("音箱对象已失效。"), context.nodeId, targetKey};
        complete({execOut, {}, error});
    });
    implementations.actions.insert(callType, [this](const ExecutionContext &context, std::function<void(ActionResult)> complete) {
        auto *speaker = m_speakers.value(context.parameters.value(targetKey).toString());
        if (!speaker) {
            complete({{}, {}, {QStringLiteral("demo.unavailable_object"), tr("音箱对象已失效。"), context.nodeId, targetKey}});
            return;
        }
        const auto error = speaker->invoke(context.parameters.value(memberKey).toString(), context.callId,
            [complete](const Diagnostic &result) { complete({execOut, {}, result}); });
        if (!error.code.isEmpty())
            complete({{}, {}, error});
    });
    implementations.cancellations.insert(callType, [this](const QUuid &callId) {
        for (auto *speaker : m_speakers)
            speaker->cancel(callId);
    });
    return implementations;
}

bool DemoGraph::run(const QString &triggerId)
{
    const QUuid triggerNodeId(triggerId);
    const auto *trigger = m_document.findNode(triggerNodeId);
    if (!trigger || trigger->typeId != triggerType)
        return report(tr("手动触发节点已失效。"));
    const auto snapshot = m_document.snapshot();
    m_runtime.stop();
    const auto error = m_runtime.start(snapshot, runtimeImplementations(snapshot));
    if (!report(error.message))
        return false;
    return report(m_runtime.execute({triggerNodeId, execOut}).error.message);
}

bool DemoGraph::open(const QUrl &url)
{
    if (!report(m_document.loadFile(url.toLocalFile()).message))
        return false;
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
            if (!result.error.code.isEmpty()) {
                if (result.error.code != QStringLiteral("runtime.unconnected_input")
                    && result.error.code != QStringLiteral("runtime.unconfigured_port")) {
                    formatted.insert(node.id.toString(QUuid::WithoutBraces), result.error.message);
                }
                continue;
            }
            const auto &value = result.value;
            QString display;
            if (value.userType() == QMetaType::Bool)
                display = value.toBool() ? tr("是") : tr("否");
            else if (value.userType() == QMetaType::QString)
                display = value.toString();
            else
                display = QLocale::c().toString(value.toDouble(), 'g', 12);
            formatted.insert(node.id.toString(QUuid::WithoutBraces), display.isEmpty() ? tr("（空字符串）") : display);
        }
    } else {
        report(error.message);
    }
    if (m_values != formatted) {
        m_values.swap(formatted);
        emit previewValuesChanged();
    }
}

void DemoGraph::syncSpeakers(const GraphChangeSet &change)
{
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
            connect(speaker, &DemoSpeaker::stateChanged, this, [this, target] {
                emit speakerStateChanged(target);
                updateValues();
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
            speaker->invoke(QStringLiteral("stop"), QUuid::createUuid(), [](const Diagnostic &) {});
            speaker->deleteLater();
        }
    }
    emit speakerNodesChanged();
}

bool DemoGraph::report(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
    return error.isEmpty();
}
