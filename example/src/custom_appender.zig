const std = @import("std");
const logex = @import("logex");

// Basic example showing how to implement a custom appender
// Logs to `stdout` as opposed to the logex provided console logger that uses `stderr`.
pub fn CustomAppender(
    comptime level: std.log.Level,
    comptime opts: logex.appenders.Options,
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
            comptime record: *const logex.Record,
            context: *const logex.Context,
        ) !void {
            // comptime log level check, no runtime overhead
            if (comptime @intFromEnum(record.level) > @intFromEnum(level)) return;

            try opts.format.write(self.writer, record, context);
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

    try Logger.init(.{}, .{.init()});

    std.log.info("Logging some output", .{});
}
