/// Simple example showing how to use `Logex` in a application.
///
/// Logex is designed to be a drop-in extension for `std.log`,
/// this means it's easy to add to an existing project (and remove it if you want)
const std = @import("std");
const logex = @import("logex");

/// Create our console appender type.
/// Configured to log debug level and above messages & using default options.
const ConsoleAppender = logex.appenders.Console(.debug, .{});

// Create our file appender type.
// Configured to log info level and above messages, using json formatting.
const FileAppender = logex.appenders.File(.info, .{
    .format = .json,
});

/// Create our Logger type using console & file appender types.
/// Returns the `logFn` we use in std_options as well as an `init`
/// function which initializes the logger.
const Logger = logex.Logex(.{ ConsoleAppender, FileAppender });

pub const std_options: std.Options = .{
    // Use our loggers `logFn` which provides console and file logging.
    .logFn = Logger.logFn,
};

const scoped = std.log.scoped(.custom);

pub fn main() !void {
    std.debug.print("Running 'simple' example\n", .{});

    // Create our console appender instance
    // it doesnt take any runtime configuration options at the moment
    const console_appender = ConsoleAppender.init;

    // Create our file appender instance
    // Passing the file name as init parameter
    const file_appender = try FileAppender.init("app.log");

    // Initialize our logger using the appender instances
    try Logger.init(
        .{},
        .{ console_appender, file_appender },
    );

    // `debug` log, only logged to console - file logger is configured for `info`
    std.log.debug("hello world!", .{});

    // `info` logs, logged to both the console and file.
    // `app.log` will contain the messages in JSON format.
    std.log.info("higher log output to file", .{});
    std.log.info("second info log", .{});

    // Also works fine with scoped loggers
    scoped.info("scoped logger also works", .{});
}
