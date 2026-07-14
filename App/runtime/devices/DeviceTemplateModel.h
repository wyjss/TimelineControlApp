#pragma once

#include "devices/DeviceTemplate.h"
#include "models/TypedListModel.h"

#include <QString>
#include <QStringList>
#include <QVariantList>


class DeviceTemplateModel final : public TypedListModel<DeviceTemplate *>
{
    Q_OBJECT
    Q_PROPERTY(QVariantList templates READ templates NOTIFY templatesChanged FINAL)

public:
    explicit DeviceTemplateModel(QObject *parent = nullptr);

    void loadDefaultTemplates();

    QVariantList templates() const;
    DeviceTemplate *templateAt(int row) const;
    DeviceTemplate *templateByName(const QString &templateName) const;

signals:
    void templatesChanged();

protected:
    bool acceptsItem(DeviceTemplate *deviceTemplate) const override;

private:
    int indexOfTemplate(DeviceTemplate *deviceTemplate) const;
    int indexOfTemplateName(const QString &templateName) const;
    void appendTemplate(DeviceTemplate *deviceTemplate);

    DeviceTemplate *createDefaultDeviceTemplatePc();
    DeviceTemplate *createDefaultDeviceTemplateDmx512Adapter();
    DeviceTemplate *createDefaultDeviceTemplateDmx512();
    DeviceTemplate *createDefaultDeviceTemplateHttp();
    DeviceTemplate *createDefaultDeviceTemplateSerial();
    DeviceTemplate *createDefaultDeviceTemplateOsc();

    DeviceTemplate *makeDeviceTemplate(const QString &name,
                                       const QString &deviceType,
                                       const QStringList &supportedProtocols,
                                       const QString &description,
                                       const QList<DeviceParamSpec *> &configSpecs,
                                       const QList<DeviceCommand *> &commands = {});
};


Q_DECLARE_METATYPE(DeviceTemplateModel *)
