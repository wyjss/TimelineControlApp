#pragma once

#include <QObject>
#include <QString>
#include <QList>

class LocatorViewerLineCallback;

class LocatorViewer : public QObject
{
    Q_OBJECT
public:
    struct LineData {
        QString name;
        double startLongitude;
        double startLatitude;
        double endLongitude;
        double endLatitude;
    };
    static LocatorViewer* getInstance();
    explicit LocatorViewer(QObject* parent = nullptr);
    ~LocatorViewer() override;

    static void initialize();

    //! 新增或更新二维图片目标，heading 单位为度
    Q_INVOKABLE bool updateTarget(const QString& name,
                                  double longitude,
                                  double latitude,
                                  double heading,
                                  bool online = true,
                                  const QString& imageUrl = "船.png");
    Q_INVOKABLE void removeTarget(const QString& name);

    //! 通过两端经纬度新增或更新二维线段
    Q_INVOKABLE bool updateLine(const QString& name,
                                double startLongitude,
                                double startLatitude,
                                double endLongitude,
                                double endLatitude);
    Q_INVOKABLE void removeline(const QString& name);
    
    //! 启动两次左键点选绘制，右键取消
    Q_INVOKABLE bool startLineDrawing(const QString& name);

    bool intersect(const QString& lineName, double startLon, double startLat,
                   double endLon, double endLat
                   );
signals:
    void lineChanged(const QString& name,
                     double startLongitude,
                     double startLatitude,
                     double endLongitude,
                     double endLatitude,
                     bool finished);

private:
    friend class LocatorViewerLineCallback;
    bool drawLine(const QString& name,
                  double startLongitude,
                  double startLatitude,
                  double endLongitude,
                  double endLatitude);

	LineData& getLineData(const QString& name);
	void removeLineData(const QString& name);
	bool hasLineData(const QString& name);
    LocatorViewerLineCallback* m_lineCallback = nullptr;
    QList<LineData> m_lines;
};
