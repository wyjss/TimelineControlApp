target_sources(TimelineControlApp PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/WebControlServer.cpp
    ${CMAKE_CURRENT_LIST_DIR}/WebControlServer.h
    ${CMAKE_CURRENT_LIST_DIR}/index.html
    ${CMAKE_CURRENT_LIST_DIR}/assets/app.css
    ${CMAKE_CURRENT_LIST_DIR}/assets/app.js
)

add_custom_target(TimelineWebControlAssets
    COMMAND ${CMAKE_COMMAND} -E make_directory
        ${CMAKE_BINARY_DIR}/$<CONFIG>/web/assets
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_LIST_DIR}/index.html
        ${CMAKE_BINARY_DIR}/$<CONFIG>/web/index.html
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_LIST_DIR}/assets
        ${CMAKE_BINARY_DIR}/$<CONFIG>/web/assets
    VERBATIM
)

add_dependencies(TimelineControlApp TimelineWebControlAssets)
