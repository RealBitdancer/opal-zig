// Copyright (c) 2026 Bitdancer (github.com/RealBitdancer).
// SPDX-License-Identifier: MIT
//
// Generated with zig init and adapted to fit the needs of this project.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("opal_c", .{});

    const mod = b.addModule("opal", .{
        .root_source_file = b.path("src/opal.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(upstream.path("include"));
    mod.addCSourceFile(.{
        .file = upstream.path("src/opal.c"),
        .flags = &.{"-std=c11"},
    });

    const demo = b.addExecutable(.{
        .name = "opal-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/demo/src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "opal", .module = mod },
            },
        }),
    });
    b.installArtifact(demo);

    const run_step = b.step("run", "Render the demo tune to opal-demo.wav");
    const run_cmd = b.addRunArtifact(demo);
    run_cmd.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_cmd.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "opal", .module = mod },
        },
    });
    test_mod.addIncludePath(upstream.path("include"));
    test_mod.addCSourceFile(.{
        .file = b.path("src/abi_check.c"),
        .flags = &.{"-std=c11"},
    });

    const tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run the binding tests");
    test_step.dependOn(&run_tests.step);
}
