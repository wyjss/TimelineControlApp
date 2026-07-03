#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

namespace EarthUI {

class AppMenuModel : public QObject
{
    Q_OBJECT

    //! 菜单面板标题。
    Q_PROPERTY(QString title READ title WRITE setTitle NOTIFY titleChanged)
    //! 菜单面板副标题。
    Q_PROPERTY(QString subtitle READ subtitle WRITE setSubtitle NOTIFY subtitleChanged)
    //! 菜单面板建议宽度，0 表示使用默认宽度。
    Q_PROPERTY(int paneWidth READ paneWidth WRITE setPaneWidth NOTIFY paneWidthChanged)
    //! 菜单顶部固定内容块列表，不参与滚动。
    Q_PROPERTY(QVariantList fixedTopBlocks READ fixedTopBlocks NOTIFY fixedTopBlocksChanged)
    //! 菜单顶部固定内容块数量。
    Q_PROPERTY(int fixedTopBlockCount READ fixedTopBlockCount NOTIFY fixedTopBlocksChanged)
    //! 菜单滚动内容块列表，可追加 AppForm 或自定义块。
    Q_PROPERTY(QVariantList blocks READ blocks NOTIFY blocksChanged)
    //! 菜单滚动内容块数量。
    Q_PROPERTY(int blockCount READ blockCount NOTIFY blocksChanged)

public:
    explicit AppMenuModel(QObject *parent = nullptr);

    QString title() const;
    void setTitle(const QString &title);

    QString subtitle() const;
    void setSubtitle(const QString &subtitle);

    int paneWidth() const;
    void setPaneWidth(int paneWidth);

    QVariantList blocks() const;
    QVariantList fixedTopBlocks() const;
    int blockCount() const;
    int fixedTopBlockCount() const;
    Q_INVOKABLE QObject *blockAt(int index) const;
    Q_INVOKABLE QObject *fixedTopBlockAt(int index) const;
    Q_INVOKABLE bool setFieldValue(const QString &fieldKey, const QVariant &value);
    void appendBlock(QObject *block);
    void appendFixedTopBlock(QObject *block);
    void clearBlocks();
    void clearFixedTopBlocks();
    Q_INVOKABLE virtual void handleAction(const QString &actionId, const QVariantMap &payload = QVariantMap());
    Q_INVOKABLE virtual void handleFieldEdited(const QString &fieldKey, const QVariant &value);

signals:
    void titleChanged();
    void subtitleChanged();
    void paneWidthChanged();
    void fixedTopBlocksChanged();
    void blocksChanged();

private:
    bool appendBlockObject(QObject *block, bool fixedTop);
    void removeBlockObject(QObject *blockObject);
    void emitBlocksChanged(bool fixedTop);

    QString m_title;
    QString m_subtitle;
    int m_paneWidth = 0;
    QList<QObject *> m_fixedTopBlocks;
    QList<QObject *> m_blocks;
    QVariantList m_fixedTopBlocksCache;
    QVariantList m_blocksCache;
};

} // namespace EarthUI
