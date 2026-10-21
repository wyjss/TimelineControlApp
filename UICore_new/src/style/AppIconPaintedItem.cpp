#include "AppIconPaintedItem.h"

#include <QImageReader>
#include <QPainter>

using namespace UICore;

AppIconPaintedItem::AppIconPaintedItem(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setFillColor(Qt::transparent);
}

QUrl AppIconPaintedItem::source() const
{
    return m_source;
}

void AppIconPaintedItem::setSource(const QUrl &source)
{
    if (m_source == source)
        return;

    m_source = source;
    emit sourceChanged();
    loadImage();
}

QSize AppIconPaintedItem::sourceSize() const
{
    return m_sourceSize;
}

void AppIconPaintedItem::setSourceSize(const QSize &sourceSize)
{
    if (m_sourceSize == sourceSize)
        return;

    m_sourceSize = sourceSize;
    emit sourceSizeChanged();
    loadImage();
}

QColor AppIconPaintedItem::color() const
{
    return m_color;
}

void AppIconPaintedItem::setColor(const QColor &color)
{
    if (m_color == color)
        return;

    m_color = color;
    emit colorChanged();
    update();
}

bool AppIconPaintedItem::tintSource() const
{
    return m_tintSource;
}

void AppIconPaintedItem::setTintSource(bool tintSource)
{
    if (m_tintSource == tintSource)
        return;

    m_tintSource = tintSource;
    emit tintSourceChanged();
    update();
}

bool AppIconPaintedItem::isReady() const
{
    return !m_image.isNull();
}

void AppIconPaintedItem::paint(QPainter *painter)
{
    if (m_image.isNull())
        return;

    QSizeF paintedSize = m_image.size();
    paintedSize.scale(QSizeF(width(), height()), Qt::KeepAspectRatio);
    const QRectF targetRect((width() - paintedSize.width()) / 2,
                            (height() - paintedSize.height()) / 2,
                            paintedSize.width(),
                            paintedSize.height());

    painter->setRenderHint(QPainter::SmoothPixmapTransform, smooth());
    painter->drawImage(targetRect, m_image);
    if (m_tintSource) {
        painter->setCompositionMode(QPainter::CompositionMode_SourceIn);
        painter->fillRect(targetRect, m_color);
    }
}

void AppIconPaintedItem::loadImage()
{
    const bool wasReady = isReady();
    m_image = QImage();

    if (!m_source.isEmpty()) {
        QString fileName;
        if (m_source.scheme() == QStringLiteral("qrc"))
            fileName = QStringLiteral(":") + m_source.path();
        else if (m_source.isLocalFile())
            fileName = m_source.toLocalFile();
        else if (m_source.isRelative())
            fileName = m_source.toString();

        QImageReader reader(fileName);
        if (m_sourceSize.isValid()) {
            QSize scaledSize = reader.size();
            if (scaledSize.isValid())
                scaledSize.scale(m_sourceSize, Qt::KeepAspectRatio);
            else
                scaledSize = m_sourceSize;
            reader.setScaledSize(scaledSize);
        }
        m_image = reader.read();
    }

    if (wasReady != isReady())
        emit readyChanged();
    update();
}
