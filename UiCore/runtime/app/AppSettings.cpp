#include "AppSettings.h"

namespace EarthUI {

AppSettings::AppSettings(QObject *parent)
    : QObject(parent)
{
}

QString AppSettings::applicationName() const
{
    return m_applicationName;
}

void AppSettings::setApplicationName(const QString &applicationName)
{
    if (m_applicationName == applicationName)
        return;

    m_applicationName = applicationName;
    emit applicationNameChanged();
}

QString AppSettings::locale() const
{
    return m_locale;
}

void AppSettings::setLocale(const QString &locale)
{
    if (m_locale == locale)
        return;

    m_locale = locale;
    emit localeChanged();
}

QString AppSettings::themeMode() const
{
    return m_themeMode;
}

void AppSettings::setThemeMode(const QString &themeMode)
{
    if (m_themeMode == themeMode)
        return;

    m_themeMode = themeMode;
    emit themeModeChanged();
}

QString AppSettings::workspaceRoot() const
{
    return m_workspaceRoot;
}

void AppSettings::setWorkspaceRoot(const QString &workspaceRoot)
{
    if (m_workspaceRoot == workspaceRoot)
        return;

    m_workspaceRoot = workspaceRoot;
    emit workspaceRootChanged();
}

QVariantMap AppSettings::featureFlags() const
{
    return m_featureFlags;
}

void AppSettings::setFeatureFlags(const QVariantMap &featureFlags)
{
    if (m_featureFlags == featureFlags)
        return;

    m_featureFlags = featureFlags;
    emit featureFlagsChanged();
}

QVariantMap AppSettings::values() const
{
    return m_values;
}

void AppSettings::setValues(const QVariantMap &values)
{
    if (m_values == values)
        return;

    m_values = values;
    emit valuesChanged();
}

QVariant AppSettings::value(const QString &key, const QVariant &fallback) const
{
    const QString normalizedKey = key.trimmed();
    if (normalizedKey.isEmpty())
        return fallback;

    if (normalizedKey == QStringLiteral("applicationName"))
        return m_applicationName.isEmpty() ? fallback : QVariant(m_applicationName);

    if (normalizedKey == QStringLiteral("locale"))
        return m_locale.isEmpty() ? fallback : QVariant(m_locale);

    if (normalizedKey == QStringLiteral("themeMode"))
        return m_themeMode.isEmpty() ? fallback : QVariant(m_themeMode);

    if (normalizedKey == QStringLiteral("workspaceRoot"))
        return m_workspaceRoot.isEmpty() ? fallback : QVariant(m_workspaceRoot);

    const QString featureFlagPrefix = QStringLiteral("featureFlags.");
    if (normalizedKey.startsWith(featureFlagPrefix)) {
        const QString featureKey = normalizedKey.mid(featureFlagPrefix.size());
        return m_featureFlags.value(featureKey, fallback);
    }

    return m_values.value(normalizedKey, fallback);
}

} // namespace EarthUI
