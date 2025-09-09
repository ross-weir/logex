const std = @import("std");
const logex = @import("logex");

// Basic example showing how to implement a custom appender
// Logs to `stdout` as opposed to the logex provided console logger that uses `stderr`.
// A real implementation would also sync access to stdout using a mutex, etc.
pub fn CustomAppender(
    comptime level: std.log.Level,
    comptime opts: logex.appenders.Options,
) type {
    return struct {
        const Self = @This();
        var buffer: [4096]u8 = undefined;

        pub fn log(
            _: *Self,
            context: *const logex.Context,
        ) !void {
            var writer = std.fs.File.stdout().writer(&buffer);
            const stdout = &writer.interface;

            try opts.format.write(stdout, context);
            try stdout.flush();
        }

        // simply checks log level but could include more complicated "enabled" logic
        pub fn enabled(comptime log_level: std.log.Level) bool {
            return @intFromEnum(log_level) <= @intFromEnum(level);
        }
    };
}

const MyAppender = CustomAppender(.debug, .{});
const Logger = logex.Logex(.{}, .{MyAppender});

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

pub fn main() !void {
    std.debug.print("Running 'custom_appender' example\n", .{});
    try Logger.init(.{}, .{.{}});

    std.log.info("Logging some output", .{});
}
