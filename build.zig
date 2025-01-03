const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zjpeg",
        .root_source_file = b.path("src/zjpeg.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Dependencies
    const sdl_dep = b.dependency("SDL", .{
        .optimize = optimize,
        .target = target,
    });
    const sdl_artifact = sdl_dep.artifact("SDL2");
    for (sdl_artifact.root_module.include_dirs.items) |include_dir| {
        try exe.root_module.include_dirs.append(b.allocator, include_dir);
    }
    exe.linkLibrary(sdl_artifact);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/zjpeg.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.linkLibrary(sdl_artifact);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Copy documentation artifacts to prefix path");
    docs_step.dependOn(&install_docs.step);

    const serve_step = b.step("serve", "Serve documentation");
    var a3: [3][]const u8 = .{ "zig", "run", "serveDocs.zig" };
    const serve_run = b.addSystemCommand(&a3);
    serve_step.dependOn(&serve_run.step);
}
