cmake_minimum_required(VERSION 3.16)
project(flappy_bird_simulator C)

find_package(SDL2 REQUIRED)
find_program(ZIG zig REQUIRED)

if(NOT DEFINED ENV{LVGL_SOURCE_DIR})
    message(FATAL_ERROR "LVGL_SOURCE_DIR is not set; configure inside `nix develop`")
endif()

set(LV_CONF_PATH "${CMAKE_CURRENT_SOURCE_DIR}/lv_conf.h" CACHE STRING "" FORCE)
set(LV_CONF_INCLUDE_SIMPLE ON CACHE BOOL "" FORCE)
add_subdirectory("$ENV{LVGL_SOURCE_DIR}" "${CMAKE_CURRENT_BINARY_DIR}/lvgl" EXCLUDE_FROM_ALL)

get_target_property(SDL2_INCLUDE_DIRS SDL2::SDL2 INTERFACE_INCLUDE_DIRECTORIES)
list(GET SDL2_INCLUDE_DIRS 0 SDL2_INCLUDE_DIR)

set(ZIG_INSTALL_DIR "${CMAKE_CURRENT_BINARY_DIR}/zig-out")
set(ZIG_OBJECT "${ZIG_INSTALL_DIR}/main_zig.o")

add_custom_command(
    OUTPUT "${ZIG_OBJECT}"
    COMMAND "${ZIG}" build
            --build-file "${CMAKE_CURRENT_SOURCE_DIR}/../build.zig"
            -Dsimulator=true
            -Dsdl-include=${SDL2_INCLUDE_DIR}
            -Dlvgl-include=$ENV{LVGL_SOURCE_DIR}
            --prefix "${ZIG_INSTALL_DIR}"
    DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/../build.zig"
            "${CMAKE_CURRENT_SOURCE_DIR}/../main/main.zig"
            "${CMAKE_CURRENT_SOURCE_DIR}/bindings.c"
            "${CMAKE_CURRENT_SOURCE_DIR}/bindings.h"
            "${CMAKE_CURRENT_SOURCE_DIR}/main.zig"
    COMMENT "Building Zig game for native Linux"
    VERBATIM
)

set_source_files_properties("${ZIG_OBJECT}" PROPERTIES
    EXTERNAL_OBJECT TRUE
    GENERATED TRUE
)

add_executable(flappy-bird-simulator bindings.c "${ZIG_OBJECT}")
set_target_properties(flappy-bird-simulator PROPERTIES LINKER_LANGUAGE C)
target_include_directories(flappy-bird-simulator PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(flappy-bird-simulator PRIVATE lvgl SDL2::SDL2)
