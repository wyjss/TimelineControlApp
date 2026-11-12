find_package(Qt5 5.14 REQUIRED COMPONENTS Quick QuickControls2)

add_library(BlueprintQuick STATIC
    include/Blueprint/GraphEditSession.h
    src/GraphEditSession.cpp
    BlueprintQuick.qrc
    qml/GraphEditor.qml
    qml/internal/GraphCanvas.qml
    qml/internal/GraphNode.qml
    qml/internal/ConnectionLayer.qml
)
set_target_properties(BlueprintQuick PROPERTIES AUTOMOC ON AUTORCC ON)
target_include_directories(BlueprintQuick PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(BlueprintQuick PUBLIC BlueprintCore Qt5::Quick)
