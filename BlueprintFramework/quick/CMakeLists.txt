find_package(Qt5 5.14 REQUIRED COMPONENTS Quick QuickControls2)

add_library(BlueprintQuick STATIC
    include/Blueprint/GraphEditSession.h
    src/GraphEditSession.cpp
    BlueprintQuick.qrc
    qml/GraphEditor.qml
    qml/NodeDragSource.qml
    qml/internal/GraphCanvas.qml
    qml/internal/GraphNode.qml
    qml/internal/ConnectionLayer.qml
)
add_library(Blueprint::Quick ALIAS BlueprintQuick)
set_target_properties(BlueprintQuick PROPERTIES AUTOMOC ON AUTORCC ON EXPORT_NAME Quick)
target_include_directories(BlueprintQuick PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(BlueprintQuick PUBLIC BlueprintCore Qt5::Quick Qt5::QuickControls2)

install(TARGETS BlueprintQuick EXPORT BlueprintTargets ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
