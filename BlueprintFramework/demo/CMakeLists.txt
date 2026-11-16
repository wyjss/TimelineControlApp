find_package(Qt5 5.14 REQUIRED COMPONENTS Quick Widgets)

if(NOT TARGET UICore)
    add_subdirectory(../../UICore_new ${CMAKE_CURRENT_BINARY_DIR}/UICore EXCLUDE_FROM_ALL)
endif()

qt5_add_resources(blueprint_demo_resources demo.qrc)

add_executable(BlueprintFramework-demo WIN32
    main.cpp
    DemoGraph.cpp
    DemoGraph.h
    demo.qrc
    ${blueprint_demo_resources}
    qml/Main.qml
)
set_target_properties(BlueprintFramework-demo PROPERTIES
    AUTOMOC ON
    VS_DEBUGGER_ENVIRONMENT "PATH=$<TARGET_FILE_DIR:Qt5::Core>;%PATH%"
)
target_link_libraries(BlueprintFramework-demo PRIVATE BlueprintQuick UICore Qt5::Widgets)
