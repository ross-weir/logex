const std = @import("std");
const root = @import("root.zig");

const Options = root.Options;
const Record = root.Record;
const Context = root.Context;

/// Function type that is called to format log messages.
pub const FormatFn = fn (
    writer: anytype,
    comptime record: *const Record,
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
        writer: anytype,
        comptime record: *const Record,
        context: *const Context,
    ) anyerror!void {
        return switch (self) {
            .text => text(writer, record, context),
            .json => json(writer, record, context),
            .custom => |func| func(writer, record, context),
        };
    }
};

fn text(
    writer: anytype,
    comptime record: *const Record,
    context: *const Context,
) @TypeOf(writer).Error!void {
    const level_txt = comptime record.level.asText();
    const prefix2 = if (record.scope == std.log.default_log_scope) ": " else "(" ++ @tagName(record.scope) ++ "): ";
    try writer.print(level_txt ++ prefix2 ++ "{s}\n", .{context.message});
}

fn json(
    writer: anytype,
    comptime record: *const Record,
    context: *const Context,
) @TypeOf(writer).Error!void {
    // try avoid allocations for now
    const level = comptime record.level.asText();
    try std.json.stringify(
        .{
            .level = level,
            .scope = @tagName(record.scope),
            .message = context.message,
        },
        .{},
        writer,
    );
    try writer.writeByte('\n');
}
