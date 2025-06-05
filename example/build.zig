const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const logex = b.dependency("logex", .{
        .target = target,
        .optimize = optimize,
    });

    const run_all_step = b.step("run", "Run all the examples");

    for (examples) |example_path| {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path(example_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "logex",
                    .module = logex.module("logex"),
                },
            },
        });

        const example_name = std.fs.path.stem(example_path);
        const exe = b.addExecutable(.{
            .name = example_name,
            .root_module = exe_mod,
        });
        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const example_step_desc = b.fmt("Run the '{s}' example ({s})", .{ example_name, example_path });
        const run_example_step = b.step(example_name, example_step_desc);
        run_example_step.dependOn(&run_cmd.step);

        run_all_step.dependOn(&run_cmd.step);
    }
}

const examples = [_][]const u8{
    "src/simple.zig",
    "src/filter.zig",
    "src/custom_format.zig",
    "src/custom_appender.zig",
};
