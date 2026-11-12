#include "DemoGraph.h"

#include <QFileInfo>
#include <QLocale>
#include <QMetaType>
#include <QSet>
#include <QTimer>
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
const auto readBoolType = QStringLiteral("demo.readBool");
const auto readNumberType = QStringLiteral("demo.readNumber");
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
const auto valueKey = QStringLiteral("value");
const auto operatorKey = QStringLiteral("operator");
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
const auto memberTypeKey = QStringLiteral("memberType");
const auto execIn = QStringLiteral("execIn");
const auto execOut = QStringLiteral("execOut");
constexpr int minDuration = 100;
constexpr int maxDuration = 10000;

// 宿主对象标识与旧图中的节点 UUID 使用不同格式。
const struct {
    QString id;
    const char *label;
    int durationMs;
} existingSpeakers[] = {
    {QStringLiteral("host:speaker-a"), QT_TRANSLATE_NOOP("DemoGraph", "音箱 A"), 2000},
    {QStringLiteral("host:speaker-b"), QT_TRANSLATE_NOOP("DemoGraph", "音箱 B"), 4000}
};

struct ReadableProperty
{
    QString objectType;
    QString key;
    const char *label;
    QString valueType;
    bool runtime;
};

// 由宿主声明可读取的成员及其来源，读取节点只保存绑定。
const ReadableProperty readableProperties[] = {
    {speakerType, playingKey, QT_TRANSLATE_NOOP("DemoGraph", "播放状态"), boolType, true},
    {speakerType, durationKey, QT_TRANSLATE_NOOP("DemoGraph", "测试时长"), numberType, true},
    {constantType, valueKey, QT_TRANSLATE_NOOP("DemoGraph", "数值"), numberType, false},
    {stringConstantType, valueKey, QT_TRANSLATE_NOOP("DemoGraph", "文本"), stringType, false},
    {optionConstantType, valueKey, QT_TRANSLATE_NOOP("DemoGraph", "选项"), stringType, false},
    {boolConstantType, valueKey, QT_TRANSLATE_NOOP("DemoGraph", "布尔值"), boolType, false}
};

const ReadableProperty *readableProperty(const QString &typeId, const QString &key)
{
    for (const auto &property : readableProperties) {
        if (property.objectType == typeId && property.key == key)
            return &property;
    }
    return nullptr;
}

bool isReader(const QString &typeId)
{
    return typeId == readPropertyType || typeId == readBoolType || typeId == readNumberType;
}

class SpeakerBehavior final : public NodeBehavior
{
public:
    explicit SpeakerBehavior(int durationMs) : m_durationMs(durationMs)
    {
        m_timer.setSingleShot(true);
        connect(&m_timer, &QTimer::timeout, this, [this] { emit stateChanged({playingKey}); });
    }

    QVariantMap state() const override
    {
        return {{playingKey, m_timer.isActive()}, {durationKey, m_durationMs}};
    }

    QString writeState(const QString &key, const QVariant &value) override
    {
        if (key != durationKey)
            return NodeBehavior::writeState(key, value);
        const double duration = value.toDouble();
        if (!NodeRegistry::acceptsValue(numberType, value) || duration < minDuration
            || duration > maxDuration || duration != qFloor(duration))
            return DemoGraph::tr("测试时长必须为 %1–%2 毫秒的整数。").arg(minDuration).arg(maxDuration);
        if (m_durationMs != duration) {
            m_durationMs = static_cast<int>(duration);
            emit stateChanged({durationKey});
        }
        return {};
    }

    QString invoke(const QString &actionKey) override
    {
        if (actionKey == QStringLiteral("playTest")) {
            if (m_timer.isActive())
                return DemoGraph::tr("正在测试，请先停止或等待结束。");
            m_timer.start(m_durationMs);
        } else if (actionKey == QStringLiteral("stop")) {
            if (!m_timer.isActive())
                return {};
            m_timer.stop();
        } else {
            return DemoGraph::tr("未知动作：%1").arg(actionKey);
        }
        emit stateChanged({playingKey});
        return {};
    }

private:
    int m_durationMs;
    QTimer m_timer;
};

