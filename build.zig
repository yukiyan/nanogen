const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "nanogen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = switch (optimize) {
                .ReleaseSafe, .ReleaseSmall, .ReleaseFast => true,
                else => false,
            },
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run nanogen");
    run_step.dependOn(&run_cmd.step);

    // Test step: run tests for each module
    const test_step = b.step("test", "Run unit tests");
    const test_modules = [_][]const u8{
        "src/timestamp.zig",
        "src/log.zig",
        "src/cli.zig",
        "src/fs.zig",
        "src/config.zig",
        "src/opener.zig",
        "src/base64.zig",
        "src/json_build.zig",
        "src/json_parse.zig",
        "src/api.zig",
        "src/client.zig",
        "src/main.zig",
    };
    for (test_modules) |mod| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(mod),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_t = b.addRunArtifact(t);
        test_step.dependOn(&run_t.step);
    }
}
