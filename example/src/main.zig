const std = @import("std");
const logex = @import("logex");

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

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

const Logger = logex.Logex(.{
    .console = logex.appenders.Console(.debug, .{
        .format = .{ .custom = formatFn },
    }),
    .file = logex.appenders.File(.info, .{
        .format = .json,
    }),
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
