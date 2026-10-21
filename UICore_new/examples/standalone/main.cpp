#include <QApplication>
#include <QCoreApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardItemModel>
#include <QQuickWindow>
#include <QTimer>
#include <QUrl>

#include <UICore/Fields/AppField.h>
#include <UICore/Forms/AppForm.h>
#include <UICore/Forms/AppMenuCustomBlock.h>
#include <UICore/Forms/AppMenuModel.h>
#include <UICore/UICore.h>

namespace {

UICore::AppField *appendField(UICore::AppForm *form,
                              const QString &key,
                              UICore::AppField::Kind kind,
                              const QString &label,
                              const QString &subtitle = QString())
{
    auto *field = new UICore::AppField;
    field->setKey(key);
    field->setKind(kind);
    field->setLabel(label);
    field->setSubtitle(subtitle);
    form->appendField(field);
    return field;
}

} // namespace

int main(int argc, char *argv[])
{
    //qputenv("QT_QUICK_BACKEND", QByteArray("software"));
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    UICore::initialize();

    QApplication application(argc, argv);
    application.setOrganizationName(QStringLiteral("UICore"));
    application.setOrganizationDomain(QStringLiteral("uicore.local"));
    application.setApplicationName(QStringLiteral("UICore Standalone"));

    QQmlApplicationEngine engine;
    auto *layerMenuModel = new UICore::AppMenuModel(&engine);
    layerMenuModel->setTitle(QStringLiteral("图层"));
    layerMenuModel->setSubtitle(QStringLiteral("当前地图中的运行时图层。"));
    layerMenuModel->setPaneWidth(360);

    auto *layerBlock = new UICore::AppMenuCustomBlock;
    layerBlock->setDelegateSource(
        QUrl(QStringLiteral("qrc:/UICore/qml/standalone/UICoreLayerMenuDemoBlock.qml")));
    layerMenuModel->appendBlock(layerBlock);
    engine.rootContext()->setContextProperty(QStringLiteral("layerMenuModel"), layerMenuModel);

    auto *sceneMenuModel = new UICore::AppMenuModel(&engine);
    sceneMenuModel->setTitle(QStringLiteral("场景"));
    sceneMenuModel->setSubtitle(QStringLiteral("当前视图、相机与渲染环境。"));
    sceneMenuModel->setPaneWidth(336);

    auto *viewForm = new UICore::AppForm;
    viewForm->setTitle(QStringLiteral("当前视图"));
    viewForm->setSubtitle(QStringLiteral("查看当前视图并切换地图配置。"));
    viewForm->setLayoutMode(UICore::UiStyle::LayoutMode::Vertical);
    appendField(viewForm,
                QStringLiteral("currentView"),
                UICore::AppField::Kind::Summary,
                QStringLiteral("视图"))
        ->setValue(QStringLiteral("三维视图"));
    auto *mapField = appendField(viewForm,
                                 QStringLiteral("mapName"),
                                 UICore::AppField::Kind::Select,
                                 QStringLiteral("地图配置"));
    mapField->setValue(QStringLiteral("城市基础地图"));
    mapField->setOptions({
        QVariantMap{{QStringLiteral("label"), QStringLiteral("城市基础地图")},
                    {QStringLiteral("value"), QStringLiteral("城市基础地图")}},
        QVariantMap{{QStringLiteral("label"), QStringLiteral("影像地图")},
                    {QStringLiteral("value"), QStringLiteral("影像地图")}},
        QVariantMap{{QStringLiteral("label"), QStringLiteral("地形分析")},
                    {QStringLiteral("value"), QStringLiteral("地形分析")}}
    });
    auto *reloadMapField = appendField(
        viewForm, QString(), UICore::AppField::Kind::Button, QString());
    reloadMapField->setValue(QStringLiteral("重新加载地图"));
    reloadMapField->setActionId(QStringLiteral("scene.reloadMap"));
    reloadMapField->setVariant(UICore::UiStyle::ButtonVariant::Subtle);
    sceneMenuModel->appendBlock(viewForm);

    auto *cameraForm = new UICore::AppForm;
    cameraForm->setTitle(QStringLiteral("相机"));
    cameraForm->setSubtitle(QStringLiteral("检查当前视点并设置主页位置。"));
    cameraForm->setCollapsible(true);
    cameraForm->setLayoutMode(UICore::UiStyle::LayoutMode::Vertical);
    appendField(cameraForm,
                QStringLiteral("currentViewpoint"),
                UICore::AppField::Kind::Summary,
                QStringLiteral("当前视点"))
        ->setValue(QStringLiteral("116.3913°, 39.9075° · 1200 m"));
    auto *refreshViewpointField = appendField(
        cameraForm, QString(), UICore::AppField::Kind::Button, QString());
    refreshViewpointField->setValue(QStringLiteral("刷新视点信息"));
    refreshViewpointField->setActionId(QStringLiteral("scene.refreshViewpoint"));
    refreshViewpointField->setVariant(UICore::UiStyle::ButtonVariant::Ghost);
    auto *homeViewpointField = appendField(
        cameraForm, QString(), UICore::AppField::Kind::Button, QString());
    homeViewpointField->setValue(QStringLiteral("将当前位置设为主页"));
    homeViewpointField->setActionId(QStringLiteral("scene.setHomeViewpoint"));
    homeViewpointField->setVariant(UICore::UiStyle::ButtonVariant::Tonal);
    sceneMenuModel->appendBlock(cameraForm);

    auto *environmentForm = new UICore::AppForm;
    environmentForm->setTitle(QStringLiteral("渲染环境"));
    environmentForm->setSubtitle(QStringLiteral("控制全局天空、光照与大气效果。"));
    environmentForm->setShowFieldDividers(true);
    appendField(environmentForm,
                QStringLiteral("sunVisible"),
                UICore::AppField::Kind::Toggle,
                QStringLiteral("太阳"))
        ->setValue(true);
    appendField(environmentForm,
                QStringLiteral("moonVisible"),
                UICore::AppField::Kind::Toggle,
                QStringLiteral("月亮"))
        ->setValue(true);
    appendField(environmentForm,
                QStringLiteral("starVisible"),
                UICore::AppField::Kind::Toggle,
                QStringLiteral("星星"))
        ->setValue(true);
    appendField(environmentForm,
                QStringLiteral("atmosphereEnabled"),
                UICore::AppField::Kind::Toggle,
                QStringLiteral("大气"))
        ->setValue(true);
    appendField(environmentForm,
                QStringLiteral("lightingEnabled"),
                UICore::AppField::Kind::Toggle,
                QStringLiteral("光照"))
        ->setValue(false);
    appendField(environmentForm,
                QStringLiteral("shadowEnabled"),
                UICore::AppField::Kind::Toggle,
                QStringLiteral("阴影"))
        ->setValue(false);
    sceneMenuModel->appendBlock(environmentForm);

    auto *performanceForm = new UICore::AppForm;
    performanceForm->setTitle(QStringLiteral("渲染性能"));
    performanceForm->setCollapsible(true);
    performanceForm->setLayoutMode(UICore::UiStyle::LayoutMode::Vertical);
    auto *frameRateField = appendField(performanceForm,
                                       QStringLiteral("maxRenderFrameRate"),
                                       UICore::AppField::Kind::Slider,
                                       QStringLiteral("最大帧率"));
    frameRateField->setValue(60);
    frameRateField->setMinimum(1);
    frameRateField->setMaximum(120);
    frameRateField->setStepSize(5);
    frameRateField->setSuffix(QStringLiteral(" FPS"));
    sceneMenuModel->appendBlock(performanceForm);
    engine.rootContext()->setContextProperty(QStringLiteral("sceneMenuModel"), sceneMenuModel);

    auto *scrollMenuModel = new UICore::AppMenuModel(&engine);
    scrollMenuModel->setTitle(QStringLiteral("滚动条测试"));
    scrollMenuModel->setSubtitle(QStringLiteral("AppMenuPane 长内容"));
    scrollMenuModel->setPaneWidth(360);

    auto *scrollForm = new UICore::AppForm;
    scrollForm->setTitle(QStringLiteral("滚动字段"));

    for (int index = 0; index < 20; ++index) {
        auto *field = new UICore::AppField;
        field->setKey(QStringLiteral("scroll_%1").arg(index));
        field->setLabel(QStringLiteral("测试项 %1").arg(index + 1));
        field->setValue(QStringLiteral("内容 %1").arg(index + 1));
        scrollForm->appendField(field);
    }

    scrollMenuModel->appendBlock(scrollForm);
    engine.rootContext()->setContextProperty(QStringLiteral("scrollMenuModel"), scrollMenuModel);

    auto *treeModel = new QStandardItemModel(&engine);
    treeModel->setItemRoleNames({
        {Qt::DisplayRole, QByteArrayLiteral("display")},
        {Qt::UserRole + 1, QByteArrayLiteral("iconName")}
    });
    auto *componentsItem = new QStandardItem(QStringLiteral("基础组件"));
    auto *controlsItem = new QStandardItem(QStringLiteral("控件"));
    controlsItem->appendRow(new QStandardItem(QStringLiteral("AppButton")));
    controlsItem->appendRow(new QStandardItem(QStringLiteral("AppSelect")));
    componentsItem->appendRow(controlsItem);
    componentsItem->appendRow(new QStandardItem(QStringLiteral("容器")));
    treeModel->appendRow(componentsItem);
    auto *formsItem = new QStandardItem(QStringLiteral("表单"));
    formsItem->appendRow(new QStandardItem(QStringLiteral("AppForm")));
    treeModel->appendRow(formsItem);
    for (auto *item : {componentsItem, controlsItem, componentsItem->child(1), formsItem})
        item->setData(QStringLiteral("folder"), Qt::UserRole + 1);
    for (auto *item : {controlsItem->child(0), controlsItem->child(1), formsItem->child(0)})
        item->setData(QStringLiteral("file"), Qt::UserRole + 1);
    engine.rootContext()->setContextProperty(QStringLiteral("treeModel"), treeModel);

    const QUrl mainUrl(QStringLiteral("qrc:/UICore/qml/standalone/UICoreStandalone.qml"));
    QObject::connect(&engine,
                     &QQmlApplicationEngine::objectCreated,
                     &application,
                     [mainUrl](QObject *object, const QUrl &url) {
                         if (!object && url == mainUrl)
                             QCoreApplication::exit(-1);
                      },
                      Qt::QueuedConnection);
    engine.load(mainUrl);

    if (application.arguments().contains(QStringLiteral("--smoke-test")))
        QTimer::singleShot(5000, &application, &QCoreApplication::quit);

    return application.exec();
}
