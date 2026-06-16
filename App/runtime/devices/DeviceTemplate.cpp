#include "devices/DeviceTemplate.h"

#include <QVariant>

namespace TimelineControl {

DeviceTemplate::DeviceTemplate(const QString &id,
                               const QString &name,
                               const QString &protocol,
                               const QString &description,
                               const QList<DeviceParamSpec *> &configSpecs,
                               QObject *parent)
    : QObject(parent)
    , m_id(id)
    , m_name(name)
    , m_protocol(protocol)
    , m_description(description)
{
    m_configSpecs.reserve(configSpecs.size());
    for (DeviceParamSpec *configSpec : configSpecs) {
        if (!configSpec)
            continue;

        if (configSpec->parent()) {
            m_configSpecs.append(configSpec->clone(this));
        } else {
            configSpec->setParent(this);
            m_configSpecs.append(configSpec);
        }
    }
}

QString DeviceTemplate::id() const
{
    return m_id;
}

QString DeviceTemplate::name() const
{
    return m_name;
}

QString DeviceTemplate::protocol() const
{
    return m_protocol;
}

QString DeviceTemplate::description() const
{
    return m_description;
}

QVariantList DeviceTemplate::configSpecs() const
{
    QVariantList result;
    result.reserve(m_configSpecs.size());

    for (DeviceParamSpec *configSpec : m_configSpecs)
        result.append(QVariant::fromValue(configSpec));

    return result;
}

QList<DeviceParamSpec *> DeviceTemplate::configSpecObjects() const
{
    return m_configSpecs;
}

} // namespace TimelineControl
