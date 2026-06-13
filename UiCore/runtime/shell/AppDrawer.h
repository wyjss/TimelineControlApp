#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>

namespace EarthUI {

class AppDrawer final : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString key READ key WRITE setKey NOTIFY keyChanged FINAL)
    Q_PROPERTY(QString label READ label WRITE setLabel NOTIFY labelChanged FINAL)
    Q_PROPERTY(QString iconName READ iconName WRITE setIconName NOTIFY iconNameChanged FINAL)
    Q_PROPERTY(QString detail READ detail WRITE setDetail NOTIFY detailChanged FINAL)
    Q_PROPERTY(QVariantMap leftPaneData READ leftPaneData WRITE setLeftPaneData NOTIFY leftPaneDataChanged FINAL)
    Q_PROPERTY(QUrl paneDelegateSource READ paneDelegateSource WRITE setPaneDelegateSource NOTIFY paneDelegateSourceChanged FINAL)
    Q_PROPERTY(QObject *paneController READ paneController WRITE setPaneController NOTIFY paneControllerChanged FINAL)

public:
    explicit AppDrawer(QObject *parent = nullptr);

    QString key() const;
    void setKey(const QString &key);

    QString label() const;
    void setLabel(const QString &label);

    QString iconName() const;
    void setIconName(const QString &iconName);

    QString detail() const;
    void setDetail(const QString &detail);

    QVariantMap leftPaneData() const;
    void setLeftPaneData(const QVariantMap &leftPaneData);

    QUrl paneDelegateSource() const;
    void setPaneDelegateSource(const QUrl &paneDelegateSource);

    QObject *paneController() const;
    void setPaneController(QObject *paneController);

    QVariantMap toVariantMap() const;

signals:
    void keyChanged();
    void labelChanged();
    void iconNameChanged();
    void detailChanged();
    void leftPaneDataChanged();
    void paneDelegateSourceChanged();
    void paneControllerChanged();

private:
    QString m_key;
    QString m_label;
    QString m_iconName;
    QString m_detail;
    QVariantMap m_leftPaneData;
    QUrl m_paneDelegateSource;
    QObject *m_paneController = nullptr;
};

} // namespace EarthUI
