cmake_minimum_required(VERSION 3.16)

project(BlueprintFramework VERSION 0.1.0 LANGUAGES CXX)

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
set_target_properties(BlueprintFramework PROPERTIES AUTOMOC ON OUTPUT_NAME BlueprintCore)
target_compile_features(BlueprintFramework PUBLIC cxx_std_17)
target_compile_options(BlueprintFramework PUBLIC $<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/utf-8>)
target_include_directories(BlueprintFramework PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(BlueprintFramework PUBLIC Qt5::Core)

if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    add_executable(BlueprintExample examples/core_example.cpp)
    target_link_libraries(BlueprintExample PRIVATE BlueprintCore)
    add_subdirectory(quick)
    add_subdirectory(demo)
endif()
