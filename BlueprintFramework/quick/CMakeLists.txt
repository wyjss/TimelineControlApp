find_package(Qt5 5.14 REQUIRED COMPONENTS Quick QuickControls2)

# 让各构建配置使用同一份资源源码，避免切换配置时误用旧 QML。
qt5_add_resources(blueprint_quick_resources BlueprintQuick.qrc)

add_library(BlueprintQuick STATIC
    include/Blueprint/GraphEditSession.h
    src/GraphEditSession.cpp
    BlueprintQuick.qrc
    ${blueprint_quick_resources}
    qml/GraphEditor.qml
    qml/NodeDragSource.qml
    qml/internal/GraphCanvas.qml
    qml/internal/GraphNode.qml
    qml/internal/ConnectionLayer.qml
)
add_library(Blueprint::Quick ALIAS BlueprintQuick)
set_target_properties(BlueprintQuick PROPERTIES AUTOMOC ON EXPORT_NAME Quick)
target_include_directories(BlueprintQuick PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(BlueprintQuick PUBLIC BlueprintCore Qt5::Quick Qt5::QuickControls2)

install(TARGETS BlueprintQuick EXPORT BlueprintTargets ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
