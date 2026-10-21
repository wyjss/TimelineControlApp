add_executable(UICoreCppTests
    cpp/main.cpp
    cpp/tst_FieldContracts.cpp
    cpp/tst_TaskContracts.cpp
)
target_link_libraries(UICoreCppTests PRIVATE
    UICore
    Qt5::Test
)
uicore_configure_target(UICoreCppTests)

add_test(NAME UICoreFieldTests COMMAND UICoreCppTests)
add_test(NAME UICoreTaskTests COMMAND UICoreCppTests)

add_executable(UICoreQmlTests
    qml/main.cpp
)
target_compile_definitions(UICoreQmlTests PRIVATE
    QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml"
)
target_link_libraries(UICoreQmlTests PRIVATE
    UICore
    Qt5::QuickTest
    Qt5::QuickControls2
)
uicore_configure_target(UICoreQmlTests)

add_test(NAME UICoreQmlTests COMMAND UICoreQmlTests)
add_test(NAME UICoreTreeSelectionTests COMMAND UICoreQmlTests
    -input "${CMAKE_CURRENT_SOURCE_DIR}/tree"
)

qt5_add_resources(UICORE_MEMORY_VERIFICATION_RESOURCES
    memory/UICoreMemoryVerification.qrc
)
add_executable(UICoreMemoryVerification
    memory/main.cpp
    ${UICORE_MEMORY_VERIFICATION_RESOURCES}
)
target_link_libraries(UICoreMemoryVerification PRIVATE
    UICore
    Qt5::QuickControls2
)
uicore_configure_target(UICoreMemoryVerification)

set(UICORE_TEST_ENVIRONMENT
    "QT_QPA_PLATFORM=offscreen"
    "QT_QUICK_BACKEND=software"
    "QT_QUICK_CONTROLS_STYLE=Default"
    "QML_DISABLE_DISK_CACHE=1"
)
if(WIN32)
    string(REPLACE ";" "\\;" UICORE_TEST_PATH "$ENV{PATH}")
    list(APPEND UICORE_TEST_ENVIRONMENT
        "PATH=$<TARGET_FILE_DIR:Qt5::Core>\\;${UICORE_TEST_PATH}"
    )
endif()
set_tests_properties(UICoreQmlTests UICoreTreeSelectionTests PROPERTIES
    ENVIRONMENT "${UICORE_TEST_ENVIRONMENT}"
)
set_tests_properties(UICoreFieldTests PROPERTIES
    ENVIRONMENT "${UICORE_TEST_ENVIRONMENT};UICORE_TEST_SUITE=field"
)
set_tests_properties(UICoreTaskTests PROPERTIES
    ENVIRONMENT "${UICORE_TEST_ENVIRONMENT};UICORE_TEST_SUITE=task"
)
