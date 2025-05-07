const std = @import("std");
const Options = @import("root.zig").Options;

/// Function type that is called to format log messages.
pub const FormatFn = fn (
    writer: anytype,
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
    comptime opts: Options,
) anyerror!void;

/// Formatting to be used when writting logs.
pub const Format = union(enum) {
    /// Text based formatting, logs are formatted the same as `std.log` by default.
    text,
    /// Logs are outtputed as JSON.
    json,
    /// Logs are formatted by a custom formatting function provided by the user.
    custom: FormatFn,

    pub fn write(
        self: Format,
        writer: anytype,
        comptime message_level: std.log.Level,
        comptime scope: @Type(.enum_literal),
        comptime fmt: []const u8,
        args: anytype,
        comptime opts: Options,
    ) anyerror!void {
        return switch (self) {
            .text => text(writer, message_level, scope, fmt, args, opts),
            .json => json(writer, message_level, scope, fmt, args, opts),
            .custom => |func| func(writer, message_level, scope, fmt, args, opts),
        };
    }
};

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
