#pragma once

#include <QPointF>
#include <QString>
#include <QStringList>
#include <QUuid>
#include <QVariant>
#include <QVector>

namespace Blueprint {

//! 执行端口只传递触发信号，不承载值。
inline const QString executionPortType = QStringLiteral("exec");

//! 数据输入端口可接收任意受支持的数据类型，不接受执行信号。
inline const QString anyValueType = QStringLiteral("any");

enum class PortDirection
{
    Input,
    Output
};

//! 节点类型上声明的端口。
struct PortDefinition
{
    //! 类型内稳定的端口键，供连线引用。
    QString key;
    PortDirection direction = PortDirection::Input;
    //! 用于校验连线兼容性和值的类型标识。
    QString valueTypeId;
    //! 可选。由此字符串参数决定数据端口类型，空值时端口未配置。
    QString typeParameterKey;
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

} // namespace Blueprint
