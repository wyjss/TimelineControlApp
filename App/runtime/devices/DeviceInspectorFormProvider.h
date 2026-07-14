#pragma once

#include <QPointer>
#include <QObject>
#include <QString>
#include <QVariantMap>

namespace EarthUI {

class AppForm;
class AppFormField;
class AppFormSection;

} // namespace EarthUI


class Device;
class DeviceCommand;
class DeviceModel;
class DeviceParamSpec;
class DeviceTemplate;
class DeviceTemplateModel;

//! 为模板、设备和指令生成只读 inspector 表单。
class DeviceInspectorFormProvider final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString templateName READ templateName WRITE setTemplateName NOTIFY templateNameChanged FINAL)
    Q_PROPERTY(QString deviceId READ deviceId WRITE setDeviceId NOTIFY deviceIdChanged FINAL)
    Q_PROPERTY(EarthUI::AppForm *templateForm READ templateForm NOTIFY templateFormChanged FINAL)
    Q_PROPERTY(EarthUI::AppForm *templateConfigForm READ templateConfigForm NOTIFY templateConfigFormChanged FINAL)
    Q_PROPERTY(EarthUI::AppForm *deviceForm READ deviceForm NOTIFY deviceFormChanged FINAL)
    Q_PROPERTY(EarthUI::AppForm *commandForm READ commandForm NOTIFY commandFormChanged FINAL)

public:
    explicit DeviceInspectorFormProvider(DeviceModel *deviceModel,
                                         DeviceTemplateModel *deviceTemplateModel,
                                         QObject *parent = nullptr);

    QString templateName() const;
    void setTemplateName(const QString &templateName);

    QString deviceId() const;
    void setDeviceId(const QString &deviceId);

    EarthUI::AppForm *templateForm() const;
    EarthUI::AppForm *templateConfigForm() const;
    EarthUI::AppForm *deviceForm() const;
    EarthUI::AppForm *commandForm() const;

    Q_INVOKABLE void inspectTemplate(const QString &templateName);
    Q_INVOKABLE void inspectDevice(const QString &deviceId);
    Q_INVOKABLE void inspectCommand(DeviceCommand *command);
    Q_INVOKABLE void inspectCommandMap(const QVariantMap &command);

signals:
    void templateNameChanged();
    void deviceIdChanged();
    void templateFormChanged();
    void templateConfigFormChanged();
    void deviceFormChanged();
    void commandFormChanged();

private:
    DeviceTemplate *findTemplate(const QString &templateName) const;
    Device *findDevice(const QString &deviceId) const;
    QString firstTemplateName() const;

    void rebuildTemplateForms();
    void rebuildDeviceForm();
    void rebuildCommandForm();

    EarthUI::AppForm *buildTemplateForm(const DeviceTemplate *deviceTemplate);
    EarthUI::AppForm *buildTemplateConfigForm(const DeviceTemplate *deviceTemplate);
    EarthUI::AppForm *buildDeviceForm(const Device *device);
    EarthUI::AppForm *buildCommandForm(const DeviceCommand *command);
    EarthUI::AppForm *buildCommandMapForm(const QVariantMap &command);

    EarthUI::AppForm *makeForm(const QString &title = QString(), const QString &subtitle = QString()) const;
    EarthUI::AppFormSection *makeSection(EarthUI::AppForm *form, const QString &title) const;
    EarthUI::AppFormField *makeSummaryField(const QString &key,
                                            const QString &label,
                                            const QVariant &value,
                                            const QString &subtitle = QString()) const;
    EarthUI::AppFormField *makeReadOnlyField(const QString &key,
                                             const QString &label,
                                             const QVariant &value,
                                             const QString &subtitle = QString()) const;
    void appendParamSpecField(EarthUI::AppFormSection *section,
                              const DeviceParamSpec *spec,
                              const QVariant &value,
                              bool useReadOnlyField = false) const;

    DeviceModel *m_deviceModel = nullptr;
    DeviceTemplateModel *m_deviceTemplateModel = nullptr;
    QString m_templateName;
    QString m_deviceId;
    QPointer<DeviceCommand> m_command;
    QVariantMap m_commandMap;
    EarthUI::AppForm *m_templateForm = nullptr;
    EarthUI::AppForm *m_templateConfigForm = nullptr;
    EarthUI::AppForm *m_deviceForm = nullptr;
    EarthUI::AppForm *m_commandForm = nullptr;
};


Q_DECLARE_METATYPE(DeviceInspectorFormProvider *)
