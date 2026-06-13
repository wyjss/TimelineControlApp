#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>

namespace EarthUI {

class AppMenuCustomBlock : public QObject
{
    Q_OBJECT

    //! 内容块标题。
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    //! 内容块副标题。
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged)
    //! 正式菜单 block 类型，和 Foundation.AppUiEnums.MenuBlockKind 对齐。
    Q_PROPERTY(int menuBlockKind READ menuBlockKind CONSTANT FINAL)
    //! 自定义内容委托地址。
    Q_PROPERTY(QUrl delegateSource READ delegateSource WRITE setDelegateSource NOTIFY delegateSourceChanged)
    //! 自定义内容控制器。
    Q_PROPERTY(QObject *controller READ controller WRITE setController NOTIFY controllerChanged)
    //! 自定义内容附加数据。
    Q_PROPERTY(QVariantMap blockData READ blockData WRITE setBlockData NOTIFY blockDataChanged)

public:
    explicit AppMenuCustomBlock(QObject *parent = nullptr);

    QString title() const;
    void setTitle(const QString &title);

    QString subtitle() const;
    void setSubtitle(const QString &subtitle);

    int menuBlockKind() const;

    QUrl delegateSource() const;
    void setDelegateSource(const QUrl &delegateSource);

    QObject *controller() const;
    void setController(QObject *controller);

    QVariantMap blockData() const;
    void setBlockData(const QVariantMap &blockData);

signals:
    void titleChanged();
    void subtitleChanged();
    void delegateSourceChanged();
    void controllerChanged();
    void blockDataChanged();

private:
    QString m_title;
    QString m_subtitle;
    QUrl m_delegateSource;
    QObject *m_controller = nullptr;
    QVariantMap m_blockData;
};

} // namespace EarthUI
