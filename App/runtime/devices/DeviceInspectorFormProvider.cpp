#include "devices/DeviceInspectorFormProvider.h"

#include <algorithm>

#include <QColor>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSize>
#include <QStringList>
#include <QVariantList>

#include "devices/Device.h"
#include "devices/DeviceCommand.h"
#include "devices/DeviceModel.h"
#include "devices/DeviceParamSpec.h"
#include "devices/DeviceTemplate.h"
#include "devices/DeviceTemplateModel.h"
#include "runtime/form/AppForm.h"
#include "runtime/form/AppFormField.h"
#include "runtime/form/AppFormSection.h"

namespace {

template <typename T>
T *objectFromVariant(const QVariant &value)
{
    if (value.canConvert<T *>())
        return value.value<T *>();

    if (value.canConvert<QObject *>())
        return qobject_cast<T *>(value.value<QObject *>());

    return nullptr;
}

QString boolText(bool value)
{
    return value ? QStringLiteral("true") : QStringLiteral("false");
}

QString sizeText(const QSize &size)
{
    return QStringLiteral("%1x%2").arg(size.width()).arg(size.height());
}

QString jsonText(const QVariant &value)
{
    const QJsonDocument document = QJsonDocument::fromVariant(value);
    if (document.isNull())
        return QString();

    return QString::fromUtf8(document.toJson(QJsonDocument::Compact));
}

QString displayValue(const QVariant &value)
{
    if (!value.isValid() || value.isNull())
        return QStringLiteral("Empty");

    if (value.type() == QVariant::Bool)
        return boolText(value.toBool());

    if (value.canConvert<QSize>()) {
        const QSize size = value.toSize();
        if (size.isValid())
            return sizeText(size);
    }

    if (value.canConvert<QColor>()) {
        const QColor color = value.value<QColor>();
        if (color.isValid())
            return color.name(QColor::HexArgb);
    }

    if (value.type() == QVariant::Map || value.type() == QVariant::List) {
        const QString text = jsonText(value);
        if (!text.isEmpty())
            return text;
    }

    const QString text = value.toString();
    return text.trimmed().isEmpty() ? QStringLiteral("Empty") : text;
}

QString specSubtitle(const TimelineControl::DeviceParamSpec *spec)
{
    if (!spec)
        return QString();

    QStringList parts;
    parts.append(spec->typeName());
    if (spec->required())
        parts.append(QStringLiteral("required"));
    if (spec->readOnly())
        parts.append(QStringLiteral("read only"));
    if (!spec->suffix().isEmpty())
        parts.append(spec->suffix());
    return parts.join(QStringLiteral(" / "));
}

QString optionLabel(const QVariant &option)
{
    const QVariantMap optionMap = option.toMap();
    if (!optionMap.isEmpty()) {
        const QString label = optionMap.value(QStringLiteral("label")).toString();
        if (!label.isEmpty())
            return label;
        return displayValue(optionMap.value(QStringLiteral("value")));
    }

    return displayValue(option);
}

QString optionsText(const QVariantList &options)
{
    QStringList labels;
    labels.reserve(options.size());
    for (const QVariant &option : options)
        labels.append(optionLabel(option));
    return labels.join(QStringLiteral(", "));
}

void replaceForm(EarthUI::AppForm *&target, EarthUI::AppForm *next)
{
    EarthUI::AppForm *old = target;
    target = next;
    if (old)
        old->deleteLater();
}

} // namespace

