project(LocatorViewer LANGUAGES CXX)

set(RAGIS_ROOT "D:/Program/RA/RAGis2" CACHE PATH "RAGis2 root directory")
set(RAGIS_DEPENDENCY_DIR "D:/Program/third_party/all" CACHE PATH "RAGis2 dependency directory")
set(RAGIS_SOURCE_DIR "${RAGIS_ROOT}/src/RAGis2")
set(RAGIS_OUTPUT_DIR "${RAGIS_ROOT}/build/output")
list(PREPEND CMAKE_PREFIX_PATH "${RAGIS_DEPENDENCY_DIR}")
find_package(OE REQUIRED)

qt5_add_resources(LOCATOR_VIEWER_RESOURCES qml.qrc)

add_library(LocatorViewer STATIC
    LocatorViewer.cpp
    LocatorViewer.h
    ${LOCATOR_VIEWER_RESOURCES}
)

target_include_directories(LocatorViewer
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
    PRIVATE
        ${RAGIS_SOURCE_DIR}
        ${RAGIS_SOURCE_DIR}/ra_depends
)

target_compile_definitions(LocatorViewer PRIVATE RAGISQUICK_STATIC)

target_link_libraries(LocatorViewer PRIVATE
    ${RAGIS_OUTPUT_DIR}/RAGis2.lib
    ${RAGIS_OUTPUT_DIR}/RAGisQuickStatic.lib
    ${RAGIS_OUTPUT_DIR}/ra_depends.lib
    ${OE_TARGETS}
    Qt5::Core
    Qt5::Gui
    Qt5::OpenGL
    Qt5::Qml
    Qt5::Quick
)
