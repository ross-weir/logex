const std = @import("std");
const logex = @import("logex");

// Define a basic custom formatting function that simply
// prefixes the log line with `[custom]` for demo purposes
pub fn formatFn(
    writer: anytype,
    comptime _: std.log.Level,
    comptime _: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
    comptime _: logex.Options,
) @TypeOf(writer).Error!void {
    try writer.print("[custom] " ++ format ++ "\n", args);
}

const ConsoleAppender = logex.appenders.Console(.debug, .{
    // Configure the console appender to use our custom format function
    .format = .{ .custom = formatFn },
});
const Logger = logex.Logex(.{ConsoleAppender});

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

pub fn main() !void {
    std.debug.print("Running 'custom_format' example\n", .{});

    // Initialize the logger and console appender
    try Logger.init(.{.init});

    // Log output will be in our custom format with `[custom]` prepended to the log message.
    std.log.info("Logging some output", .{});
}
