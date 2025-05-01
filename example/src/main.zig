const std = @import("std");
const logex = @import("logex");

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

const TextLogFormatter = logex.formatters.TextFormatter();
const Logger = logex.Logex(.{
    .console = logex.targets.ConsoleTarget(.debug, TextLogFormatter),
    .file = logex.targets.FileTarget(.info, TextLogFormatter),
});

pub fn main() !void {
    const text_formatter: TextLogFormatter = .init;

    try Logger.init(.{
        .console = .init(text_formatter),
        .file = try .init(text_formatter, "app.log"),
    });

    std.log.debug("hello world!", .{});
    std.log.info("higher log output to file", .{});
    std.log.info("second info log", .{});
}
