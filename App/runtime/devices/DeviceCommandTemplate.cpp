#include "devices/DeviceCommandTemplate.h"

namespace TimelineControl {

DeviceCommandTemplate::DeviceCommandTemplate(const QString &id,
                                             const QString &name,
                                             const QString &action,
                                             const QVariantList &params,
                                             QObject *parent)
    : QObject(parent)
    , m_id(id)
    , m_name(name)
    , m_action(action)
    , m_params(params)
{
}

QString DeviceCommandTemplate::id() const
{
    return m_id;
}

QString DeviceCommandTemplate::name() const
{
    return m_name;
}

QString DeviceCommandTemplate::action() const
{
    return m_action;
}

QVariantList DeviceCommandTemplate::params() const
{
    return m_params;
}

} // namespace TimelineControl
