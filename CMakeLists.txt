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

set(AVRB_ROOT "D:/Program/RA/avrb" CACHE PATH "AVRB root directory")
set(AVRB_RUNTIME_DIR "${AVRB_ROOT}/x64/Release" CACHE PATH "AVRB runtime directory")
set(AVRB_FFMPEG_RUNTIME_DIR "D:/Program/third_party/ffmpeg/bin" CACHE PATH "AVRB FFmpeg runtime dependency directory")

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
    App/runtime/devices/DeviceCommand.cpp
    App/runtime/devices/DeviceCommand.h
    App/runtime/devices/DeviceCommand_Dmx512.cpp
    App/runtime/devices/DeviceCommand_Dmx512.h
    App/runtime/devices/DeviceCommand_Http.cpp
    App/runtime/devices/DeviceCommand_Http.h
    App/runtime/devices/DeviceCommand_PC.cpp
    App/runtime/devices/DeviceCommand_PC.h
    App/runtime/devices/DeviceCommand_Serial.cpp
    App/runtime/devices/DeviceCommand_Serial.h
    App/runtime/devices/DeviceConstants.h
    App/runtime/devices/DeviceInspectorFormProvider.cpp
    App/runtime/devices/DeviceInspectorFormProvider.h
    App/runtime/devices/DeviceParamSpec.cpp
    App/runtime/devices/DeviceParamSpec.h
    App/runtime/devices/Device.cpp
    App/runtime/devices/Device.h
    App/runtime/devices/DeviceManager.cpp
    App/runtime/devices/DeviceManager.h
    App/runtime/devices/DeviceModel.cpp
    App/runtime/devices/DeviceModel.h
    App/runtime/devices/DeviceTemplate.cpp
    App/runtime/devices/DeviceTemplate.h
    App/runtime/devices/DeviceTemplateModel.cpp
    App/runtime/devices/DeviceTemplateModel.h
    App/runtime/models/TypedListModel.h
    App/runtime/models/VariantListModel.cpp
    App/runtime/models/VariantListModel.h
    App/runtime/projection/ProjectionInstructionManager.cpp
    App/runtime/projection/ProjectionInstructionManager.h
    App/runtime/timeline/TimelineCommand.cpp
    App/runtime/timeline/TimelineCommand.h
    App/runtime/timeline/TimelineManager.cpp
    App/runtime/timeline/TimelineManager.h
    App/runtime/TimelineRuntime.cpp
    App/runtime/TimelineRuntime.h
    App/runtime/TimelineShellController.cpp
    App/runtime/TimelineShellController.h
    App/runtime/video/FfmpegVideoFrameItem.cpp
    App/runtime/video/FfmpegVideoFrameItem.h
    ${TIMELINE_APP_RESOURCES}
)

target_include_directories(TimelineControlApp PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/App
    ${CMAKE_CURRENT_SOURCE_DIR}/App/runtime
    ${AVRB_ROOT}/avrb
)

target_link_libraries(TimelineControlApp PRIVATE
    UiCore
    ${AVRB_RUNTIME_DIR}/avrb.lib
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

file(GLOB AVRB_FFMPEG_RUNTIME_DLLS "${AVRB_FFMPEG_RUNTIME_DIR}/*.dll")
if(AVRB_FFMPEG_RUNTIME_DLLS)
    add_custom_command(TARGET TimelineControlApp POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${AVRB_FFMPEG_RUNTIME_DLLS}
            $<TARGET_FILE_DIR:TimelineControlApp>
    )
endif()

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
