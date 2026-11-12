#pragma once

#include <Blueprint/GraphData.h>

#include <QHash>

namespace Blueprint {

//! 保存可供图文档使用的节点类型定义。
class NodeRegistry
{
public:
    //! 注册类型。成功时返回空字符串。
    QString add(const NodeTypeDefinition &definition);

    //! 未注册时返回空指针。继续注册类型后应重新查询。
    const NodeTypeDefinition *find(const QString &typeId) const;

    //! 按声明类型检查值，避免把字符串等隐式转换成数值。
    static bool acceptsValue(const QString &valueTypeId, const QVariant &value);

private:
    QHash<QString, NodeTypeDefinition> m_types;
};

} // namespace Blueprint
