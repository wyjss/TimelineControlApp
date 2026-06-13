cmake_minimum_required(VERSION 3.10)

include(FindPackageHandleStandardArgs)

set(_FFMPEG_HINTS
    ${FFMPEG_ROOT}
    $ENV{FFMPEG_ROOT}
)

find_path(FFMPEG_INCLUDE_DIR
    NAMES libavcodec/avcodec.h
    HINTS ${_FFMPEG_HINTS}
    PATH_SUFFIXES include
)

function(_ffmpeg_find_library out_var name)
    find_library(${out_var}
        NAMES ${name} lib${name}
        HINTS ${_FFMPEG_HINTS}
        PATH_SUFFIXES lib
    )
endfunction()

_ffmpeg_find_library(FFMPEG_AVCODEC_LIBRARY    avcodec)
_ffmpeg_find_library(FFMPEG_AVDEVICE_LIBRARY   avdevice)
_ffmpeg_find_library(FFMPEG_AVFILTER_LIBRARY   avfilter)
_ffmpeg_find_library(FFMPEG_AVFORMAT_LIBRARY   avformat)
_ffmpeg_find_library(FFMPEG_AVUTIL_LIBRARY     avutil)
_ffmpeg_find_library(FFMPEG_SWRESAMPLE_LIBRARY swresample)
_ffmpeg_find_library(FFMPEG_SWSCALE_LIBRARY    swscale)

find_package_handle_standard_args(FFmpeg
    REQUIRED_VARS
        FFMPEG_INCLUDE_DIR
        FFMPEG_AVCODEC_LIBRARY
        FFMPEG_AVDEVICE_LIBRARY
        FFMPEG_AVFILTER_LIBRARY
        FFMPEG_AVFORMAT_LIBRARY
        FFMPEG_AVUTIL_LIBRARY
        FFMPEG_SWRESAMPLE_LIBRARY
        FFMPEG_SWSCALE_LIBRARY
)

if(FFmpeg_FOUND)
    set(FFMPEG_INCLUDE_DIRS ${FFMPEG_INCLUDE_DIR})
    set(FFMPEG_LIBRARIES
        ${FFMPEG_AVCODEC_LIBRARY}
        ${FFMPEG_AVDEVICE_LIBRARY}
        ${FFMPEG_AVFILTER_LIBRARY}
        ${FFMPEG_AVFORMAT_LIBRARY}
        ${FFMPEG_AVUTIL_LIBRARY}
        ${FFMPEG_SWRESAMPLE_LIBRARY}
        ${FFMPEG_SWSCALE_LIBRARY}
    )

    if(NOT TARGET FFmpeg::avutil)
        add_library(FFmpeg::avutil UNKNOWN IMPORTED)
        set_target_properties(FFmpeg::avutil PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_AVUTIL_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
        )
    endif()

    if(NOT TARGET FFmpeg::swresample)
        add_library(FFmpeg::swresample UNKNOWN IMPORTED)
        set_target_properties(FFmpeg::swresample PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_SWRESAMPLE_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
            INTERFACE_LINK_LIBRARIES "FFmpeg::avutil"
        )
    endif()

    if(NOT TARGET FFmpeg::swscale)
        add_library(FFmpeg::swscale UNKNOWN IMPORTED)
        set_target_properties(FFmpeg::swscale PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_SWSCALE_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
            INTERFACE_LINK_LIBRARIES "FFmpeg::avutil"
        )
    endif()

    if(NOT TARGET FFmpeg::avcodec)
        add_library(FFmpeg::avcodec UNKNOWN IMPORTED)
        set_target_properties(FFmpeg::avcodec PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_AVCODEC_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
            INTERFACE_LINK_LIBRARIES "FFmpeg::avutil"
        )
    endif()

    if(NOT TARGET FFmpeg::avformat)
        add_library(FFmpeg::avformat UNKNOWN IMPORTED)
        set_target_properties(FFmpeg::avformat PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_AVFORMAT_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
            INTERFACE_LINK_LIBRARIES "FFmpeg::avcodec;FFmpeg::avutil"
        )
    endif()

    if(NOT TARGET FFmpeg::avfilter)
        add_library(FFmpeg::avfilter UNKNOWN IMPORTED)
        set_target_properties(FFmpeg::avfilter PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_AVFILTER_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
            INTERFACE_LINK_LIBRARIES "FFmpeg::avcodec;FFmpeg::avformat;FFmpeg::avutil;FFmpeg::swresample;FFmpeg::swscale"
        )
    endif()

    if(NOT TARGET FFmpeg::avdevice)
        add_library(FFmpeg::avdevice UNKNOWN IMPORTED)
        set_target_properties(FFmpeg::avdevice PROPERTIES
            IMPORTED_LOCATION "${FFMPEG_AVDEVICE_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${FFMPEG_INCLUDE_DIR}"
            INTERFACE_LINK_LIBRARIES "FFmpeg::avfilter;FFmpeg::avformat;FFmpeg::avcodec;FFmpeg::avutil"
        )
    endif()
endif()

mark_as_advanced(
    FFMPEG_INCLUDE_DIR
    FFMPEG_AVCODEC_LIBRARY
    FFMPEG_AVDEVICE_LIBRARY
    FFMPEG_AVFILTER_LIBRARY
    FFMPEG_AVFORMAT_LIBRARY
    FFMPEG_AVUTIL_LIBRARY
    FFMPEG_SWRESAMPLE_LIBRARY
    FFMPEG_SWSCALE_LIBRARY
)