NodeRegistry demoRegistry()
{
    const PortDefinition output{valueKey, PortDirection::Output, numberType};
    const PortDefinition textOutput{valueKey, PortDirection::Output, stringType};
    const PortDefinition boolOutput{valueKey, PortDirection::Output, boolType};
    const PortDefinition propertyOutput{valueKey, PortDirection::Output, {}, memberTypeKey};
    const QString noMember = QStringLiteral("");
    const QStringList readableTypes{noMember, boolType, numberType, stringType};
    const PortDefinition numberA{inputA, PortDirection::Input, numberType};
    const PortDefinition numberB{inputB, PortDirection::Input, numberType};
    const PortDefinition boolA{inputA, PortDirection::Input, boolType};
    const PortDefinition boolB{inputB, PortDirection::Input, boolType};
    const PortDefinition execute{execIn, PortDirection::Input, executionPortType};
    const PortDefinition next{execOut, PortDirection::Output, executionPortType};
    const ParameterDefinition target{targetKey, stringType, QStringLiteral("")};
    NodeRegistry registry;
    registry.add({constantType, DemoGraph::tr("数值常量"), {output}, {{valueKey, numberType, 0.0}}, valueCategory});
    registry.add({stringConstantType, DemoGraph::tr("字符串常量"), {textOutput},
                  {{valueKey, stringType, DemoGraph::tr("示例文本")}}, valueCategory});
    registry.add({optionConstantType, DemoGraph::tr("选项常量"), {textOutput},
                  {{valueKey, stringType, autoOption, {autoOption, manualOption}}}, valueCategory});
    registry.add({boolConstantType, DemoGraph::tr("布尔常量"), {boolOutput},
                  {{valueKey, boolType, false}}, valueCategory});
    registry.add({additionType, DemoGraph::tr("加法"), {numberA, numberB, output}, {}, logicCategory});
    registry.add({compareType, DemoGraph::tr("比较"),
                  {{inputA, PortDirection::Input, anyValueType}, {inputB, PortDirection::Input, anyValueType}, boolOutput},
                  {{operatorKey, stringType, QStringLiteral("eq"),
                    {QStringLiteral("gt"), QStringLiteral("ge"), QStringLiteral("lt"), QStringLiteral("le"),
                     QStringLiteral("eq"), QStringLiteral("ne")}}}, logicCategory});
    registry.add({greaterType, DemoGraph::tr("大于"), {numberA, numberB, boolOutput}, {}, logicCategory});
    registry.add({lessType, DemoGraph::tr("小于"), {numberA, numberB, boolOutput}, {}, logicCategory});
    registry.add({equalType, DemoGraph::tr("等于"), {numberA, numberB, boolOutput}, {}, logicCategory});
    registry.add({andType, DemoGraph::tr("且"), {boolA, boolB, boolOutput}, {}, logicCategory});
    registry.add({orType, DemoGraph::tr("或"), {boolA, boolB, boolOutput}, {}, logicCategory});
    registry.add({notType, DemoGraph::tr("非"), {boolA, boolOutput}, {}, logicCategory});
    registry.add({resultType, DemoGraph::tr("结果"), {{valueKey, PortDirection::Input, numberType}}, {}, resultCategory});
    registry.add({textResultType, DemoGraph::tr("文本结果"), {{valueKey, PortDirection::Input, stringType}}, {}, resultCategory});
    registry.add({speakerType, DemoGraph::tr("模拟音箱"), {}, {
        {durationKey, numberType, 2000.0}
    }, objectCategory});
    registry.add({speakerReferenceType, DemoGraph::tr("已有音箱"), {}, {{objectIdKey, stringType, {}}},
                  existingObjectCategory, InstancePolicy::UniqueByParameter, objectIdKey});
    registry.add({triggerType, DemoGraph::tr("手动触发"), {next}, {}, flowCategory});
    registry.add({readPropertyType, DemoGraph::tr("读取属性"), {propertyOutput},
                  {target, {memberKey, stringType, noMember}, {memberTypeKey, stringType, noMember, readableTypes}},
                  operationCategory});
    // 旧图中的两种读取节点使用原默认属性和端口类型。
    registry.add({readBoolType, DemoGraph::tr("读取属性"), {propertyOutput},
                  {target, {memberKey, stringType, playingKey}, {memberTypeKey, stringType, boolType, readableTypes}},
                  operationCategory});
    registry.add({readNumberType, DemoGraph::tr("读取属性"), {propertyOutput},
                  {target, {memberKey, stringType, durationKey}, {memberTypeKey, stringType, numberType, readableTypes}},
                  operationCategory});
    registry.add({setType, DemoGraph::tr("设置属性"), {execute, {valueKey, PortDirection::Input, numberType}, next},
                  {target, {memberKey, stringType, durationKey, {durationKey}}, {valueKey, numberType, 3000.0}}, operationCategory});
    registry.add({callType, DemoGraph::tr("调用接口"), {execute, next},
                  {target, {memberKey, stringType, QStringLiteral("playTest"), {QStringLiteral("playTest"), QStringLiteral("stop")}}},
                  operationCategory});
    registry.add({boolResultType, DemoGraph::tr("状态结果"), {{valueKey, PortDirection::Input, boolType}}, {}, resultCategory});
    return registry;
}

} // namespace

