#pragma once

#include <QColor>
#include <QImage>
#include <QQuickPaintedItem>
#include <QSize>
#include <QUrl>

namespace UICore {

class AppIconPaintedItem : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QSize sourceSize READ sourceSize WRITE setSourceSize NOTIFY sourceSizeChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(bool tintSource READ tintSource WRITE setTintSource NOTIFY tintSourceChanged)
    Q_PROPERTY(bool ready READ isReady NOTIFY readyChanged)
    Q_PROPERTY(bool mipmap READ mipmap WRITE setMipmap)

public:
    explicit AppIconPaintedItem(QQuickItem *parent = nullptr);

    QUrl source() const;
    void setSource(const QUrl &source);

    QSize sourceSize() const;
    void setSourceSize(const QSize &sourceSize);

    QColor color() const;
    void setColor(const QColor &color);

    bool tintSource() const;
    void setTintSource(bool tintSource);

    bool isReady() const;

    void paint(QPainter *painter) override;

signals:
    void sourceChanged();
    void sourceSizeChanged();
    void colorChanged();
    void tintSourceChanged();
    void readyChanged();

private:
    void loadImage();

    QUrl m_source;
    QSize m_sourceSize;
    QColor m_color;
    bool m_tintSource = true;
    QImage m_image;
};

} // namespace UICore