namespace TimelineControl {

DeviceInspectorFormProvider::DeviceInspectorFormProvider(DeviceModel *deviceModel,
                                                         DeviceTemplateModel *deviceTemplateModel,
                                                         QObject *parent)
    : QObject(parent)
    , m_deviceModel(deviceModel)
    , m_deviceTemplateModel(deviceTemplateModel)
{
    m_templateName = firstTemplateName();
    m_deviceId = m_deviceModel ? m_deviceModel->currentDeviceId() : QString();

    if (m_deviceTemplateModel) {
        connect(m_deviceTemplateModel, &DeviceTemplateModel::templatesChanged, this, [this]() {
            const QString nextTemplateName = findTemplate(m_templateName) ? m_templateName : firstTemplateName();
            const bool changed = m_templateName != nextTemplateName;
            m_templateName = nextTemplateName;
            rebuildTemplateForms();
            rebuildDeviceForm();
            if (changed)
                emit templateNameChanged();
        });
    }
    if (m_deviceModel) {
        connect(m_deviceModel, &DeviceModel::devicesChanged, this, [this]() {
            const QString nextDeviceId = findDevice(m_deviceId)
                ? m_deviceId
                : m_deviceModel->currentDeviceId();
            const bool changed = m_deviceId != nextDeviceId;
            m_deviceId = nextDeviceId;
            rebuildDeviceForm();
            if (changed)
                emit deviceIdChanged();
        });
        connect(m_deviceModel, &DeviceModel::currentDeviceIdChanged, this, [this]() {
            setDeviceId(m_deviceModel ? m_deviceModel->currentDeviceId() : QString());
        });
    }

    rebuildTemplateForms();
    rebuildDeviceForm();
    rebuildCommandForm();
}

QString DeviceInspectorFormProvider::templateName() const
{
    return m_templateName;
}

void DeviceInspectorFormProvider::setTemplateName(const QString &templateName)
{
    const QString normalizedTemplateName = templateName.trimmed();
    if (m_templateName == normalizedTemplateName)
        return;

    m_templateName = normalizedTemplateName;
    emit templateNameChanged();
    rebuildTemplateForms();
}

QString DeviceInspectorFormProvider::deviceId() const
{
    return m_deviceId;
}

void DeviceInspectorFormProvider::setDeviceId(const QString &deviceId)
{
    const QString normalizedDeviceId = deviceId.trimmed();
    if (m_deviceId == normalizedDeviceId)
        return;

    m_deviceId = normalizedDeviceId;
    emit deviceIdChanged();
    rebuildDeviceForm();
}

EarthUI::AppForm *DeviceInspectorFormProvider::templateForm() const
{
    return m_templateForm;
}

EarthUI::AppForm *DeviceInspectorFormProvider::templateConfigForm() const
{
    return m_templateConfigForm;
}

EarthUI::AppForm *DeviceInspectorFormProvider::deviceForm() const
{
    return m_deviceForm;
}

EarthUI::AppForm *DeviceInspectorFormProvider::commandForm() const
{
    return m_commandForm;
}

void DeviceInspectorFormProvider::inspectTemplate(const QString &templateName)
{
    setTemplateName(templateName);
}

void DeviceInspectorFormProvider::inspectDevice(const QString &deviceId)
{
    setDeviceId(deviceId);
}

void DeviceInspectorFormProvider::inspectCommand(DeviceCommand *command)
{
    if (m_command == command && m_commandMap.isEmpty())
        return;

    m_command = command;
    m_commandMap.clear();
    rebuildCommandForm();
}

void DeviceInspectorFormProvider::inspectCommandMap(const QVariantMap &command)
{
    m_command = nullptr;
    m_commandMap = command;
    rebuildCommandForm();
}

DeviceTemplate *DeviceInspectorFormProvider::findTemplate(const QString &templateName) const
{
    if (!m_deviceTemplateModel)
        return nullptr;

    return m_deviceTemplateModel->templateByName(templateName);
}

Device *DeviceInspectorFormProvider::findDevice(const QString &deviceId) const
{
    if (!m_deviceModel)
        return nullptr;

    return m_deviceModel->deviceById(deviceId);
}

DeviceTemplate *DeviceInspectorFormProvider::templateForDevice(const Device *device) const
{
    return device ? findTemplate(device->templateName()) : nullptr;
}

QString DeviceInspectorFormProvider::firstTemplateName() const
{
    if (!m_deviceTemplateModel)
        return QString();

    if (DeviceTemplate *deviceTemplate = m_deviceTemplateModel->templateAt(0))
        return deviceTemplate->name();

    return QString();
}

void DeviceInspectorFormProvider::rebuildTemplateForms()
{
    const DeviceTemplate *deviceTemplate = findTemplate(m_templateName);
    replaceForm(m_templateForm, buildTemplateForm(deviceTemplate));
    replaceForm(m_templateConfigForm, buildTemplateConfigForm(deviceTemplate));
    emit templateFormChanged();
    emit templateConfigFormChanged();
}

void DeviceInspectorFormProvider::rebuildDeviceForm()
{
    replaceForm(m_deviceForm, buildDeviceForm(findDevice(m_deviceId)));
    emit deviceFormChanged();
}

void DeviceInspectorFormProvider::rebuildCommandForm()
{
    EarthUI::AppForm *nextForm = nullptr;
    if (m_command)
        nextForm = buildCommandForm(m_command);
    else
        nextForm = buildCommandMapForm(m_commandMap);

    replaceForm(m_commandForm, nextForm);
    emit commandFormChanged();
}

EarthUI::AppForm *DeviceInspectorFormProvider::buildTemplateForm(const DeviceTemplate *deviceTemplate)
{
    auto *form = makeForm(tr("Template"));
    auto *summarySection = makeSection(form, tr("Template"));
    summarySection->appendField(makeSummaryField(QStringLiteral("name"),
                                                 tr("Name"),
                                                 deviceTemplate ? deviceTemplate->name() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("deviceType"),
                                                 tr("Device Type"),
                                                 deviceTemplate ? deviceTemplate->deviceType() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("protocol"),
                                                 tr("Protocol"),
                                                 deviceTemplate ? deviceTemplate->protocol() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("description"),
                                                 tr("Description"),
                                                 deviceTemplate ? deviceTemplate->description() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("configCount"),
                                                 tr("Config Count"),
                                                 deviceTemplate ? deviceTemplate->configSpecObjects().size() : 0));

    auto *configSection = makeSection(form, tr("Fixed Config"));
    if (deviceTemplate) {
        const QList<DeviceParamSpec *> specs = deviceTemplate->configSpecObjects();
        for (const DeviceParamSpec *spec : specs)
            appendParamSpecField(configSection, spec, spec ? spec->defaultValue() : QVariant(), true);
    }
    return form;
}

EarthUI::AppForm *DeviceInspectorFormProvider::buildTemplateConfigForm(const DeviceTemplate *deviceTemplate)
{
    auto *form = makeForm();
    form->setLayoutMode(EarthUI::AppForm::Horizontal);
    form->setLabelWidth(112);
    form->setFieldSpacing(12);
    form->setShowFieldDividers(true);

    auto *configSection = makeSection(form, QString());
    configSection->setLayoutMode(EarthUI::AppFormSection::Horizontal);
    configSection->setLabelWidth(112);
    configSection->setFieldSpacing(12);
    configSection->setShowFieldDividers(true);

    if (deviceTemplate) {
        const QList<DeviceParamSpec *> specs = deviceTemplate->configSpecObjects();
        for (const DeviceParamSpec *spec : specs)
            appendParamSpecField(configSection, spec, spec ? spec->defaultValue() : QVariant());
    }
    return form;
}

EarthUI::AppForm *DeviceInspectorFormProvider::buildDeviceForm(const Device *device)
{
    auto *form = makeForm(tr("Device"));
    auto *summarySection = makeSection(form, tr("Device"));
    summarySection->appendField(makeSummaryField(QStringLiteral("id"), tr("ID"), device ? device->id() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("name"), tr("Name"), device ? device->name() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("deviceType"), tr("Device Type"), device ? device->deviceType() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("templateName"), tr("Template"), device ? device->templateName() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("protocol"), tr("Protocol"), device ? device->protocol() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("address"), tr("Address"), device ? device->address() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("status"), tr("Status"), device ? device->status() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("lastSeen"), tr("Last Seen"), device ? device->lastSeen() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("capabilities"), tr("Capabilities"), device ? device->capabilities() : QVariant()));

    auto *configSection = makeSection(form, tr("Config Values"));
    if (!device)
        return form;

    QVariantMap remainingValues = device->configValues();
    if (DeviceTemplate *deviceTemplate = templateForDevice(device)) {
        const QList<DeviceParamSpec *> specs = deviceTemplate->configSpecObjects();
        for (const DeviceParamSpec *spec : specs) {
            if (!spec || spec->key().isEmpty())
                continue;

            appendParamSpecField(configSection,
                                 spec,
                                 remainingValues.value(spec->key(), spec->defaultValue()));
            remainingValues.remove(spec->key());
        }
    }

    QStringList keys = remainingValues.keys();
    keys.sort(Qt::CaseInsensitive);
    for (const QString &key : keys)
        configSection->appendField(makeSummaryField(key, key, remainingValues.value(key)));

    return form;
}

EarthUI::AppForm *DeviceInspectorFormProvider::buildCommandForm(const DeviceCommand *command)
{
    auto *form = makeForm(tr("Command"));
    auto *summarySection = makeSection(form, tr("Command"));
    summarySection->appendField(makeSummaryField(QStringLiteral("name"), tr("Name"), command ? command->name() : QVariant()));
    summarySection->appendField(makeSummaryField(QStringLiteral("protocol"), tr("Protocol"), command ? command->protocol() : QVariant()));

    if (!command)
        return form;

    auto *creationSection = makeSection(form, tr("Creation Parameters"));
    const QVariantList creationFields = command->creationInputFields();
    for (const QVariant &fieldValue : creationFields) {
        const DeviceParamSpec *spec = objectFromVariant<DeviceParamSpec>(fieldValue);
        appendParamSpecField(creationSection, spec, spec ? spec->value() : QVariant());
    }

    auto *executionSection = makeSection(form, tr("Execution Parameters"));
    const QVariantList executionFields = command->executionInputFields();
    for (const QVariant &fieldValue : executionFields) {
        const DeviceParamSpec *spec = objectFromVariant<DeviceParamSpec>(fieldValue);
        appendParamSpecField(executionSection, spec, spec ? spec->value() : QVariant());
    }

    return form;
}

EarthUI::AppForm *DeviceInspectorFormProvider::buildCommandMapForm(const QVariantMap &command)
{
    auto *form = makeForm(tr("Command"));
    auto *summarySection = makeSection(form, tr("Command"));

    const QStringList preferredKeys{
        QStringLiteral("name"),
        QStringLiteral("protocol"),
        QStringLiteral("templateId"),
        QStringLiteral("targetDeviceName"),
        QStringLiteral("targetDeviceAddress"),
        QStringLiteral("startTimeMs"),
        QStringLiteral("durationMs")
    };

    QStringList consumedKeys;
    for (const QString &key : preferredKeys) {
        if (!command.contains(key))
            continue;

        summarySection->appendField(makeSummaryField(key, key, command.value(key)));
        consumedKeys.append(key);
    }

    QStringList keys = command.keys();
    keys.sort(Qt::CaseInsensitive);
    for (const QString &key : keys) {
        if (consumedKeys.contains(key) || key == QStringLiteral("params"))
            continue;

        summarySection->appendField(makeSummaryField(key, key, command.value(key)));
    }

    const QVariantMap params = command.value(QStringLiteral("params")).toMap();
    if (!params.isEmpty()) {
        auto *paramsSection = makeSection(form, tr("Parameters"));
        QStringList paramKeys = params.keys();
        paramKeys.sort(Qt::CaseInsensitive);
        for (const QString &key : paramKeys)
            paramsSection->appendField(makeSummaryField(key, key, params.value(key)));
    }

    return form;
}

EarthUI::AppForm *DeviceInspectorFormProvider::makeForm(const QString &title, const QString &subtitle) const
{
    auto *form = new EarthUI::AppForm(const_cast<DeviceInspectorFormProvider *>(this));
    form->setTitle(title);
    form->setSubtitle(subtitle);
    form->setSurfaceMode(EarthUI::AppForm::Bare);
    form->setLayoutMode(EarthUI::AppForm::Vertical);
    form->setShowFieldDividers(false);
    form->setShowHeaderDivider(false);
    form->setLabelWidth(124);
    form->setFieldSpacing(8);
    form->setSectionSpacing(12);
    return form;
}

EarthUI::AppFormSection *DeviceInspectorFormProvider::makeSection(EarthUI::AppForm *form, const QString &title) const
{
    if (!form)
        return nullptr;

    auto *section = new EarthUI::AppFormSection(form);
    section->setTitle(title);
    section->setLayoutMode(EarthUI::AppFormSection::Vertical);
    section->setShowFieldDividers(false);
    form->appendSection(section);
    return section;
}

EarthUI::AppFormField *DeviceInspectorFormProvider::makeSummaryField(const QString &key,
                                                                     const QString &label,
                                                                     const QVariant &value,
                                                                     const QString &subtitle) const
{
    auto *field = new EarthUI::AppFormField;
    field->setKind(EarthUI::AppFormField::Summary);
    field->setKey(key);
    field->setLabel(label);
    field->setSubtitle(subtitle);
    field->setValue(displayValue(value));
    field->setReadOnly(true);
    field->setSurfaceTone(QStringLiteral("surface"));
    return field;
}

EarthUI::AppFormField *DeviceInspectorFormProvider::makeGhostTextField(const QString &key,
                                                                       const QString &label,
                                                                       const QVariant &value,
                                                                       const QString &subtitle) const
{
    auto *field = new EarthUI::AppFormField;
    field->setKind(EarthUI::AppFormField::TextField);
    field->setKey(key);
    field->setLabel(label);
    field->setSubtitle(subtitle);
    field->setValue(displayValue(value));
    field->setReadOnly(true);
    field->setAppearance(EarthUI::AppFormField::Ghost);
    field->setSurfaceTone(QStringLiteral("ghost"));
    return field;
}

void DeviceInspectorFormProvider::appendParamSpecField(EarthUI::AppFormSection *section,
                                                       const DeviceParamSpec *spec,
                                                       const QVariant &value,
                                                       bool useGhostValue) const
{
    if (!section || !spec)
        return;

    auto *field = useGhostValue
        ? makeGhostTextField(spec->key(), spec->label(), value, specSubtitle(spec))
        : makeSummaryField(spec->key(), spec->label(), value, specSubtitle(spec));
    QVariantMap customData;
    customData.insert(QStringLiteral("valueType"), spec->typeName());
    customData.insert(QStringLiteral("required"), spec->required());
    customData.insert(QStringLiteral("readOnly"), spec->readOnly());
    if (!spec->options().isEmpty())
        customData.insert(QStringLiteral("options"), optionsText(spec->options()));
    field->setCustomData(customData);
    section->appendField(field);
}

} // namespace TimelineControl
