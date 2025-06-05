/// Example showing how to use environment variable filtering with `Logex`.
///
/// This example demonstrates how to configure log levels at runtime using
/// the ZIG_LOG environment variable, similar to Rust's env_logger.
const std = @import("std");
const logex = @import("logex");

/// Create our console appender type.
/// Configured to log debug level and above messages & using default options.
const ConsoleAppender = logex.appenders.Console(.debug, .{});

/// Create our Logger type using the console appender type.
/// We'll use the environment variable filter to control log levels at runtime.
const Logger = logex.Logex(.{ConsoleAppender});

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

// Create some scoped loggers for demonstration
const module_a = std.log.scoped(.module_a);
const module_b = std.log.scoped(.module_b);
const module_c = std.log.scoped(.module_c);

// Example ZIG_LOG values to try:
//   ZIG_LOG=info - Show all info and above logs
//   ZIG_LOG=module_a=debug,module_b=warn - Debug logs for module_a, warn for module_b
//   ZIG_LOG=info,module_c=debug - Info for all, debug for module_c
pub fn main() !void {
    std.debug.print("Running 'filter' example\n", .{});

    // Create our console appender instance
    const console_appender = ConsoleAppender.init;
    // Create our environment variable filter
    const env_filter = try logex.filter.EnvFilter.init(std.heap.page_allocator);
    defer env_filter.deinit(std.heap.page_allocator);

    // Initialize our logger using the appender instance and environment variable filter
    try Logger.init(
        .{ .filter = env_filter.filter() },
        .{console_appender},
    );

    // Log messages at different levels from different scopes
    std.log.debug("Root debug message", .{});
    std.log.info("Root info message", .{});
    std.log.warn("Root warning message", .{});
    std.log.err("Root error message", .{});

    module_a.debug("Module A debug message", .{});
    module_a.info("Module A info message", .{});
    module_a.warn("Module A warning message", .{});
    module_a.err("Module A error message", .{});

    module_b.debug("Module B debug message", .{});
    module_b.info("Module B info message", .{});
    module_b.warn("Module B warning message", .{});
    module_b.err("Module B error message", .{});

    module_c.debug("Module C debug message", .{});
    module_c.info("Module C info message", .{});
    module_c.warn("Module C warning message", .{});
    module_c.err("Module C error message", .{});
}
