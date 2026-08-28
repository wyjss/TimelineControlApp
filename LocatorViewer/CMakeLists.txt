project(LocatorViewer LANGUAGES CXX)

set(APP_SOURCES)
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR}/ APP_SOURCES . "*.h")
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR}/ APP_SOURCES . "*.cpp")
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR}/ APP_SOURCES . "*.qrc")
qt5_add_resources(APP_SOURCES qml.qrc)

add_executable(${PROJECT_NAME}
	${APP_SOURCES}
	${CMAKE_SOURCE_DIR}/third_party/RAGis2/include/geomutil/guVector.cpp
)

target_include_directories(${PROJECT_NAME} PUBLIC ./)
target_include_directories(${PROJECT_NAME} PUBLIC ../third_party/RAGis2/include)


target_link_directories(${PROJECT_NAME} PRIVATE ../third_party/RAGis2/lib)
target_link_libraries(${PROJECT_NAME} PRIVATE RAGis2 RAGisQuick)

target_link_libraries(${PROJECT_NAME} PRIVATE
	Qt5::Core 
	Qt5::Gui
	Qt5::Widgets
	Qt5::Network
	Qt5::OpenGL
	Qt5::Xml
	Qt5::Quick
	Qt5::QuickControls2
)

file(GLOB RUNTIME_DLLS
    "${CMAKE_SOURCE_DIR}/third_party/RAGis2/bin/*.dll"
    "D:/Program/third_party/all/bin/*.dll"
)
get_target_property(QT_CORE_DLL Qt5::Core IMPORTED_LOCATION_RELEASE)
get_filename_component(QT_RUNTIME_DIR "${QT_CORE_DLL}" DIRECTORY)
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${RUNTIME_DLLS}
        $<TARGET_FILE_DIR:${PROJECT_NAME}>
    COMMAND "${QT_RUNTIME_DIR}/windeployqt.exe"
        --no-translations
        --qmldir "${CMAKE_CURRENT_SOURCE_DIR}"
        $<TARGET_FILE:${PROJECT_NAME}>
)

set_target_properties(${PROJECT_NAME} PROPERTIES
    VS_DEBUGGER_ENVIRONMENT "PATH=\
${CMAKE_SOURCE_DIR}/third_party/RAGis2/bin;\
D:/Program/third_party/all/bin;\
${QT_RUNTIME_DIR};\
%PATH%"
)
