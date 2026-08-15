find_program(ZIG zig REQUIRED)

set(ZIG_SOURCE "${CMAKE_CURRENT_SOURCE_DIR}/hello.zig")
set(ZIG_OBJECT "${CMAKE_CURRENT_BINARY_DIR}/hello_zig.o")

if(NOT CMAKE_BUILD_EARLY_EXPANSION)
    add_custom_command(
        OUTPUT "${ZIG_OBJECT}"
        COMMAND "${ZIG}" build-obj "${ZIG_SOURCE}"
                -target xtensa-freestanding-none
                -mcpu=esp32s3
                "-femit-bin=${ZIG_OBJECT}"
        DEPENDS "${ZIG_SOURCE}"
        COMMENT "Building Zig code for ESP32-S3"
        VERBATIM
    )

    set_source_files_properties("${ZIG_OBJECT}" PROPERTIES
        EXTERNAL_OBJECT TRUE
        GENERATED TRUE
    )
endif()

idf_component_register(
    SRCS "main.c" "${ZIG_OBJECT}"
    INCLUDE_DIRS "."
)
