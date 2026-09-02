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

if(MSVC)
    add_compile_options(/utf-8)

    set(CMAKE_CXX_FLAGS "$ENV{CXXFLAGS} -MP  -ZI /openmp")
    set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "$ENV{CXXFLAGS} -MP  -Od -ZI  /openmp")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(Dependencies)

add_subdirectory(UICore_new)
add_subdirectory(LocatorViewer)
add_subdirectory(App)
