#pragma once

#include <QPointF>
#include <QString>
#include <QUuid>
#include <QVariant>
#include <QVector>

namespace Blueprint {

enum class PortDirection
{
    Input,
    Output
};

//! 节点类型上声明的数据端口。
struct PortDefinition
{
    //! 类型内稳定的端口键，供连线引用。
    QString key;
    PortDirection direction = PortDirection::Input;
    //! 用于校验连线兼容性和值的类型标识。
    QString valueTypeId;
};

//! 节点自身的可编辑参数，与数据输入端口分开声明。
struct ParameterDefinition
{
    //! 类型内稳定的参数键，供节点实例保存覆盖值。
    QString key;
    QString valueTypeId;
    QVariant defaultValue;
};

//! 可由多个节点实例共享的类型定义。
struct NodeTypeDefinition
{
    //! 注册表中的稳定类型标识。
    QString typeId;
    QString displayName;
    QVector<PortDefinition> ports;
    QVector<ParameterDefinition> parameters;
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
