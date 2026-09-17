#pragma once

#include "devices/DeviceTemplate.h"
#include "models/TypedListModel.h"

#include <QString>
#include <QStringList>
#include <QVariantList>


class TimelineModel;


//! 实例由 TimelineRuntime 创建并管理。
class DeviceTemplateModel final : public TypedListModel<DeviceTemplate *>
{
    Q_OBJECT
    Q_PROPERTY(QVariantList templates READ templates NOTIFY templatesChanged FINAL)

public:
    explicit DeviceTemplateModel(TimelineModel *timelineModel,
                                 QObject *parent = nullptr);

    void loadDefaultTemplates();

    QVariantList templates() const;
    DeviceTemplate *templateAt(int row) const;
    DeviceTemplate *templateByName(const QString &templateName) const;

signals:
    void templatesChanged();

protected:
    bool acceptsItem(DeviceTemplate *deviceTemplate) const override;

private:
    int indexOfTemplateName(const QString &templateName) const;
    void appendTemplate(DeviceTemplate *deviceTemplate);

    DeviceTemplate *createDefaultDeviceTemplateDmx512Adapter();
    DeviceTemplate *createDefaultDeviceTemplateDmx512();
    DeviceTemplate *createDefaultDeviceTemplateHttp();
    DeviceTemplate *createDefaultDeviceTemplateSerial();
    DeviceTemplate * createDefaultDeviceTemplateUdp();

    DeviceTemplate *makeDeviceTemplate(const QString &name,
                                       const QString &deviceType,
                                       const QStringList &supportedProtocols,
                                       const QString &description,
                                       const QList<DeviceParamSpec *> &configSpecs,
                                       const QList<DeviceCommand *> &commands = {});

    TimelineModel *m_timelineModel = nullptr;
};


Q_DECLARE_METATYPE(DeviceTemplateModel *)
