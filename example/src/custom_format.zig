const std = @import("std");
const logex = @import("logex");

// Define a basic custom formatting function that simply
// prefixes the log line with `[custom]` for demo purposes
pub fn formatFn(
    writer: *std.Io.Writer,
    context: *const logex.Context,
) std.Io.Writer.Error!void {
    try writer.print("[custom] {s}\n", .{context.message});
}

const ConsoleAppender = logex.appenders.Console(.debug, .{
    // Configure the console appender to use our custom format function
    .format = .{ .custom = formatFn },
});
const Logger = logex.Logex(.{}, .{ConsoleAppender});

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

pub fn main() !void {
    std.debug.print("Running 'custom_format' example\n", .{});

    // Initialize the logger and console appender
    try Logger.init(.{}, .{.init});

    // Log output will be in our custom format with `[custom]` prepended to the log message.
    std.log.info("Logging some output", .{});
}
