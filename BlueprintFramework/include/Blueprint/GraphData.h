#pragma once

#include <QPointF>
#include <QMetaType>
#include <QString>
#include <QStringList>
#include <QUuid>
#include <QVariant>
#include <QVector>

#include <functional>

namespace Blueprint {

struct GraphData;
struct NodeData;

//! 数据输入可接受任一受支持的值类型；输出、参数和属性仍需声明具体类型。
inline const QString anyValueType = QStringLiteral("any");

//! 公共操作的诊断结果。code 为空时表示成功。
struct Diagnostic
{
    QString code;
    QString message;
    QUuid nodeId;
    QString key;
};

enum class PortDirection
{
    Input,
    Output
};

enum class PortKind
{
    Data,
    Execution
};

//! 节点类型上声明的端口。
struct PortDefinition
{
    //! 类型内稳定的端口键，供连线引用。
    QString key;
    PortDirection direction = PortDirection::Input;
    //! 数据端口的值类型；执行端口不承载值，必须为空。
    QString valueTypeId;
    QString displayName;
    PortKind kind = PortKind::Data;
    //! 数据输入端口的可选默认值；未连接且没有默认值时由运行时报错。
    QVariant defaultValue;
};

//! 节点自身的可编辑参数，与数据输入端口分开声明。
struct ParameterDefinition
{
    //! 类型内稳定的参数键，供节点实例保存覆盖值。
    QString key;
    QString valueTypeId;
    QVariant defaultValue;
    //! 字符串参数的封闭候选值，留空时允许任意字符串。
    QStringList allowedValues;
    QString displayName;
    QString description;
    //! 数值参数的闭区间边界；无效 QVariant 表示没有该边界。
    QVariant minimum;
    QVariant maximum;
    bool integer = false;
};

//! 由宿主对象或节点运行实例持有的属性，变更不写入图配置。
struct PropertyDefinition
{
    ParameterDefinition value;
    //! 默认为只读；仅显式可写属性允许生成设置操作，宿主写入也须检查此标记。
    bool writable = false;
};

//! 一次接口调用的输入和输出声明。
struct MethodDefinition
{
    QString key;
    QString displayName;
    QVector<ParameterDefinition> inputs;
    QVector<ParameterDefinition> outputs;
};

enum class InstancePolicy
{
    Multiple,
    SinglePerDocument,
    UniqueByParameter
};

//! 可由多个节点实例共享的类型定义。
struct NodeTypeDefinition
{
    //! 注册表中的稳定类型标识。
    QString typeId;
    QString displayName;
    QVector<PortDefinition> ports;
    QVector<ParameterDefinition> parameters;
    //! 宿主定义的节点库分组标识，可留空。
    QString categoryId;
    //! 约束此类型在一张图内的实例数量。
    InstancePolicy instancePolicy = InstancePolicy::Multiple;
    //! UniqueByParameter 使用的字符串参数，实例的有效值必须非空。
    QString instanceKeyParameter = {};
    QString description;
    QString symbol;
    QVector<PropertyDefinition> properties;
    QVector<MethodDefinition> methods;
    //! 可选。仅根据本节点配置与稳定成员声明解析端口，不读取其他节点可变值。
    //! 未配置的数据端口可使用空 valueTypeId，此时不能连接。
    std::function<QVector<PortDefinition>(const NodeData &)> resolvePorts;
};

//! 一张图中的节点实例。
struct NodeData
{
    //! 在所属图中定位此节点。
    QUuid id;
    //! 引用 NodeTypeDefinition::typeId。
    QString typeId;
    //! 画布坐标，独立于视口平移和缩放。
    QPointF position;
    //! 按参数键保存覆盖值，缺少键时使用定义的默认值。
    QVariantMap parameterOverrides;
};

//! 在所属图内用节点标识和端口键定位端口。
struct Endpoint
{
    QUuid nodeId;
    QString portKey;
};

//! 从输出端口指向输入端口的有向连线。
struct ConnectionData
{
    QUuid id;
    Endpoint source;
    Endpoint target;
};

//! 一张图的持久化数据，集中保存节点与连线。
struct GraphData
{
    QUuid id;
    QVector<NodeData> nodes;
    QVector<ConnectionData> connections;
};

//! 启动时已解析默认参数和派生端口的节点，不包含画布状态。
struct SnapshotNode
{
    QUuid id;
    QString typeId;
    QVariantMap parameters;
    QVector<PortDefinition> ports;
};

//! 在文档所属线程创建，运行期间保持不变的逻辑快照。
struct GraphSnapshot
{
    QUuid graphId;
    quint64 revision = 0;
    QVector<SnapshotNode> nodes;
    QVector<ConnectionData> connections;
};

} // namespace Blueprint

Q_DECLARE_METATYPE(Blueprint::Diagnostic)
