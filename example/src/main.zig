const std = @import("std");
const logex = @import("logex");

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

const Logger = logex.Logex(.{
    .console = logex.targets.ConsoleTarget(.{ .level = .debug }),
    .file = logex.targets.FileTarget(.{ .level = .info }),
});

pub fn main() !void {
    try Logger.init(.{
        .console = .init,
        .file = try .init("app.log"),
    });

    std.log.debug("hello world!", .{});
    std.log.info("higher log output to file", .{});
    std.log.info("second info log", .{});
}
