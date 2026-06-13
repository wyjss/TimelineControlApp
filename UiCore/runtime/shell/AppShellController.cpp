#include "AppShellController.h"

#include <utility>

#include "AppDrawer.h"

namespace {

QString drawerKey(const QVariantMap &drawerData)
{
    return drawerData.value(QStringLiteral("key")).toString().trimmed();
}

bool variantWrapsQObject(const QVariant &value)
{
    return value.isValid() && value.canConvert<QObject *>();
}

} // namespace

namespace EarthUI {

AppShellController::AppShellController(QObject *parent)
    : QObject(parent)
{
}

QString AppShellController::activeDrawerKey() const
{
    return m_activeDrawerKey;
}

void AppShellController::setActiveDrawerKey(const QString &key)
{
    const QString normalizedKey = normalizeDrawerKey(key);
    if (!key.trimmed().isEmpty() && normalizedKey.isEmpty())
        return;

    if (m_activeDrawerKey == normalizedKey)
        return;

    m_activeDrawerKey = normalizedKey;
    emit activeDrawerKeyChanged();
}

bool AppShellController::drawerOpen() const
{
    return m_drawerOpen;
}

void AppShellController::setDrawerOpen(bool open)
{
    if (m_drawerOpen == open)
        return;

    m_drawerOpen = open;
    emit drawerOpenChanged();
}

bool AppShellController::rightPanelOpen() const
{
    return m_rightPanelOpen;
}

void AppShellController::setRightPanelOpen(bool open)
{
    if (m_rightPanelOpen == open)
        return;

    m_rightPanelOpen = open;
    emit rightPanelOpenChanged();
}

bool AppShellController::leftPanelAutoHide() const
{
    return m_leftPanelAutoHide;
}

void AppShellController::setLeftPanelAutoHide(bool enabled)
{
    if (m_leftPanelAutoHide == enabled)
        return;

    m_leftPanelAutoHide = enabled;
    emit leftPanelAutoHideChanged();
}

QString AppShellController::canvasInteractionState() const
{
    return m_canvasInteractionState;
}

void AppShellController::setCanvasInteractionState(const QString &state)
{
    if (m_canvasInteractionState == state)
        return;

    m_canvasInteractionState = state;
    emit canvasInteractionStateChanged();
}

QString AppShellController::leftPaneFilterText() const
{
    return m_leftPaneFilterText;
}

void AppShellController::setLeftPaneFilterText(const QString &text)
{
    if (m_leftPaneFilterText == text)
        return;

    m_leftPaneFilterText = text;
    emit leftPaneFilterTextChanged();
}

QVariantList AppShellController::drawers() const
{
    return m_drawers;
}

QObject *AppShellController::inspectorObject() const
{
    return m_inspectorObject.data();
}

void AppShellController::setInspectorObject(QObject *inspectorObject)
{
    if (m_inspectorObject.data() == inspectorObject)
        return;

    const bool mirrorVariant = !m_inspectorData.isValid()
        || (variantWrapsQObject(m_inspectorData)
            && qvariant_cast<QObject *>(m_inspectorData) == m_inspectorObject.data());

    syncInspectorObject(inspectorObject);

    emit inspectorObjectChanged();

    if (mirrorVariant) {
        const QVariant nextData = inspectorObject
            ? QVariant::fromValue(inspectorObject)
            : QVariant();
        if (m_inspectorData != nextData) {
            m_inspectorData = nextData;
            emit inspectorDataChanged();
        }
    }
}

QVariant AppShellController::inspectorData() const
{
    return m_inspectorData;
}

void AppShellController::setInspectorData(const QVariant &data)
{
    QObject *nextInspectorObject = variantWrapsQObject(data)
        ? qvariant_cast<QObject *>(data)
        : nullptr;
    const bool objectChanged = m_inspectorObject.data() != nextInspectorObject;
    const bool dataChanged = m_inspectorData != data;

    if (!objectChanged && !dataChanged)
        return;

    if (objectChanged) {
        syncInspectorObject(nextInspectorObject);
        emit inspectorObjectChanged();
    }

    if (dataChanged) {
        m_inspectorData = data;
        emit inspectorDataChanged();
    }
}

QVariantMap AppShellController::selectionData() const
{
    return m_selectionData;
}

void AppShellController::setSelectionData(const QVariantMap &data)
{
    if (m_selectionData == data)
        return;

    m_selectionData = data;
    emit selectionDataChanged();
}

void AppShellController::registerDrawer(AppDrawer *drawer)
{
    if (!drawer)
        return;

    for (auto iterator = m_registeredDrawers.begin(); iterator != m_registeredDrawers.end();) {
        if (!(*iterator)) {
            iterator = m_registeredDrawers.erase(iterator);
            continue;
        }

        if (*iterator == drawer)
            return;

        if ((*iterator)->key() == drawer->key() && !drawer->key().trimmed().isEmpty()) {
            disconnectDrawerSignals(*iterator);
            iterator = m_registeredDrawers.erase(iterator);
            continue;
        }

        ++iterator;
    }

    if (!drawer->parent())
        drawer->setParent(this);

    m_registeredDrawers.append(drawer);
    connectDrawerSignals(drawer);
    refreshDrawersFromRegisteredObjects();
}

void AppShellController::unregisterDrawer(const QString &key)
{
    const QString normalizedKey = key.trimmed();
    if (normalizedKey.isEmpty())
        return;

    for (auto iterator = m_registeredDrawers.begin(); iterator != m_registeredDrawers.end(); ++iterator) {
        AppDrawer *drawer = iterator->data();
        if (!drawer || drawer->key() != normalizedKey)
            continue;

        disconnectDrawerSignals(drawer);
        m_registeredDrawers.erase(iterator);
        refreshDrawersFromRegisteredObjects();
        return;
    }
}

void AppShellController::selectDrawer(const QString &key)
{
    const QString normalizedKey = normalizeDrawerKey(key);
    if (normalizedKey.isEmpty())
        return;

    setActiveDrawerKey(normalizedKey);
    setDrawerOpen(true);
}

void AppShellController::toggleRightPanel()
{
    setRightPanelOpen(!m_rightPanelOpen);
}

void AppShellController::handleUiAction(const QString &actionId, const QVariantMap &payload)
{
    emit uiActionTriggered(actionId, payload);
}

void AppShellController::syncInspectorObject(QObject *inspectorObject)
{
    if (m_inspectorObject.data() == inspectorObject)
        return;

    if (m_inspectorObject)
        QObject::disconnect(m_inspectorObject, nullptr, this, nullptr);

    m_inspectorObject = inspectorObject;

    if (m_inspectorObject) {
        QObject *watchedObject = m_inspectorObject.data();
        QObject::connect(watchedObject,
                         &QObject::destroyed,
                         this,
                         [this, watchedObject]() {
                             const bool mirroredVariant = variantWrapsQObject(m_inspectorData)
                                 && qvariant_cast<QObject *>(m_inspectorData) == watchedObject;

                             if (m_inspectorObject.data() == watchedObject) {
                                 m_inspectorObject = nullptr;
                                 emit inspectorObjectChanged();
                             }

                             if (mirroredVariant) {
                                 m_inspectorData = QVariant();
                                 emit inspectorDataChanged();
                             }
                         });
    }
}

QString AppShellController::normalizeDrawerKey(const QString &key) const
{
    const QString candidate = key.trimmed();
    if (candidate.isEmpty())
        return QString();

    for (const QVariant &drawerValue : m_drawers) {
        const QString currentKey = drawerKey(drawerValue.toMap());
        if (currentKey == candidate)
            return currentKey;
    }

    return QString();
}

QString AppShellController::defaultDrawerKey() const
{
    if (m_drawers.isEmpty())
        return QString();

    return drawerKey(m_drawers.constFirst().toMap());
}

AppDrawer *AppShellController::registeredDrawer(const QString &key) const
{
    const QString normalizedKey = key.trimmed();
    if (normalizedKey.isEmpty())
        return nullptr;

    for (const QPointer<AppDrawer> &drawer : m_registeredDrawers) {
        if (drawer && drawer->key() == normalizedKey)
            return drawer;
    }

    return nullptr;
}

void AppShellController::connectDrawerSignals(AppDrawer *drawer)
{
    if (!drawer)
        return;

    const auto refreshHandler = [this]() {
        refreshDrawersFromRegisteredObjects();
    };

    QObject::connect(drawer, &AppDrawer::keyChanged, this, refreshHandler);
    QObject::connect(drawer, &AppDrawer::labelChanged, this, refreshHandler);
    QObject::connect(drawer, &AppDrawer::iconNameChanged, this, refreshHandler);
    QObject::connect(drawer, &AppDrawer::detailChanged, this, refreshHandler);
    QObject::connect(drawer, &AppDrawer::leftPaneDataChanged, this, refreshHandler);
    QObject::connect(drawer, &AppDrawer::paneDelegateSourceChanged, this, refreshHandler);
    QObject::connect(drawer, &AppDrawer::paneControllerChanged, this, refreshHandler);
    QObject::connect(drawer,
                     &QObject::destroyed,
                     this,
                     [this](QObject *drawerObject) {
                         removeRegisteredDrawer(drawerObject);
                     });
}

void AppShellController::disconnectDrawerSignals(AppDrawer *drawer)
{
    if (!drawer)
        return;

    QObject::disconnect(drawer, nullptr, this, nullptr);
}

void AppShellController::refreshDrawersFromRegisteredObjects()
{
    QVariantList nextDrawers;
    QList<QPointer<AppDrawer>> nextRegisteredDrawers;

    for (const QPointer<AppDrawer> &drawer : std::as_const(m_registeredDrawers)) {
        if (!drawer)
            continue;

        const QVariantMap drawerData = drawer->toVariantMap();
        if (drawerKey(drawerData).isEmpty())
            continue;

        nextRegisteredDrawers.append(drawer);
        nextDrawers.append(drawerData);
    }

    m_registeredDrawers = nextRegisteredDrawers;

    if (m_drawers != nextDrawers) {
        m_drawers = nextDrawers;
        emit drawersChanged();
    }

    syncActiveDrawerKeyAfterDrawerChange();
}

void AppShellController::syncActiveDrawerKeyAfterDrawerChange()
{
    const QString normalizedActiveKey = normalizeDrawerKey(m_activeDrawerKey);
    const QString nextActiveKey = normalizedActiveKey.isEmpty() ? defaultDrawerKey() : normalizedActiveKey;
    if (m_activeDrawerKey == nextActiveKey)
        return;

    m_activeDrawerKey = nextActiveKey;
    emit activeDrawerKeyChanged();
}

void AppShellController::removeRegisteredDrawer(QObject *drawerObject)
{
    bool changed = false;

    for (auto iterator = m_registeredDrawers.begin(); iterator != m_registeredDrawers.end();) {
        if (!(*iterator) || iterator->data() == drawerObject) {
            iterator = m_registeredDrawers.erase(iterator);
            changed = true;
            continue;
        }

        ++iterator;
    }

    if (changed)
        refreshDrawersFromRegisteredObjects();
}

} // namespace EarthUI
