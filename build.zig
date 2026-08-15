const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const simulator = b.option(bool, "simulator", "Build the native simulator") orelse false;
    const optimize = b.standardOptimizeOption(.{});

    const game_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("main/main.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
        .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
    });
    const run_game_tests = b.addRunArtifact(game_tests);
    const simulator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("simulator/input.zig"),
            .target = b.graph.host,
            .optimize = optimize,
        }),
        .test_runner = .{ .path = b.path("test_runner.zig"), .mode = .simple },
    });
    const run_simulator_tests = b.addRunArtifact(simulator_tests);
    run_simulator_tests.step.dependOn(&run_game_tests.step);
    const test_step = b.step("test", "Run the Zig tests");
    test_step.dependOn(&run_simulator_tests.step);

    if (simulator) {
        buildSimulator(b, optimize);
    } else {
        buildFirmware(b, optimize);
    }
}

fn buildFirmware(b: *std.Build, optimize: std.builtin.OptimizeMode) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .xtensa,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.esp32s3 },
    });
    const application = b.addObject(.{
        .name = "main_zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install_application = b.addInstallArtifact(application, .{
        .dest_dir = .{ .override = .prefix },
        .dest_sub_path = "main_zig.o",
    });
    b.getInstallStep().dependOn(&install_application.step);
}

fn buildSimulator(b: *std.Build, optimize: std.builtin.OptimizeMode) void {
    const target = b.standardTargetOptions(.{});
    const lvgl_source_dir = b.graph.environ_map.get("LVGL_SOURCE_DIR") orelse
        @panic("LVGL_SOURCE_DIR is not set; run inside `nix develop`");
    const sdl_include_dir = b.graph.environ_map.get("SDL3_INCLUDE_DIR") orelse
        @panic("SDL3_INCLUDE_DIR is not set; run inside `nix develop`");
    const sdl_library_dir = b.graph.environ_map.get("SDL3_LIBRARY_DIR") orelse
        @panic("SDL3_LIBRARY_DIR is not set; run inside `nix develop`");
    const root_module = b.createModule(.{
        .root_source_file = b.path("simulator/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // Linux's final native link is performed by the Nix C compiler so SDL
        // and libc come from one coherent runtime. Do not emit Zig C
        // sanitizer calls, whose runtime would otherwise need to be linked.
        .sanitize_c = .off,
    });

    const c_bindings = b.addTranslateC(.{
        .root_source_file = b.path("simulator/bindings.h"),
        .target = target,
        .optimize = optimize,
    });
    c_bindings.addSystemIncludePath(b.graph.cwdRelativePath(sdl_include_dir));
    root_module.addImport("c", c_bindings.createModule());
    root_module.addImport("game", b.createModule(.{
        .root_source_file = b.path("main/main.zig"),
        .target = target,
        .optimize = optimize,
    }));

    root_module.addSystemIncludePath(b.graph.cwdRelativePath(lvgl_source_dir));
    root_module.addSystemIncludePath(b.graph.cwdRelativePath(sdl_include_dir));
    root_module.addSystemIncludePath(b.path("simulator"));
    const c_flags = &.{
        "-std=c11",
        "-DLV_CONF_INCLUDE_SIMPLE",
        "-DLV_LVGL_H_INCLUDE_SIMPLE",
    };
    root_module.addCSourceFiles(.{
        .root = b.graph.cwdRelativePath(lvgl_source_dir),
        .files = findLvglSources(b, lvgl_source_dir),
        .flags = c_flags,
    });
    root_module.addCSourceFile(.{
        .file = b.path("simulator/bindings.c"),
        .flags = c_flags,
    });

    const simulator = if (builtin.os.tag == .macos) simulator: {
        root_module.addLibraryPath(b.graph.cwdRelativePath(sdl_library_dir));
        root_module.addRPath(b.graph.cwdRelativePath(sdl_library_dir));
        root_module.linkSystemLibrary("SDL3", .{ .use_pkg_config = .no });
        root_module.linkSystemLibrary("m", .{});
        const executable = b.addExecutable(.{
            .name = "flappy-bird-simulator",
            .root_module = root_module,
        });
        break :simulator executable.getEmittedBin();
    } else simulator: {
        const simulator_object = b.addObject(.{
            .name = "flappy-bird-simulator-object",
            .root_module = root_module,
        });
        const linker = b.addSystemCommand(&.{"cc"});
        linker.addArtifactArg(simulator_object);
        linker.addArg("-o");
        const output = linker.addOutputFileArg("flappy-bird-simulator");
        linker.addArgs(&.{
            b.fmt("-L{s}", .{sdl_library_dir}),
            b.fmt("-Wl,-rpath,{s}", .{sdl_library_dir}),
            "-Wl,-z,noexecstack",
            "-lSDL3",
            "-lm",
        });
        break :simulator output;
    };

    const install_simulator = b.addInstallFileWithDir(simulator, .bin, "flappy-bird-simulator");
    b.getInstallStep().dependOn(&install_simulator.step);

    const run_simulator = b.addRunFile(simulator);
    const run_step = b.step("run", "Run the native simulator");
    run_step.dependOn(&run_simulator.step);
}

fn findLvglSources(b: *std.Build, lvgl_source_dir: []const u8) []const []const u8 {
    const source_dir_path = b.pathJoin(&.{ lvgl_source_dir, "src" });
    var source_dir = std.Io.Dir.cwd().openDir(b.graph.io, source_dir_path, .{ .iterate = true }) catch
        @panic("unable to open LVGL source directory");
    defer source_dir.close(b.graph.io);

    var walker = source_dir.walk(b.graph.arena) catch @panic("unable to walk LVGL sources");
    defer walker.deinit();

    var sources: std.ArrayList([]const u8) = .empty;
    while (walker.next(b.graph.io) catch @panic("unable to walk LVGL sources")) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.path, ".c")) {
            sources.append(b.graph.arena, b.fmt("src/{s}", .{entry.path})) catch @panic("OOM");
        }
    }

    std.mem.sort([]const u8, sources.items, {}, struct {
        fn lessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
            return std.mem.lessThan(u8, lhs, rhs);
        }
    }.lessThan);
    return sources.items;
}