DemoGraph::DemoGraph(QObject *parent)
    : QObject(parent), m_document(demoRegistry()), m_session(m_document)
{
    for (const auto &entry : existingSpeakers) {
        auto *speaker = new SpeakerBehavior(entry.durationMs);
        speaker->setParent(this);
        m_existingSpeakers.insert(entry.id, speaker);
        connect(speaker, &NodeBehavior::stateChanged, this, [this, id = entry.id] {
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
    const QVariantMap bound{{targetKey, speaker.toString(QUuid::WithoutBraces)}};
    m_document.replaceData({m_document.data().id, {
        {first, constantType, {42, 104}, {{valueKey, 12.0}}},
        {second, constantType, {42, 294}, {{valueKey, 30.0}}},
        {addition, additionType, {300, 192}, {}},
        {result, resultType, {558, 192}, {}},
        {speaker, speakerType, {800, 42}, {}},
        {QUuid::createUuid(), speakerType, {800, 294}, {{durationKey, 4000.0}}},
        {trigger, triggerType, {42, 420}, {}},
        {set, setType, {300, 420}, bound},
        {call, callType, {558, 420}, bound},
        {read, readPropertyType, {300, 580}, {
            {targetKey, speaker.toString(QUuid::WithoutBraces)}, {memberKey, playingKey}, {memberTypeKey, boolType}
        }},
        {status, boolResultType, {558, 580}, {}}
    }, {
        {QUuid::createUuid(), {first, valueKey}, {addition, inputA}},
        {QUuid::createUuid(), {second, valueKey}, {addition, inputB}},
        {QUuid::createUuid(), {addition, valueKey}, {result, valueKey}},
        {QUuid::createUuid(), {trigger, execOut}, {set, execIn}},
        {QUuid::createUuid(), {set, execOut}, {call, execIn}},
        {QUuid::createUuid(), {read, valueKey}, {status, valueKey}}
    }});
    syncSpeakers();
    updateValues();
    connect(&m_runtime, &GraphRuntime::stateChanged, this, [this](const QUuid &nodeId, const QStringList &) {
        emit speakerStateChanged(nodeId.toString(QUuid::WithoutBraces));
        updateValues();
    });
    connect(&m_runtime, &GraphRuntime::reset, this, &DemoGraph::speakerNodesChanged);
    connect(&m_document, &GraphDocument::changed, this, [this](const GraphChangeSet &change) {
        report({});
        emit placedObjectsChanged();
        if (change.reset)
            m_runtime.stop();
        if (change.reset || !change.addedNodeIds.isEmpty() || !change.removedNodeIds.isEmpty()) {
            syncSpeakers();
            emit readTargetsChanged();
        }
        if (change.reset || !change.addedNodeIds.isEmpty() || !change.removedNodeIds.isEmpty()
            || !change.addedConnectionIds.isEmpty() || !change.removedConnectionIds.isEmpty()
            || (!change.changedNodes.isEmpty() && !change.changedNodes.first().parameterKeys.isEmpty())) {
            updateValues();
        }
    });
}

QObject *DemoGraph::session() { return &m_session; }
QVariantMap DemoGraph::previewValues() const { return m_values; }
QString DemoGraph::error() const { return m_error; }
QString DemoGraph::fileName() const { return m_fileName; }

QVariantList DemoGraph::palette() const
{
    const struct {
        QString typeId;
        QString description;
        QString symbol;
    } entries[] = {
        {constantType, tr("输出可编辑的数值"), QStringLiteral("#")},
        {stringConstantType, tr("输出文本"), QStringLiteral("T")},
        {optionConstantType, tr("输出所选选项的值"), QStringLiteral("▾")},
        {boolConstantType, tr("输出真或假"), QStringLiteral("✓")},
        {additionType, tr("相加两个数值输入"), QStringLiteral("+")},
        {compareType, tr("选择运算符比较两个输入"), QStringLiteral("≷")},
        {andType, tr("两个输入都为真"), QStringLiteral("∧")},
        {orType, tr("至少一个输入为真"), QStringLiteral("∨")},
        {notType, tr("对输入取反"), QStringLiteral("¬")},
        {resultType, tr("显示收到的数值"), QStringLiteral("=")},
        {textResultType, tr("显示收到的文本"), QStringLiteral("=")},
        {speakerType, tr("测试和停止播放"), QStringLiteral("♪")},
        {triggerType, tr("开始执行流程"), QStringLiteral("▶")},
        {readPropertyType, tr("读取所选对象的属性"), QStringLiteral("↗")},
        {setType, tr("写入运行时测试时长"), QStringLiteral("↘")},
        {callType, tr("测试播放或停止"), QStringLiteral("▷")},
        {boolResultType, tr("显示布尔值"), QStringLiteral("=")}
    };
    QHash<QString, QVariantList> nodesByCategory;
    for (const auto &entry : entries) {
        const auto *definition = m_document.findNodeType(entry.typeId);
        if (!definition)
            continue;
        nodesByCategory[definition->categoryId].append(QVariantMap{
            {QStringLiteral("type"), definition->typeId},
            {QStringLiteral("title"), definition->displayName},
            {QStringLiteral("description"), entry.description},
            {QStringLiteral("symbol"), entry.symbol}
        });
    }

    for (const auto &entry : existingSpeakers) {
        nodesByCategory[existingObjectCategory].append(QVariantMap{
            {QStringLiteral("type"), speakerReferenceType},
            {QStringLiteral("title"), tr(entry.label)},
            {QStringLiteral("description"), tr("显示和控制已有音箱")},
            {QStringLiteral("symbol"), QStringLiteral("♪")},
            {QStringLiteral("parameters"), QVariantMap{{objectIdKey, entry.id}}}
        });
    }

    const QPair<QString, QString> categories[] = {
        {existingObjectCategory, tr("已有对象")},
        {objectCategory, tr("对象")},
        {valueCategory, tr("值")},
        {logicCategory, tr("运算与判断")},
        {operationCategory, tr("对象操作")},
        {flowCategory, tr("流程控制")},
        {resultCategory, tr("结果与调试")}
    };
    QVariantList groups;
    for (const auto &category : categories) {
        const auto nodes = nodesByCategory.value(category.first);
        if (!nodes.isEmpty()) {
            groups.append(QVariantMap{{QStringLiteral("id"), category.first},
                                      {QStringLiteral("title"), category.second},
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
    return {
        QVariantMap{{QStringLiteral("label"), tr("自动")}, {QStringLiteral("value"), autoOption}},
        QVariantMap{{QStringLiteral("label"), tr("手动")}, {QStringLiteral("value"), manualOption}}
    };
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
        options.append(QVariantMap{{QStringLiteral("value"), id},
                                   {QStringLiteral("label"), tr("模拟音箱 · %1").arg(id.left(8))}});
    }
    return options;
}

QVariantList DemoGraph::readTargetOptions() const
{
    QVariantList options = existingSpeakerOptions();
    for (const NodeData &node : m_document.data().nodes) {
        for (const auto &property : readableProperties) {
            if (property.objectType != node.typeId)
                continue;
            const auto id = node.id.toString(QUuid::WithoutBraces);
            const auto title = m_document.findNodeType(node.typeId)->displayName;
            options.append(QVariantMap{{QStringLiteral("value"), id},
                                       {QStringLiteral("label"), tr("%1 · %2").arg(title, id.left(8))}});
            break;
        }
    }
    return options;
}

QVariantMap DemoGraph::speakerState(const QString &targetId) const
{
    const auto *speaker = m_existingSpeakers.value(targetId);
    return speaker ? speaker->state() : m_runtime.state(QUuid(targetId));
}

bool DemoGraph::invokeSpeaker(const QString &targetId, const QString &actionKey)
{
    auto *speaker = m_existingSpeakers.value(targetId);
    return report(speaker ? speaker->invoke(actionKey) : m_runtime.invoke(QUuid(targetId), actionKey));
}

QVariantList DemoGraph::operationMembers(const QString &typeId) const
{
    if (typeId == setType)
        return {QVariantMap{{QStringLiteral("label"), tr("测试时长")}, {QStringLiteral("value"), durationKey}}};
    if (typeId == callType) {
        return {QVariantMap{{QStringLiteral("label"), tr("测试播放")}, {QStringLiteral("value"), QStringLiteral("playTest")}},
                QVariantMap{{QStringLiteral("label"), tr("停止")}, {QStringLiteral("value"), QStringLiteral("stop")}}};
    }
    return {};
}

QString DemoGraph::targetType(const QString &targetId) const
{
    if (m_existingSpeakers.contains(targetId))
        return speakerType;
    const auto *node = m_document.findNode(QUuid(targetId));
    return node ? node->typeId : QString();
}

QVariantList DemoGraph::readMembers(const QString &targetId) const
{
    QVariantList members;
    const auto typeId = targetType(targetId);
    for (const auto &property : readableProperties) {
        if (property.objectType == typeId)
            members.append(QVariantMap{{QStringLiteral("label"), tr(property.label)},
                                       {QStringLiteral("value"), property.key}});
    }
    return members;
}

bool DemoGraph::bindRead(const QString &nodeId, const QString &targetId, const QString &member)
{
    const QUuid id(nodeId);
    const auto *node = m_document.findNode(id);
    const auto typeId = targetType(targetId);
    if (!node || !isReader(node->typeId) || typeId.isEmpty())
        return report(tr("读取节点或目标已失效。"));
    const auto *property = readableProperty(typeId, member);
    if (!member.isEmpty() && !property)
        return report(tr("所选目标没有此属性。"));
    const auto none = QStringLiteral("");
    return report(m_document.setParameters(id, {
        {targetKey, targetId}, {memberKey, member}, {memberTypeKey, property ? property->valueType : none}
    }).error);
}

QString DemoGraph::addOperation(const QString &typeId, const QString &targetId, const QString &member, QPointF position)
{
    const auto objectType = targetType(targetId);
    if (typeId == readPropertyType) {
        const auto *property = readableProperty(objectType, member);
        if (!property) {
            report(tr("所选目标没有此属性。"));
            return {};
        }
        const auto result = m_document.addNode(typeId, position, {
            {targetKey, targetId}, {memberKey, member}, {memberTypeKey, property->valueType}
        });
        return report(result.error) ? result.id.toString(QUuid::WithoutBraces) : QString();
    }
    if (objectType != speakerType || operationMembers(typeId).isEmpty()) {
        report(tr("无法绑定此目标。"));
        return {};
    }
    const auto result = m_document.addNode(typeId, position, {{targetKey, targetId}, {memberKey, member}});
    return report(result.error) ? result.id.toString(QUuid::WithoutBraces) : QString();
}

bool DemoGraph::setDurationInput(const QString &nodeId, const QString &text)
{
    bool ok = false;
    const int duration = text.trimmed().toInt(&ok);
    if (!ok || duration < minDuration || duration > maxDuration)
        return report(tr("测试时长必须为 %1–%2 毫秒的整数。").arg(minDuration).arg(maxDuration));
    report({});
    return m_session.setParameter(nodeId, valueKey, static_cast<double>(duration));
}

bool DemoGraph::run(const QString &triggerId)
{
    const QUuid trigger(triggerId);
    const NodeData *start = m_document.findNode(trigger);
    if (!start || start->typeId != triggerType)
        return report(tr("手动触发节点已失效。"));

    QHash<QUuid, QUuid> next;
    QHash<QUuid, QUuid> valueSources;
    for (const ConnectionData &link : m_document.data().connections) {
        if (link.source.portKey == execOut)
            next.insert(link.source.nodeId, link.target.nodeId);
        else if (link.target.portKey == valueKey)
            valueSources.insert(link.target.nodeId, link.source.nodeId);
    }

    // 先检查执行链，避免检测到循环前已经写入或调用对象。
    QVector<QUuid> steps;
    QSet<QUuid> visited;
    for (QUuid id = next.value(trigger); !id.isNull(); id = next.value(id)) {
        if (visited.contains(id))
            return report(tr("执行连线存在循环。"));
        visited.insert(id);
        const auto target = m_document.parameterValue(id, targetKey).toString();
        if (speakerState(target).isEmpty())
            return report(tr("流程中的操作节点未绑定音箱或目标已失效。"));
        steps.append(id);
    }
    if (steps.isEmpty())
        return report(tr("请先连接执行输出。"));

    for (const QUuid &id : steps) {
        const NodeData *node = m_document.findNode(id);
        const auto target = m_document.parameterValue(id, targetKey).toString();
        const QString member = m_document.parameterValue(id, memberKey).toString();
        if (node->typeId == setType) {
            const QUuid source = valueSources.value(id);
            const QVariant value = source.isNull() ? m_document.parameterValue(id, valueKey) : m_outputs.value(source);
            if (!value.isValid())
                return report(tr("设置属性的输入值不可用。"));
            auto *speaker = m_existingSpeakers.value(target);
            const auto error = speaker ? speaker->writeState(member, value)
                                       : m_runtime.writeState(QUuid(target), member, value);
            if (!error.isEmpty())
                return report(error);
        } else if (!invokeSpeaker(target, member)) {
            return false;
        }
    }
    return report({});
}

bool DemoGraph::open(const QUrl &url)
{
    if (!report(m_document.loadFile(url.toLocalFile())))
        return false;
    m_fileName = QFileInfo(url.toLocalFile()).fileName();
    emit fileNameChanged();
    return true;
}

bool DemoGraph::save(const QUrl &url)
{
    if (!report(m_document.saveFile(url.toLocalFile())))
        return false;
    m_session.markSaved();
    m_fileName = QFileInfo(url.toLocalFile()).fileName();
    emit fileNameChanged();
    return true;
}

void DemoGraph::updateValues()
{
    QHash<QUuid, QHash<QString, QUuid>> inputs;
    QHash<QUuid, QVector<QUuid>> downstream;
    QHash<QUuid, int> waiting;
    for (const ConnectionData &link : m_document.data().connections) {
        if (link.source.portKey == execOut)
            continue;
        inputs[link.target.nodeId].insert(link.target.portKey, link.source.nodeId);
        downstream[link.source.nodeId].append(link.target.nodeId);
        ++waiting[link.target.nodeId];
    }

    QHash<QUuid, const NodeData *> byId;
    QVector<QUuid> ready;
    for (const NodeData &node : m_document.data().nodes) {
        byId.insert(node.id, &node);
        if (waiting.value(node.id) == 0)
            ready.append(node.id);
    }

    // 按依赖顺序求值。缺输入或有循环的节点保持未求值状态。
    QHash<QUuid, QVariant> values;
    for (int index = 0; index < ready.size(); ++index) {
        const QUuid id = ready.at(index);
        const QString &typeId = byId.value(id)->typeId;
        if (typeId == constantType || typeId == stringConstantType || typeId == optionConstantType
            || typeId == boolConstantType) {
            values.insert(id, m_document.parameterValue(id, valueKey));
        } else if (typeId == notType) {
            const auto a = values.value(inputs.value(id).value(inputA));
            if (a.isValid())
                values.insert(id, !a.toBool());
        } else if (typeId == additionType || typeId == compareType || typeId == greaterType || typeId == lessType
                   || typeId == equalType || typeId == andType || typeId == orType) {
            const auto links = inputs.value(id);
            const auto a = values.value(links.value(inputA));
            const auto b = values.value(links.value(inputB));
            if (a.isValid() && b.isValid()) {
                if (typeId == additionType) {
                    const double sum = a.toDouble() + b.toDouble();
                    if (qIsFinite(sum))
                        values.insert(id, sum);
                } else if (typeId == compareType) {
                    const auto operation = m_document.parameterValue(id, operatorKey).toString();
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
                    values.insert(id, result);
                } else if (typeId == greaterType) {
                    values.insert(id, a.toDouble() > b.toDouble());
                } else if (typeId == lessType) {
                    values.insert(id, a.toDouble() < b.toDouble());
                } else if (typeId == equalType) {
                    values.insert(id, a.toDouble() == b.toDouble());
                } else if (typeId == andType) {
                    values.insert(id, a.toBool() && b.toBool());
                } else {
                    values.insert(id, a.toBool() || b.toBool());
                }
            }
        } else if (isReader(typeId)) {
            const auto target = m_document.parameterValue(id, targetKey).toString();
            const auto key = m_document.parameterValue(id, memberKey).toString();
            const auto *property = readableProperty(targetType(target), key);
            if (property && property->valueType == m_document.parameterValue(id, memberTypeKey).toString()) {
                const auto value = property->runtime
                    ? speakerState(target).value(key) : m_document.parameterValue(QUuid(target), key);
                if (NodeRegistry::acceptsValue(property->valueType, value))
                    values.insert(id, value);
            }
        } else if (typeId == resultType || typeId == textResultType || typeId == boolResultType) {
            const auto input = values.constFind(inputs.value(id).value(valueKey));
            if (input != values.cend())
                values.insert(id, input.value());
        }
        for (const QUuid &next : downstream.value(id)) {
            if (--waiting[next] == 0)
                ready.append(next);
        }
    }

    QVariantMap formatted;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        const QVariant &value = it.value();
        QString display;
        if (value.userType() == QMetaType::Bool)
            display = value.toBool() ? tr("是") : tr("否");
        else if (value.userType() == QMetaType::QString)
            display = value.toString();
        else
            display = QLocale::c().toString(value.toDouble(), 'g', 12);
        formatted.insert(it.key().toString(QUuid::WithoutBraces), display.isEmpty() ? tr("（空字符串）") : display);
    }
    m_outputs = std::move(values);
    if (m_values != formatted) {
        m_values.swap(formatted);
        emit previewValuesChanged();
    }
}

void DemoGraph::syncSpeakers()
{
    report(m_runtime.syncNodes(m_document, {{speakerType, [](const QVariantMap &parameters) {
        const double duration = parameters.value(durationKey).toDouble();
        return std::make_unique<SpeakerBehavior>(static_cast<int>(qBound<double>(minDuration, duration, maxDuration)));
    }}}));
}

bool DemoGraph::report(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
    return error.isEmpty();
}
