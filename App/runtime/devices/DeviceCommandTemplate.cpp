#include "devices/DeviceCommandTemplate.h"

#include <QVariant>

namespace TimelineControl {

DeviceCommandTemplate::DeviceCommandTemplate(const QString &id,
                                             const QString &name,
                                             const QString &action,
                                             const QList<DeviceParamSpec *> &params,
                                             QObject *parent)
    : QObject(parent)
    , m_id(id)
    , m_name(name)
    , m_action(action)
{
    m_params.reserve(params.size());
    for (DeviceParamSpec *param : params) {
        if (!param)
            continue;

        if (param->parent()) {
            m_params.append(param->clone(this));
        } else {
            param->setParent(this);
            m_params.append(param);
        }
    }
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
    QVariantList result;
    result.reserve(m_params.size());

    for (DeviceParamSpec *param : m_params)
        result.append(QVariant::fromValue(param));

    return result;
}

QList<DeviceParamSpec *> DeviceCommandTemplate::paramSpecs() const
{
    return m_params;
}

} // namespace TimelineControl
