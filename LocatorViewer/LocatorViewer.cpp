#include "LocatorViewer.h"

#include "core/LogMacros.h"

#include "ragis/ragis.h"
#include "ragis/quick/RAGisQuick.h"

#include <QGuiApplication>
#include <QMetaObject>
#include <QUrl>
#include <QtMath>
#include <QtQml/qqml.h>
#include <QDebug>
#include <QLineF>

using namespace ragis;
class LocatorViewerLineCallback : public ragis::RagEventCallback
{
public:
    explicit LocatorViewerLineCallback(LocatorViewer* viewer)
        : m_viewer(viewer)
    {
    }

    void start(const QString& name)
    {
        if (m_viewer->hasLineData(name)) {
            m_hasBack = true;
            m_back = m_viewer->getLineData(name);
        } else {
            m_hasBack = false;
        }
        
        if (m_hasPreview)
            m_viewer->removeTarget(m_name);
        m_name = name;
        m_hasStart = false;
        m_hasPreview = false;
        setCursor(!name.isEmpty());
    }

    void onMouseEvent(QMouseEvent& event) override
    {
        if (m_name.isEmpty()
            || getActiveView() != ragis::RagEarth::getInstance()->getView2D())
            return;

        if (event.type() == QEvent::MouseMove) {
            if (m_hasStart) {
                const auto point = getCurrentLLH();
                m_hasPreview = m_viewer->drawLine(
                    m_name, m_start.lon, m_start.lat, point.lon, point.lat);
                if (m_hasPreview)
                    emit m_viewer->lineChanged(
                        m_name, m_start.lon, m_start.lat, point.lon, point.lat, false);
                event.accept();
            }
            return;
        }

        if (event.type() != QEvent::MouseButtonPress)
            return;

        if (event.button() == Qt::RightButton) {
            if (m_hasPreview)
                m_viewer->removeTarget(m_name);
            m_name.clear();
            m_hasStart = false;
            m_hasPreview = false;
            
            if (m_hasBack) {
                m_hasBack = false;
                m_viewer->updateLine(m_back.name,
                                     m_back.startLongitude,
                                     m_back.startLatitude,
                                     m_back.endLongitude,
                                     m_back.endLatitude);
            }

            setCursor(false);
            event.accept();
            return;
        }

        if (event.button() != Qt::LeftButton)
            return;

        const auto point = getCurrentLLH();
        if (!m_hasStart) {
            m_start = point;
            m_hasStart = true;
        } else {
            if (m_viewer->drawLine(m_name, m_start.lon, m_start.lat, point.lon, point.lat))
                emit m_viewer->lineChanged(
                    m_name, m_start.lon, m_start.lat, point.lon, point.lat, true);
            m_name.clear();
            m_hasStart = false;
            m_hasPreview = false;
            setCursor(false);
        }
        event.accept();
    }

private:
    void setCursor(bool active)
    {
        if (m_cursorActive == active)
            return;

        m_cursorActive = active;
        QMetaObject::invokeMethod(QGuiApplication::instance(), [active]() {
            if (active)
                QGuiApplication::setOverrideCursor(Qt::CrossCursor);
            else
                QGuiApplication::restoreOverrideCursor();
        }, Qt::QueuedConnection);
    }

    LocatorViewer* m_viewer = nullptr;
    QString m_name;
    CguVec3 m_start;
    
    bool m_hasStart = false;
    bool m_hasPreview = false;
    bool m_cursorActive = false;

	LocatorViewer::LineData m_back;
	bool m_hasBack = false;
};


namespace
{
    LocatorViewer* g_LocatorViewer = nullptr;
}
LocatorViewer* LocatorViewer::getInstance()
{
    return g_LocatorViewer;
}

void LocatorViewer::initialize()
{
    Q_INIT_RESOURCE(qml);
    ragis::quick::initialize();
    qmlRegisterType<LocatorViewer>("LocatorViewer", 1, 0, "LocatorViewerController");
    qmlRegisterType(QUrl(QStringLiteral("qrc:/LocatorViewer/LocatorViewer.qml")),
                    "LocatorViewer", 1, 0, "LocatorViewer");
}

void LocatorViewer::quit()
{
    ragis::RagEarth::getInstance()->quitRender();
}

LocatorViewer::LocatorViewer(QObject* parent)
    : QObject(parent)
    , m_lineCallback(new LocatorViewerLineCallback(this))
{
    g_LocatorViewer = this;
    auto earth = ragis::RagEarth::getInstance();
    earth->init();
    earth->setMaxRenderFrameRate(30);
    ragis::CreateViewOption option;
    option.name = ragis::DefaultView2D;
    earth->createView(option);

    ragis::Viewpoint vp = {{109.0, 32.7, 0.0}, {0, -90, 4000}};
    earth->getViewpoint()->setHomeViewpoint(vp);
    earth->getViewpoint()->setViewpoint(vp);
   // earth->startRender();
    earth->addEventCallback(m_lineCallback);
}

