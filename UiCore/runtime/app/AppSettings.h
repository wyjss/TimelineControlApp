#pragma once

#include <QObject>
#include <QVariant>
#include <QVariantMap>

namespace EarthUI {

class AppSettings final : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString applicationName READ applicationName WRITE setApplicationName NOTIFY applicationNameChanged FINAL)
    Q_PROPERTY(QString locale READ locale WRITE setLocale NOTIFY localeChanged FINAL)
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged FINAL)
    Q_PROPERTY(QString workspaceRoot READ workspaceRoot WRITE setWorkspaceRoot NOTIFY workspaceRootChanged FINAL)
    Q_PROPERTY(QVariantMap featureFlags READ featureFlags WRITE setFeatureFlags NOTIFY featureFlagsChanged FINAL)
    Q_PROPERTY(QVariantMap values READ values WRITE setValues NOTIFY valuesChanged FINAL)

public:
    explicit AppSettings(QObject *parent = nullptr);

    QString applicationName() const;
    void setApplicationName(const QString &applicationName);

    QString locale() const;
    void setLocale(const QString &locale);

    QString themeMode() const;
    void setThemeMode(const QString &themeMode);

    QString workspaceRoot() const;
    void setWorkspaceRoot(const QString &workspaceRoot);

    QVariantMap featureFlags() const;
    void setFeatureFlags(const QVariantMap &featureFlags);

    QVariantMap values() const;
    void setValues(const QVariantMap &values);

    Q_INVOKABLE QVariant value(const QString &key, const QVariant &fallback = QVariant()) const;

signals:
    void applicationNameChanged();
    void localeChanged();
    void themeModeChanged();
    void workspaceRootChanged();
    void featureFlagsChanged();
    void valuesChanged();

private:
    QString m_applicationName;
    QString m_locale;
    QString m_themeMode;
    QString m_workspaceRoot;
    QVariantMap m_featureFlags;
    QVariantMap m_values;
};

} // namespace EarthUI

Q_DECLARE_METATYPE(EarthUI::AppSettings *)
