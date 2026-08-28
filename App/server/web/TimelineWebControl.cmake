target_sources(TimelineControlApp PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/WebControlServer.cpp
    ${CMAKE_CURRENT_LIST_DIR}/WebControlServer.h
    ${CMAKE_CURRENT_LIST_DIR}/index.html
    ${CMAKE_CURRENT_LIST_DIR}/assets/app.css
    ${CMAKE_CURRENT_LIST_DIR}/assets/app.js
)

add_custom_command(TARGET TimelineControlApp POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        $<TARGET_FILE_DIR:TimelineControlApp>/web/assets
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_LIST_DIR}/index.html
        $<TARGET_FILE_DIR:TimelineControlApp>/web/index.html
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_LIST_DIR}/assets
        $<TARGET_FILE_DIR:TimelineControlApp>/web/assets
    VERBATIM
)
