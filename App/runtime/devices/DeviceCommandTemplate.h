#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>

namespace TimelineControl {

class DeviceCommandTemplate final : public QObject
{
    Q_OBJECT

    //! 指令模板唯一标识，供时间线引用。
    Q_PROPERTY(QString id READ id CONSTANT FINAL)
    Q_PROPERTY(QString name READ name CONSTANT FINAL)
    Q_PROPERTY(QString action READ action CONSTANT FINAL)
    Q_PROPERTY(QVariantList params READ params CONSTANT FINAL)

public:
    DeviceCommandTemplate(const QString &id,
                          const QString &name,
                          const QString &action,
                          const QVariantList &params,
                          QObject *parent = nullptr);

    QString id() const;
    QString name() const;
    QString action() const;
    QVariantList params() const;

private:
    QString m_id;
    QString m_name;
    QString m_action;
    QVariantList m_params;
};

} // namespace TimelineControl

Q_DECLARE_METATYPE(TimelineControl::DeviceCommandTemplate *)
