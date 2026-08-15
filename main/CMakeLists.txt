find_program(ZIG zig REQUIRED)

set(ZIG_BUILD_FILE "${PROJECT_DIR}/build.zig")
set(ZIG_INSTALL_DIR "${CMAKE_CURRENT_BINARY_DIR}/zig-out")
set(ZIG_OBJECT "${ZIG_INSTALL_DIR}/main_zig.o")

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    add_custom_command(
        OUTPUT "${ZIG_OBJECT}"
        COMMAND "${ZIG}" build
                --build-file "${ZIG_BUILD_FILE}"
                --prefix "${ZIG_INSTALL_DIR}"
        DEPENDS "${ZIG_BUILD_FILE}" "${CMAKE_CURRENT_SOURCE_DIR}/main.zig"
        COMMENT "Building Zig application for ESP32-S3"
        VERBATIM
    )

    set_source_files_properties("${ZIG_OBJECT}" PROPERTIES
        EXTERNAL_OBJECT TRUE
        GENERATED TRUE
    )
endif()

idf_component_register(
    SRCS "platform.c" "${ZIG_OBJECT}"
    INCLUDE_DIRS "."
    REQUIRES esp_driver_gpio esp_driver_i2c esp_driver_spi esp_lcd esp_timer lvgl
)
