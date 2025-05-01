const std = @import("std");
const logex = @import("logex");

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

const TextFormatter = logex.formatters.TextFormatter();
const JsonFormatter = logex.formatters.JsonFormatter();

const Logger = logex.Logex(.{
    .console = logex.targets.ConsoleTarget(.debug, TextFormatter),
    .file = logex.targets.FileTarget(.info, JsonFormatter),
});

pub fn main() !void {
    const text_formatter: TextFormatter = .init;
    const json_formatter: JsonFormatter = .init;

    try Logger.init(.{
        .console = .init(text_formatter),
        .file = try .init(json_formatter, "app.log"),
    });

    std.log.debug("hello world!", .{});
    std.log.info("higher log output to file", .{});
    std.log.info("second info log", .{});
}
