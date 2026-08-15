const std = @import("std");

pub fn build(b: *std.Build) void {
    const simulator = b.option(bool, "simulator", "Build for the native Linux simulator") orelse false;
    const target = if (simulator)
        b.standardTargetOptions(.{})
    else
        b.resolveTargetQuery(.{
            .cpu_arch = .xtensa,
            .os_tag = .freestanding,
            .abi = .none,
            .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.esp32s3 },
        });
    const optimize = b.standardOptimizeOption(.{});

    const root_source_file = if (simulator)
        b.path("simulator/main.zig")
    else
        b.path("main/main.zig");
    const root_module = b.createModule(.{
        .root_source_file = root_source_file,
        .target = target,
        .optimize = optimize,
        .pic = simulator,
    });

    if (simulator) {
        const sdl_include = b.option([]const u8, "sdl-include", "SDL2 header directory") orelse
            @panic("-Dsdl-include is required for the simulator");
        const lvgl_include = b.option([]const u8, "lvgl-include", "LVGL source directory") orelse
            @panic("-Dlvgl-include is required for the simulator");
        const c_bindings = b.addTranslateC(.{
            .root_source_file = b.path("simulator/bindings.h"),
            .target = target,
            .optimize = optimize,
        });
        c_bindings.addSystemIncludePath(b.graph.cwdRelativePath(sdl_include));
        c_bindings.addSystemIncludePath(b.graph.cwdRelativePath(lvgl_include));
        c_bindings.addSystemIncludePath(b.path("simulator"));
        c_bindings.defineCMacro("LV_CONF_INCLUDE_SIMPLE", null);
        c_bindings.defineCMacro("LV_LVGL_H_INCLUDE_SIMPLE", null);
        c_bindings.defineCMacro("SDL_DISABLE_IMMINTRIN_H", null);
        root_module.addImport("c", c_bindings.createModule());
        root_module.addImport("game", b.createModule(.{
            .root_source_file = b.path("main/main.zig"),
            .target = target,
            .optimize = optimize,
            .pic = true,
        }));
    }

    const application = b.addObject(.{
        .name = "main_zig",
        .root_module = root_module,
    });

    const install_application = b.addInstallArtifact(application, .{
        .dest_dir = .{ .override = .prefix },
        .dest_sub_path = "main_zig.o",
    });
    b.getInstallStep().dependOn(&install_application.step);
}
