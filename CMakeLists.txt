cmake_minimum_required(VERSION 3.16)

project(TimelineControlApp
    VERSION 0.1.0
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt5 5.14 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Widgets
)

add_subdirectory(UiCore)

qt5_add_resources(TIMELINE_APP_RESOURCES
    App/App.qrc
)

add_executable(TimelineControlApp
    App/main.cpp
    App/runtime/devices/DeviceParamSpec.cpp
    App/runtime/devices/DeviceParamSpec.h
    App/runtime/devices/DeviceCommandTemplate.cpp
    App/runtime/devices/DeviceCommandTemplate.h
    App/runtime/devices/Device.cpp
    App/runtime/devices/Device.h
    App/runtime/devices/DeviceManager.cpp
    App/runtime/devices/DeviceManager.h
    App/runtime/devices/DeviceTemplate.cpp
    App/runtime/devices/DeviceTemplate.h
    App/runtime/TimelineRuntime.cpp
    App/runtime/TimelineRuntime.h
    App/runtime/TimelineShellController.cpp
    App/runtime/TimelineShellController.h
    ${TIMELINE_APP_RESOURCES}
)

target_include_directories(TimelineControlApp PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/App
    ${CMAKE_CURRENT_SOURCE_DIR}/App/runtime
)

target_link_libraries(TimelineControlApp PRIVATE
    UiCore
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    Qt5::QuickControls2
    Qt5::Widgets
)

target_compile_options(TimelineControlApp PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/utf-8>
)
