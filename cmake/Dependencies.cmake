set(AVRB_ROOT "${CMAKE_SOURCE_DIR}/libavrb")
set(AVRB_INCLUDE_DIR "${AVRB_ROOT}/include/avrb")
set(AVRB_LIBRARY "${AVRB_ROOT}/lib/avrb.lib")
set(AVRB_RUNTIME_DIR "${AVRB_ROOT}/dll")

find_package(Qt5 5.14 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
    Network
    Widgets
    SerialPort
    OpenGL
    Xml
)
find_package(spdlog CONFIG REQUIRED)
