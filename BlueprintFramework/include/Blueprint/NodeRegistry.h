#pragma once

#include <Blueprint/GraphData.h>

#include <QHash>
#include <QObject>

#include <memory>

namespace Blueprint {

//! 项目内共享的追加式类型注册表。由宿主持有，所有访问在其所属线程完成。
class NodeRegistry : public QObject
{
    Q_OBJECT

public:
    explicit NodeRegistry(QObject *parent = nullptr);

    //! 注册不可变的类型定义。失败时注册表保持不变，不允许覆盖已有类型。
    Diagnostic add(const NodeTypeDefinition &definition);

    //! 未注册时返回空指针。返回值在注册表存活期间保持有效。
    const NodeTypeDefinition *find(const QString &typeId) const;

    //! 按注册顺序返回声明快照。
    QVector<NodeTypeDefinition> definitions() const;

    //! 按声明类型检查值，避免把字符串等隐式转换成数值。
    static bool acceptsValue(const QString &valueTypeId, const QVariant &value);

    //! 同时检查参数的值类型、候选值及数值约束。
    static bool acceptsParameterValue(const ParameterDefinition &parameter, const QVariant &value);

    //! 根据已校验的声明检查参数、属性或调用数据；缺失项使用默认值。
    //! 无默认值且缺失表示未设置；未知键和显式无效值均报错。
    static Diagnostic validateValues(const QVector<ParameterDefinition> &definitions,
                                     const QVariantMap &values);

    //! 注册、派生端口和运行快照共用的端口校验。
    static Diagnostic validatePorts(const QVector<PortDefinition> &ports,
                                    bool allowUnconfigured = false);

signals:
    void typeAdded(const QString &typeId);

private:
    QHash<QString, std::shared_ptr<const NodeTypeDefinition>> m_types;
    QStringList m_typeOrder;
};

} // namespace Blueprint