LocatorViewer::~LocatorViewer()
{
    if (m_lineCallback) {
        m_lineCallback->start(QString());
        ragis::RagEarth::getInstance()->removeEventCallback(m_lineCallback);
    }
}

bool LocatorViewer::updateTarget(const QString& name,
                                 double longitude,
                                 double latitude,
                                 double heading,
                                 bool online,
                                 const QString& imageUrl)
{
    if (name.isEmpty() || imageUrl.isEmpty())
        return false;

    auto earth = ragis::RagEarth::getInstance();
    auto view = earth->getView2D();
    if (!view)
        return false;

   // if (!earth->getEntity(name, false)) 
    {
        auto vp = earth->getViewpoint()->getViewpoint();
        vp.eye.x = longitude;
        vp.eye.y = latitude;
        vp.eye.z = 0;
        vp.hpd = {0, -90, 100};
        RagEarth::getViewpointIns()->setHomeViewpoint(vp);
    }
    auto entity = earth->getEntity(name, true);
    entity->setMaxPoseCount(5000);

    entity->get<ragis::RagHisTrack>("", true)->setColor(Qt::red);
    entity->get<ragis::RagHisTrack>("", true)->setType(Track_Line);
    entity->get<ragis::RagHisTrack>("", true)->setSize(3);

	static double s_longitude = 0;
	static double s_latitude = 0;
	static CguVec3 s_world = {0, 0, 0};
	static CguVec3 s_f_world = {0, 0, 0};
	CguVec3 curWorld;
	earth->getView2D()->convLLHToWorld({longitude, latitude, 0},
									   curWorld);
    if (s_f_world == CguVec3{0, 0, 0}) {
        s_f_world = curWorld;
    }
    LOG_INFO("移动距离： " << (curWorld - s_world).GetMod() 
    <<"，原点距离：" << (curWorld - s_f_world).GetMod());

    s_world = curWorld;

    entity->updatePose({{longitude, latitude, 0.0}, {heading, 0.0, 0.0}});
    auto image = entity->get<ragis::RagImage>(QString(), true);
    image->setFileName(imageUrl);
    ragis::AutoTransParam transform;
    transform.autoScale = true;
    transform.size = 40.0f;
    image->setAutoTrans(transform);
    image->detachAll();
    image->attachView(view);

    auto label = entity->get<ragis::RagLabel>(QString(), true);
    DocumentLayout layout;
    layout.rows.resize(2);
    layout.rows[0].fields.resize(2);

    label->setLayout(layout);
    label->setText(0, name);
	label->setText(1, online ? "${绿点.png}" : "${红点.png}");
    label->setText(2, QString("朝向:%1").arg(int(heading)));

    return true;
}

void LocatorViewer::removeTarget(const QString& name)
{
    removeLineData(name);
    if (name.isEmpty()) {
        return;
    }
    auto entity = ragis::RagEarth::getInstance()->getEntity(name, false);
    if (entity) {
        entity->remove();
    }
}

bool LocatorViewer::updateLine(const QString& name,
                               double startLongitude,
                               double startLatitude,
                               double endLongitude,
                               double endLatitude)
{
    return drawLine(name, startLongitude, startLatitude, endLongitude, endLatitude);
}

