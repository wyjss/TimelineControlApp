qt5_add_resources(UICORE_STANDALONE_RESOURCES
    UICoreStandalone.qrc
)

add_executable(UICoreStandalone
    main.cpp
    ${UICORE_STANDALONE_RESOURCES}
)
set_target_properties(UICoreStandalone PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}"
)
target_link_libraries(UICoreStandalone PRIVATE
    UICore
    Qt5::Widgets
)
uicore_configure_target(UICoreStandalone)
