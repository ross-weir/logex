const std = @import("std");
const logex = @import("logex");

const ConsoleAppender = logex.appenders.Console(.debug, .{});
const FileAppender = logex.appenders.File(.info, .{
    .format = .json,
});

const Logger = logex.Logex(.{ ConsoleAppender, FileAppender });

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

pub fn main() !void {
    try Logger.init(.{
        ConsoleAppender.init,
        try FileAppender.init("app.log"),
    });

    std.log.debug("hello world!", .{});
    std.log.info("higher log output to file", .{});
    std.log.info("second info log", .{});
}
