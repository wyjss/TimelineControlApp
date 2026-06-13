cmake_minimum_required(VERSION 3.16)

set(UICORE_COLLECT_SOURCES_CMAKE "")
foreach(candidate
        "${CMAKE_CURRENT_LIST_DIR}/../cmake/CollectSources.cmake"
        "${CMAKE_CURRENT_LIST_DIR}/../../cmake/CollectSources.cmake"
        "${CMAKE_SOURCE_DIR}/cmake/CollectSources.cmake")
    if(EXISTS "${candidate}")
        set(UICORE_COLLECT_SOURCES_CMAKE "${candidate}")
        break()
    endif()
endforeach()

if(UICORE_COLLECT_SOURCES_CMAKE STREQUAL "")
    message(FATAL_ERROR "CollectSources.cmake not found for UiCore.")
endif()

include("${UICORE_COLLECT_SOURCES_CMAKE}")

project(UiCore
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

set(UICORE_RUNTIME_SOURCES "")
COLLECT_SOURCES(./runtime UICORE_RUNTIME_SOURCES app)
COLLECT_SOURCES(./runtime UICORE_RUNTIME_SOURCES form)
COLLECT_SOURCES(./runtime UICORE_RUNTIME_SOURCES menus)
COLLECT_SOURCES(./runtime UICORE_RUNTIME_SOURCES shell)
COLLECT_SOURCES(./runtime UICORE_RUNTIME_SOURCES task)

set(UICORE_COMMON_LIBRARIES
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    Qt5::QuickControls2
    Qt5::Widgets
)

add_library(UiCore OBJECT)
set_target_properties(UiCore PROPERTIES FOLDER "app")

qt5_add_resources(UICORE_RESOURCE_SOURCES
    UiCore.qrc
)

target_sources(UiCore PRIVATE
    ${UICORE_RUNTIME_SOURCES}
    ${UICORE_RESOURCE_SOURCES}
)

target_include_directories(UiCore PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}
    ${CMAKE_CURRENT_LIST_DIR}/runtime
    ${CMAKE_CURRENT_LIST_DIR}/runtime/app
)

target_link_libraries(UiCore PUBLIC
    ${UICORE_COMMON_LIBRARIES}
)

target_compile_options(UiCore PRIVATE
    $<$<CXX_COMPILER_ID:MSVC>:/utf-8>
)

set(UICORE_BUILD_STANDALONE_DEFAULT OFF)
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(UICORE_BUILD_STANDALONE_DEFAULT ON)
endif()

option(UICORE_BUILD_STANDALONE
    "Build the standalone UiCore shell executable."
    ${UICORE_BUILD_STANDALONE_DEFAULT}
)

if(UICORE_BUILD_STANDALONE)
    add_executable(UiCoreStandalone
        standalone/main.cpp
    )
    set_target_properties(UiCoreStandalone PROPERTIES
        FOLDER "app"
        OUTPUT_NAME "UiCoreStandalone"
    )
    target_link_libraries(UiCoreStandalone PRIVATE
        UiCore
        ${UICORE_COMMON_LIBRARIES}
    )
    target_compile_options(UiCoreStandalone PRIVATE
        $<$<CXX_COMPILER_ID:MSVC>:/utf-8>
    )
endif()
