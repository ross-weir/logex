const std = @import("std");

pub fn defaultFormat(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) []const u8 {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    var buf: [2048]u8 = undefined;

    return std.fmt.bufPrint(&buf, level_txt ++ prefix2 ++ format ++ "\n", args) catch unreachable;
}

pub const FormatFn = fn (
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) []const u8;
