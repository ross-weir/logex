const std = @import("std");
const logex = @import("logex");

// Basic example showing how to implement a custom appender
// Logs to `stdout` as opposed to the logex provided console logger that uses `stderr`.
pub fn CustomAppender(
    comptime level: std.log.Level,
    comptime opts: logex.Options,
) type {
    return struct {
        const Self = @This();

        writer: std.fs.File.Writer,

        pub fn init() Self {
            const stdout = std.io.getStdOut();

            return .{ .writer = stdout.writer() };
        }

        pub fn log(
            self: *Self,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            // comptime log level check, no runtime overhead
            if (comptime @intFromEnum(message_level) > @intFromEnum(level)) return;

            try opts.format.write(self.writer, message_level, scope, format, args, opts);
        }
    };
}

const MyAppender = CustomAppender(.debug, .{});
const Logger = logex.Logex(.{MyAppender});

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

pub fn main() !void {
    std.debug.print("Running 'custom_appender' example\n", .{});

    try Logger.init(.{.init()});

    std.log.info("Logging some output", .{});
}
