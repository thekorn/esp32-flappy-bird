const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .xtensa,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_model = .{ .explicit = &std.Target.xtensa.cpu.esp32s3 },
    });
    const optimize = b.standardOptimizeOption(.{});

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
