#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

namespace EarthUI {

class AppShellRouteState final : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool active READ active NOTIFY routeChanged FINAL)
    Q_PROPERTY(QString dialogKey READ dialogKey NOTIFY routeChanged FINAL)
    Q_PROPERTY(QString mode READ mode NOTIFY routeChanged FINAL)
    Q_PROPERTY(QString targetName READ targetName NOTIFY routeChanged FINAL)
    Q_PROPERTY(QVariantMap payload READ payload NOTIFY routeChanged FINAL)

public:
    explicit AppShellRouteState(QObject *parent = nullptr);

    bool active() const;
    QString dialogKey() const;
    QString mode() const;
    QString targetName() const;
    QVariantMap payload() const;

    //! 设置当前壳层流程目标。
    void setDialogRoute(const QString &dialogKey,
                        const QString &mode = QString(),
                        const QString &targetName = QString(),
                        const QVariantMap &payload = QVariantMap());

    //! 清空当前壳层流程目标。
    Q_INVOKABLE void clear();

signals:
    void routeChanged();

private:
    QString m_dialogKey;
    QString m_mode;
    QString m_targetName;
    QVariantMap m_payload;
};

} // namespace EarthUI
