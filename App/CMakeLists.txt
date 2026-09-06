include(CollectSources)

set(TIMELINE_APP_SOURCES "")
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR} TIMELINE_APP_SOURCES . *.cpp)
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR} TIMELINE_APP_SOURCES runtime *.cpp)
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR} TIMELINE_APP_SOURCES runtime *.h)
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR}/runtime TIMELINE_APP_SOURCES devices *.cpp)
COLLECT_SOURCES_TYPE(${CMAKE_CURRENT_SOURCE_DIR}/runtime TIMELINE_APP_SOURCES devices *.h)
COLLECT_SOURCES(${CMAKE_CURRENT_SOURCE_DIR}/runtime/devices TIMELINE_APP_SOURCES executors)
COLLECT_SOURCES(${CMAKE_CURRENT_SOURCE_DIR}/runtime/devices TIMELINE_APP_SOURCES backends)
COLLECT_SOURCES(${CMAKE_CURRENT_SOURCE_DIR}/runtime TIMELINE_APP_SOURCES models)
COLLECT_SOURCES(${CMAKE_CURRENT_SOURCE_DIR}/runtime TIMELINE_APP_SOURCES location)
COLLECT_SOURCES(${CMAKE_CURRENT_SOURCE_DIR}/runtime TIMELINE_APP_SOURCES projection)
COLLECT_SOURCES(${CMAKE_CURRENT_SOURCE_DIR}/runtime TIMELINE_APP_SOURCES timeline)
COLLECT_SOURCES(${CMAKE_CURRENT_SOURCE_DIR}/runtime TIMELINE_APP_SOURCES video)
list(REMOVE_ITEM TIMELINE_APP_SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/runtime/LogMacros.cpp")
qt5_add_resources(TIMELINE_APP_RESOURCES App.qrc)

add_executable(TimelineControlApp
    ${TIMELINE_APP_SOURCES}
    ${TIMELINE_APP_RESOURCES}
)

include(server/web/TimelineWebControl.cmake)

target_include_directories(TimelineControlApp PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/runtime
    ${AVRB_INCLUDE_DIR}
)

target_link_libraries(TimelineControlApp PRIVATE
    UICore
    LocatorViewer
    ${AVRB_LIBRARY}
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    Qt5::QuickControls2
    Qt5::Network
    Qt5::Widgets
    Qt5::SerialPort
    spdlog::spdlog
)

set_target_properties(TimelineControlApp PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

file(GLOB AVRB_RUNTIME_DLLS "${AVRB_RUNTIME_DIR}/*.dll")
if(AVRB_RUNTIME_DLLS)
    add_custom_command(TARGET TimelineControlApp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${AVRB_RUNTIME_DLLS}
            $<TARGET_FILE_DIR:TimelineControlApp>
    )
endif()

set(GLEW_RUNTIME_DLL "D:/Program/third_party/all/bin/glew32.dll"
    CACHE FILEPATH "GLEW runtime library"
)
if(EXISTS "${GLEW_RUNTIME_DLL}")
    add_custom_command(TARGET TimelineControlApp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${GLEW_RUNTIME_DLL}"
            $<TARGET_FILE_DIR:TimelineControlApp>
    )
endif()

set_target_properties(TimelineControlApp PROPERTIES
    VS_DEBUGGER_ENVIRONMENT "PATH=\
D:/Program/third_party/ffmpeg/bin;\
${CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE};\
${RAGIS_OUTPUT_DIR};\
$<TARGET_FILE_DIR:Qt5::Core>;"
)



file(GLOB RAGIS_RUNTIME_DLLS
    "${RAGIS_ROOT}/build/output/RAGis2.dll"
    "${RAGIS_ROOT}/build/output/RAGis2.pdb"
    "${RAGIS_DEPENDENCY_DIR}/bin/*.dll"
)
if(false)
    add_custom_command(TARGET TimelineControlApp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${RAGIS_RUNTIME_DLLS}
            $<TARGET_FILE_DIR:TimelineControlApp>
    )
else()
    add_custom_command(TARGET TimelineControlApp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
            ${RAGIS_RUNTIME_DLLS}
            $<TARGET_FILE_DIR:TimelineControlApp>
    )
endif()