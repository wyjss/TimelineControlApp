cmake_minimum_required(VERSION 3.16)

project(TimelineControlApp
    VERSION 0.1.0
    LANGUAGES CXX
)

if(POLICY CMP0144)
    cmake_policy(SET CMP0144 NEW)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(CollectSources)

set(AVRB_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/libavrb")
set(AVRB_INCLUDE_DIR "${AVRB_ROOT}/include/avrb")
set(AVRB_LIBRARY "${AVRB_ROOT}/lib/avrb.lib")
set(AVRB_RUNTIME_DIR "${AVRB_ROOT}/dll")

find_package(Qt5 5.14 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Network
    Widgets
    SerialPort
)

add_subdirectory(UiCore)

qt5_add_resources(TIMELINE_APP_RESOURCES
    App/App.qrc
)

set(TIMELINE_APP_SOURCES "")
COLLECT_SOURCES_TYPE(./App TIMELINE_APP_SOURCES . *.cpp)

set(TIMELINE_RUNTIME_SOURCES "")
COLLECT_SOURCES_TYPE(./App TIMELINE_RUNTIME_SOURCES runtime *.cpp)
COLLECT_SOURCES_TYPE(./App TIMELINE_RUNTIME_SOURCES runtime *.h)
COLLECT_SOURCES_TYPE(./App/runtime TIMELINE_RUNTIME_SOURCES devices *.cpp)
COLLECT_SOURCES_TYPE(./App/runtime TIMELINE_RUNTIME_SOURCES devices *.h)
COLLECT_SOURCES(./App/runtime/devices TIMELINE_RUNTIME_SOURCES executors)
COLLECT_SOURCES(./App/runtime TIMELINE_RUNTIME_SOURCES models)
COLLECT_SOURCES(./App/runtime TIMELINE_RUNTIME_SOURCES projection)
COLLECT_SOURCES(./App/runtime TIMELINE_RUNTIME_SOURCES timeline)
COLLECT_SOURCES(./App/runtime TIMELINE_RUNTIME_SOURCES video)

add_executable(TimelineControlApp
    ${TIMELINE_APP_SOURCES}
    ${TIMELINE_RUNTIME_SOURCES}
    ${TIMELINE_APP_RESOURCES}
)

target_include_directories(TimelineControlApp PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/App
    ${CMAKE_CURRENT_SOURCE_DIR}/App/runtime
    ${AVRB_INCLUDE_DIR}
)

target_link_libraries(TimelineControlApp PRIVATE
    UiCore
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

find_package(spdlog CONFIG REQUIRED)

target_compile_options(TimelineControlApp PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/utf-8>
)

file(GLOB AVRB_RUNTIME_DLLS "${AVRB_RUNTIME_DIR}/*.dll")
if(AVRB_RUNTIME_DLLS)
    add_custom_command(TARGET TimelineControlApp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${AVRB_RUNTIME_DLLS}
            $<TARGET_FILE_DIR:TimelineControlApp>
    )
endif()

if(EXISTS "D:/Program/third_party/all/bin/glew32.dll")
    add_custom_command(TARGET TimelineControlApp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "D:/Program/third_party/all/bin/glew32.dll"
            $<TARGET_FILE_DIR:TimelineControlApp>
    )
endif()
