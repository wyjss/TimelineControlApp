#include <UICore/UICore.h>

#include <QQmlEngine>
#include <QResource>

#include <UICore/Fields/AppField.h>
#include <UICore/Fields/BaseField.h>
#include <UICore/Forms/UiFormEnums.h>
#include <UICore/Style/UiStyleEnums.h>

#include "style/AppIconPaintedItem.h"

using namespace UICore;

static void initializeResources()
{
    Q_INIT_RESOURCE(UICore);
}

void UICore::initialize()
{
    static const bool initialized = []() {
        qmlRegisterUncreatableType<UICore::BaseField>(
            "UICore.Fields",
            1,
            0,
            "BaseField",
            QStringLiteral("BaseField is exposed through AppField.sourceField"));
        qmlRegisterType<UICore::AppField>("UICore.Fields", 1, 0, "AppField");
        qmlRegisterType<UICore::AppIconPaintedItem>(
            "UICore.Internal", 1, 0, "AppIconPaintedItem");
        qmlRegisterUncreatableMetaObject(UICore::UiStyle::staticMetaObject,
                                         "UICore.Style",
                                         1,
                                         0,
                                         "UiStyle",
                                         QStringLiteral("UiStyle only provides enums"));
        qmlRegisterUncreatableMetaObject(UICore::UiForm::staticMetaObject,
                                         "UICore.Forms",
                                         1,
                                         0,
                                         "UiForm",
                                         QStringLiteral("UiForm only provides enums"));
        initializeResources();
        return true;
    }();
    Q_UNUSED(initialized)
}
