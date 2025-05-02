const std = @import("std");
const Options = @import("root.zig").Options;

pub const Format = union(enum) {
    text,
    json,
    custom: @TypeOf(formatFn),
};

pub fn formatFn(
    writer: anytype,
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
    comptime opts: Options,
) anyerror!void {
    return switch (opts.format) {
        .text => text(writer, message_level, scope, fmt, args, opts),
        .json => json(writer, message_level, scope, fmt, args, opts),
        .custom => |func| func(writer, message_level, scope, fmt, args, opts),
    };
}

fn text(
    writer: anytype,
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
    comptime _: Options,
) @TypeOf(writer).Error!void {
    const level_txt = comptime message_level.asText();
    const prefix2 = if (scope == std.log.default_log_scope) ": " else "(" ++ @tagName(scope) ++ "): ";
    try writer.print(level_txt ++ prefix2 ++ fmt ++ "\n", args);
}

fn json(
    writer: anytype,
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
    comptime _: Options,
) @TypeOf(writer).Error!void {
    // try avoid allocations for now
    var buf: [2048]u8 = undefined;
    const message = try std.fmt.bufPrint(&buf, fmt, args);
    const level = comptime message_level.asText();
    try std.json.stringify(
        .{
            .level = level,
            .scope = @tagName(scope),
            .message = message,
        },
        .{},
        writer,
    );
    try writer.writeByte('\n');
}
