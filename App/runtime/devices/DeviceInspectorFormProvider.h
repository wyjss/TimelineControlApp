#pragma once

#include <QPointer>
#include <QObject>
#include <QString>
#include <QVariantMap>

namespace UICore {

class AppForm;
class AppField;
class AppFormSection;

} // namespace UICore


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
    Q_PROPERTY(UICore::AppForm *templateForm READ templateForm NOTIFY templateFormChanged FINAL)
    Q_PROPERTY(UICore::AppForm *templateConfigForm READ templateConfigForm NOTIFY templateConfigFormChanged FINAL)
    Q_PROPERTY(UICore::AppForm *deviceForm READ deviceForm NOTIFY deviceFormChanged FINAL)
    Q_PROPERTY(UICore::AppForm *commandForm READ commandForm NOTIFY commandFormChanged FINAL)

public:
    explicit DeviceInspectorFormProvider(DeviceModel *deviceModel,
                                         DeviceTemplateModel *deviceTemplateModel,
                                         QObject *parent = nullptr);

    QString templateName() const;
    void setTemplateName(const QString &templateName);

    QString deviceId() const;
    void setDeviceId(const QString &deviceId);

    UICore::AppForm *templateForm() const;
    UICore::AppForm *templateConfigForm() const;
    UICore::AppForm *deviceForm() const;
    UICore::AppForm *commandForm() const;

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

    UICore::AppForm *buildTemplateForm(const DeviceTemplate *deviceTemplate);
    UICore::AppForm *buildTemplateConfigForm(const DeviceTemplate *deviceTemplate);
    UICore::AppForm *buildDeviceForm(const Device *device);
    UICore::AppForm *buildCommandForm(const DeviceCommand *command);
    UICore::AppForm *buildCommandMapForm(const QVariantMap &command);

    UICore::AppForm *makeForm(const QString &title = QString(), const QString &subtitle = QString()) const;
    UICore::AppFormSection *makeSection(UICore::AppForm *form, const QString &title) const;
    UICore::AppField *makeSummaryField(const QString &key,
                                       const QString &label,
                                       const QVariant &value,
                                       const QString &subtitle = QString()) const;
    UICore::AppField *makeReadOnlyField(const QString &key,
                                        const QString &label,
                                        const QVariant &value,
                                        const QString &subtitle = QString()) const;
    void appendParamSpecField(UICore::AppFormSection *section,
                              const DeviceParamSpec *spec,
                              const QVariant &value,
                              bool useReadOnlyField = false) const;

    DeviceModel *m_deviceModel = nullptr;
    DeviceTemplateModel *m_deviceTemplateModel = nullptr;
    QString m_templateName;
    QString m_deviceId;
    QPointer<DeviceCommand> m_command;
    QVariantMap m_commandMap;
    UICore::AppForm *m_templateForm = nullptr;
    UICore::AppForm *m_templateConfigForm = nullptr;
    UICore::AppForm *m_deviceForm = nullptr;
    UICore::AppForm *m_commandForm = nullptr;
};


Q_DECLARE_METATYPE(DeviceInspectorFormProvider *)
