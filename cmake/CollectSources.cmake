# find sources from current cmakelists dir
# @param inDir dir
# @param outVar
# @param name dir name
function(COLLECT_SOURCES inDir outVar name)
    file(GLOB temp_sources ${inDir}/${name}/*)
    list(FILTER temp_sources EXCLUDE REGEX ".*[ -_]副本.*")  # 过滤不需要的文件
    source_group(${name} FILES ${temp_sources})
    set(${outVar} ${${outVar}} ${temp_sources} PARENT_SCOPE)  # 正确传递到外部变量
endfunction()

function(COLLECT_SOURCES_TYPE inDir outVar name type)
    file(GLOB temp_sources ${inDir}/${name}/${type})
    list(FILTER temp_sources EXCLUDE REGEX ".*[ -_]副本.*")  # 过滤不需要的文件
    source_group(${name} FILES ${temp_sources})
    set(${outVar} ${${outVar}} ${temp_sources} PARENT_SCOPE)  # 正确传递到外部变量
endfunction()
