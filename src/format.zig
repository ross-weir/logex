const std = @import("std");
const root = @import("root.zig");

const Options = root.Options;
const Context = root.Context;

/// Function type that is called to format log messages.
pub const FormatFn = *const fn (
    writer: *std.Io.Writer,
    context: *const Context,
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
        writer: *std.Io.Writer,
        context: *const Context,
    ) anyerror!void {
        return switch (self) {
            .text => text(writer, context),
            .json => json(writer, context),
            .custom => |func| func(writer, context),
        };
    }
};

fn text(
    writer: *std.Io.Writer,
    context: *const Context,
) !void {
    if (context.timestamp) |ts| {
        try writer.print("{s} ", .{ts});
    }

    if (context.thread) |th| {
        try writer.print("tid={s} ", .{th});
    }

    try writer.print("{s}({s}): {s}\n", .{ context.level, context.scope, context.message });
}

fn json(
    writer: *std.Io.Writer,
    context: *const Context,
) !void {
    var stringify: std.json.Stringify = .{ .writer = writer, .options = .{ .emit_null_optional_fields = false } };
    try stringify.write(context);
    try writer.writeByte('\n');
}
