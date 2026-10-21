cmake_minimum_required(VERSION 3.16)

project(UICore
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
    QuickCompiler
    QuickControls2
    Widgets
)

function(uicore_configure_target target)
    target_compile_features(${target} PUBLIC cxx_std_17)
    target_compile_options(${target} PRIVATE
        $<$<CXX_COMPILER_ID:MSVC>:/utf-8>
    )
endfunction()

qt5_add_resources(UICORE_RESOURCES resources/UICore.qrc)
add_library(UICore STATIC
    src/UICore.cpp
    include/UICore/UICore.h
    src/fields/AppField.cpp
    src/fields/BaseField.cpp
    include/UICore/Fields/AppField.h
    include/UICore/Fields/BaseField.h
    include/UICore/Style/UiStyleEnums.h
    src/style/AppIconPaintedItem.cpp
    src/style/AppIconPaintedItem.h
    src/forms/AppForm.cpp
    src/forms/AppFormSection.cpp
    src/forms/AppMenuCustomBlock.cpp
    src/forms/AppMenuModel.cpp
    include/UICore/Forms/UiFormEnums.h
    include/UICore/Forms/AppForm.h
    include/UICore/Forms/AppFormSection.h
    include/UICore/Forms/AppMenuCustomBlock.h
    include/UICore/Forms/AppMenuModel.h
    src/shell/AppSettings.cpp
    src/shell/AppShellController.cpp
    src/shell/AppShellRouteState.cpp
    src/shell/BaseRuntime.cpp
    include/UICore/Shell/AppSettings.h
    include/UICore/Shell/AppShellController.h
    include/UICore/Shell/AppShellRouteState.h
    include/UICore/Shell/BaseRuntime.h
    src/task/Task.cpp
    src/task/TaskManager.cpp
    include/UICore/Task/Task.h
    include/UICore/Task/TaskManager.h
    ${UICORE_RESOURCES}
)
target_include_directories(UICore PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
)
target_link_libraries(UICore PUBLIC
    Qt5::Core
    Qt5::Gui
    Qt5::Qml
    Qt5::Quick
    Qt5::QuickControls2

)
uicore_configure_target(UICore)

set(UICORE_BUILD_STANDALONE_DEFAULT OFF)
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(UICORE_BUILD_STANDALONE_DEFAULT ON)
endif()

option(UICORE_BUILD_STANDALONE
    "Build the standalone UICore shell executable."
    ${UICORE_BUILD_STANDALONE_DEFAULT}
)

set(UICORE_BUILD_TESTS_DEFAULT OFF)
if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(UICORE_BUILD_TESTS_DEFAULT ON)
endif()

option(UICORE_BUILD_TESTS
    "Build the UICore contract tests."
    ${UICORE_BUILD_TESTS_DEFAULT}
)

if(UICORE_BUILD_STANDALONE)
    add_subdirectory(examples/standalone)
endif()

if(UICORE_BUILD_TESTS)
    enable_testing()
    find_package(Qt5 5.14 REQUIRED COMPONENTS Test QuickTest)
    add_subdirectory(verification)
endif()
