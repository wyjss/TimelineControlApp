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
    include/Blueprint/GraphData.h
    include/Blueprint/GraphDocument.h
    include/Blueprint/GraphRuntime.h
    include/Blueprint/NodeRegistry.h
    src/GraphDocument.cpp
    src/GraphFile.cpp
    src/GraphRuntime.cpp
    src/NodeRegistry.cpp
    docs/data-model.md
    README.md
)
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
    if(NOT TARGET BlueprintQuick)
        message(FATAL_ERROR "Document projection tests require BlueprintQuick")
    endif()
    add_executable(BlueprintDocumentTest tests/document_test.cpp)
    set_target_properties(BlueprintDocumentTest PROPERTIES AUTOMOC ON)
    target_link_libraries(BlueprintDocumentTest PRIVATE BlueprintQuick Qt5::Test)
    add_test(NAME BlueprintDocumentTest COMMAND BlueprintDocumentTest)
    add_executable(BlueprintRuntimeTest tests/runtime_test.cpp)
    target_link_libraries(BlueprintRuntimeTest PRIVATE BlueprintCore)
    add_test(NAME BlueprintRuntimeTest COMMAND BlueprintRuntimeTest)
    add_executable(BlueprintEditorTest tests/editor_test.cpp)
    target_link_libraries(BlueprintEditorTest PRIVATE BlueprintQuick)
    add_test(NAME BlueprintEditorTest COMMAND BlueprintEditorTest)
    set_tests_properties(BlueprintEditorTest PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    add_executable(BlueprintReconnectTest tests/reconnect_test.cpp)
    set_target_properties(BlueprintReconnectTest PROPERTIES AUTOMOC ON)
    target_link_libraries(BlueprintReconnectTest PRIVATE BlueprintQuick Qt5::Test)
    add_test(NAME BlueprintReconnectTest COMMAND BlueprintReconnectTest)
    set_tests_properties(BlueprintReconnectTest PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
    add_executable(BlueprintDemoTest tests/demo_test.cpp demo/DemoGraph.cpp demo/DemoGraph.h)
    set_target_properties(BlueprintDemoTest PROPERTIES AUTOMOC ON)
    target_include_directories(BlueprintDemoTest PRIVATE demo)
    target_link_libraries(BlueprintDemoTest PRIVATE BlueprintQuick Qt5::Test)
    add_test(NAME BlueprintDemoTest COMMAND BlueprintDemoTest)
    add_executable(BlueprintCompareTest tests/compare_test.cpp demo/DemoGraph.cpp demo/DemoGraph.h)
    set_target_properties(BlueprintCompareTest PROPERTIES AUTOMOC ON)
    target_include_directories(BlueprintCompareTest PRIVATE demo)
    target_link_libraries(BlueprintCompareTest PRIVATE BlueprintQuick Qt5::Test)
    add_test(NAME BlueprintCompareTest COMMAND BlueprintCompareTest)
    add_executable(BlueprintInteractionTest tests/interaction_test.cpp)
    set_target_properties(BlueprintInteractionTest PROPERTIES AUTOMOC ON)
    target_link_libraries(BlueprintInteractionTest PRIVATE BlueprintQuick Qt5::Test)
    add_test(NAME BlueprintInteractionTest COMMAND BlueprintInteractionTest)
    set_tests_properties(BlueprintInteractionTest PROPERTIES
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
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
