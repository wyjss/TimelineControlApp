cmake_minimum_required(VERSION 3.16)

project(BlueprintFramework VERSION 0.1.0 LANGUAGES CXX)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

option(BLUEPRINT_BUILD_QUICK "Build the Qt Quick editor" ON)
option(BLUEPRINT_BUILD_DEMO "Build the example host (requires UICore)" OFF)
option(BLUEPRINT_BUILD_EXAMPLE "Build the core command-line example" ON)
option(BLUEPRINT_BUILD_TESTS "Build framework contract tests" OFF)

find_package(Qt5 5.14 REQUIRED COMPONENTS Core)

add_library(BlueprintFramework STATIC
    include/Blueprint/BasicNodes.h
    include/Blueprint/GraphData.h
    include/Blueprint/GraphDocument.h
    include/Blueprint/GraphRuntime.h
    include/Blueprint/NodeRegistry.h
    include/Blueprint/ObjectNodes.h
    include/Blueprint/WaitNodes.h
    src/GraphDocument.cpp
    src/GraphFile.cpp
    src/GraphRuntime.cpp
    src/NodeRegistry.cpp
    src/nodes/BasicNodes.cpp
    src/nodes/BranchNode.cpp
    src/nodes/BranchNode.h
    src/nodes/CompareNode.cpp
    src/nodes/CompareNode.h
    src/nodes/ObjectNodes.cpp
    src/nodes/WaitNodes.cpp
    docs/data-model.md
    README.md
)
source_group(nodes REGULAR_EXPRESSION "/src/nodes/")
add_library(BlueprintCore ALIAS BlueprintFramework)
add_library(Blueprint::Core ALIAS BlueprintFramework)
set_target_properties(BlueprintFramework PROPERTIES AUTOMOC ON EXPORT_NAME Core)
target_compile_features(BlueprintFramework PUBLIC cxx_std_17)
target_compile_options(BlueprintFramework PUBLIC $<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/utf-8>)
target_include_directories(BlueprintFramework PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(BlueprintFramework PUBLIC Qt5::Core)

if(BLUEPRINT_BUILD_EXAMPLE AND CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    add_executable(BlueprintExample examples/core_example.cpp)
    target_link_libraries(BlueprintExample PRIVATE BlueprintCore)

    add_executable(BlueprintAsyncExample examples/async_nodes_example.cpp)
    target_link_libraries(BlueprintAsyncExample PRIVATE BlueprintCore)
endif()
if(BLUEPRINT_BUILD_QUICK)
    add_subdirectory(quick)
endif()
if(BLUEPRINT_BUILD_DEMO)
    if(NOT BLUEPRINT_BUILD_QUICK)
        message(FATAL_ERROR "BLUEPRINT_BUILD_DEMO requires BLUEPRINT_BUILD_QUICK")
    endif()
    add_subdirectory(demo)
endif()

if(BLUEPRINT_BUILD_TESTS)
    enable_testing()
    find_package(Qt5 5.14 REQUIRED COMPONENTS Test)

    if(TARGET BlueprintExample)
        add_test(NAME BlueprintExample COMMAND BlueprintExample)
        add_test(NAME BlueprintAsyncExample COMMAND BlueprintAsyncExample)
    endif()

    add_executable(BlueprintRuntimeTest verification/runtime_test.cpp)
    set_target_properties(BlueprintRuntimeTest PROPERTIES AUTOMOC ON)
    target_link_libraries(BlueprintRuntimeTest PRIVATE BlueprintCore Qt5::Test)
    add_test(NAME BlueprintRuntimeTest COMMAND BlueprintRuntimeTest)

    if(TARGET BlueprintQuick)
        add_executable(BlueprintHistoryTest verification/history_test.cpp demo/DemoGraph.cpp demo/DemoGraph.h)
        set_target_properties(BlueprintHistoryTest PROPERTIES AUTOMOC ON)
        target_include_directories(BlueprintHistoryTest PRIVATE demo)
        target_link_libraries(BlueprintHistoryTest PRIVATE BlueprintQuick Qt5::Test)
        add_test(NAME BlueprintHistoryTest COMMAND BlueprintHistoryTest)

        add_executable(BlueprintEditorTest verification/editor_test.cpp)
        set_target_properties(BlueprintEditorTest PROPERTIES AUTOMOC ON)
        target_link_libraries(BlueprintEditorTest PRIVATE BlueprintQuick Qt5::Test)
        add_test(NAME BlueprintEditorTest COMMAND BlueprintEditorTest)
        set_tests_properties(BlueprintEditorTest PROPERTIES
            ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
    endif()

    if(BLUEPRINT_BUILD_DEMO)
        find_package(Qt5 5.14 REQUIRED COMPONENTS Widgets)
        qt5_add_resources(blueprint_demo_test_resources demo/demo.qrc)
        add_executable(BlueprintDemoUiTest verification/demo_ui_test.cpp
            demo/DemoGraph.cpp demo/DemoGraph.h demo/demo.qrc ${blueprint_demo_test_resources})
        set_target_properties(BlueprintDemoUiTest PROPERTIES AUTOMOC ON)
        target_include_directories(BlueprintDemoUiTest PRIVATE demo)
        target_link_libraries(BlueprintDemoUiTest PRIVATE BlueprintQuick UICore Qt5::Widgets Qt5::Test)
        add_test(NAME BlueprintDemoUiTest COMMAND BlueprintDemoUiTest)
        set_tests_properties(BlueprintDemoUiTest PROPERTIES
            ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
    endif()
endif()

install(TARGETS BlueprintFramework EXPORT BlueprintTargets ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(DIRECTORY include/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})
install(EXPORT BlueprintTargets FILE BlueprintTargets.cmake NAMESPACE Blueprint::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/BlueprintFramework)
configure_package_config_file(cmake/BlueprintFrameworkConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/BlueprintFrameworkConfig.cmake
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/BlueprintFramework)
write_basic_package_version_file(${CMAKE_CURRENT_BINARY_DIR}/BlueprintFrameworkConfigVersion.cmake
    VERSION ${PROJECT_VERSION} COMPATIBILITY ExactVersion)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/BlueprintFrameworkConfig.cmake
    ${CMAKE_CURRENT_BINARY_DIR}/BlueprintFrameworkConfigVersion.cmake
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/BlueprintFramework)