bool LocatorViewer::drawLine(const QString& name,
                             double startLongitude,
                             double startLatitude,
                             double endLongitude,
                             double endLatitude)
{
    if (name.isEmpty())
        return false;

    auto earth = ragis::RagEarth::getInstance();
    auto view = earth->getView2D();
    if (!view)
        return false;

    ragis::GeometryData geometry;
    geometry.type = ragis::Geometry_Line;
    geometry.text = name;
    geometry.points = {
        {startLongitude, startLatitude, 0.0},
        {endLongitude, endLatitude, 0.0}
    };

    ragis::GeometryStyle style;
    style.clamping = true;
    style.line.size = 4.0;
    style.lineStyle = Qt::DashLine;
    style.text = {32.0f, style.line.color};
    style.textIAnchor = true;
    style.textOAnchor = true;
    auto entity = earth->getEntity(name, true);
    auto graphics = entity->get<ragis::RagGraphics>(QString(), true);
    graphics->clearGeometry();
    graphics->addGeometry(style, geometry);

    const double middleLongitude = (startLongitude + endLongitude) / 2.0;
    const double middleLatitude = (startLatitude + endLatitude) / 2.0;
    const double longitudeScale = qCos(qDegreesToRadians(middleLatitude));
    const double east = (endLongitude - startLongitude) * longitudeScale;
    const double north = endLatitude - startLatitude;
    const double lineLength = qSqrt(east * east + north * north);
    if (lineLength > 0.0 && !qFuzzyIsNull(longitudeScale)) {
        const double directionLongitude = north * 0.2 / longitudeScale;
        const double directionLatitude = -east * 0.2;
        const double lineHeading = qRadiansToDegrees(qAtan2(east, north));
        const int firstHeading = qRound(lineHeading + 450.0) % 360;
        const int secondHeading = (firstHeading + 180) % 360;

        ragis::GeometryStyle directionStyle = style;
        directionStyle.line.size = 2.0;
        directionStyle.lineStyle = Qt::SolidLine;

        ragis::GeometryData direction;
        direction.type = ragis::Geometry_LA;
        direction.points = {
            {middleLongitude, middleLatitude, 0.0},
            {middleLongitude + directionLongitude, middleLatitude + directionLatitude, 0.0}
        };
        graphics->addGeometry(directionStyle, direction);

        direction.points[1] = {
            middleLongitude - directionLongitude, middleLatitude - directionLatitude, 0.0};
        graphics->addGeometry(directionStyle, direction);

        const int headings[] = {firstHeading, secondHeading};
        const CguVec3 positions[] = {
            {middleLongitude + directionLongitude * 1.2,
             middleLatitude + directionLatitude * 1.2, 0.0},
            {middleLongitude - directionLongitude * 1.2,
             middleLatitude - directionLatitude * 1.2, 0.0}
        };
        for (int i = 0; i < 2; ++i) {
            const QString handle = i == 0
                ? QStringLiteral("heading.first") : QStringLiteral("heading.second");
            auto tag = entity->get<ragis::RagTag>(handle, false);
            if (!tag) {
                tag = entity->get<ragis::RagTag>(handle, true);
                tag->detachAll();
                tag->attachView(view);
            }
            tag->setVisible(true);
            tag->setInheritPosition(false);
            tag->setPosition(positions[i]);
            tag->setText(QStringLiteral("%1°").arg(headings[i]));
            tag->setTextSize(32.0f);
            tag->setTextColor(directionStyle.line.color);
            tag->setTextAlign(ragis::Align_CenterCenter);
        }
    } else {
        for (const QString& handle : {
                 QStringLiteral("heading.first"), QStringLiteral("heading.second")}) {
            if (auto tag = entity->get<ragis::RagTag>(handle, false))
                tag->setVisible(false);
        }
    }
    graphics->detachAll();
    graphics->attachView(view);

    auto& lineData = getLineData(name);
    lineData.startLongitude = startLongitude;
    lineData.startLatitude = startLatitude;
    lineData.endLongitude = endLongitude;
    lineData.endLatitude = endLatitude;
    return true;
}

void LocatorViewer::removeline(const QString& name)
{
    removeLineData(name);
}

bool LocatorViewer::startLineDrawing(const QString& name)
{
    if (name.isEmpty() || !ragis::RagEarth::getInstance()->getView2D() || !m_lineCallback)
        return false;

    m_lineCallback->start(name);
    return true;
}

bool LocatorViewer::intersect(
	const QString& lineName,
	double startLon, double startLat,
	double endLon, double endLat
)
{
    if (!hasLineData(lineName)) {
        return false;
    }
    auto d = getLineData(lineName);

	QLineF line1(d.startLongitude * 1000,
				 d.startLatitude * 1000,
				 d.endLongitude * 1000,
				 d.endLatitude * 1000
	);

	QLineF line2(startLon * 1000,
				 startLat * 1000,
				 endLon * 1000,
				 endLat * 1000
	);
    
    QPointF p;
    return line1.intersect(line2, &p) == QLineF::BoundedIntersection;
}

LocatorViewer::LineData& LocatorViewer::getLineData(const QString& name)
{
    for (auto& d : m_lines) {
        if (d.name == name) {
            return d;
        }
    }

    m_lines.push_back({});
    m_lines.back().name = name;
    return m_lines.back();
}

void LocatorViewer::removeLineData(const QString& name)
{
    for (int i = 0; i < m_lines.size(); ++i) {
		if (m_lines[i].name == name) {
            m_lines.removeAt(i);
            break;
		}
	}
}

bool LocatorViewer::hasLineData(const QString& name)
{
	for (int i = 0; i < m_lines.size(); ++i) {
		if (m_lines[i].name == name) {
            return true;
		}
	}
    return false;
}
