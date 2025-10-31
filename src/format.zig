const std = @import("std");
const root = @import("root.zig");

const Options = root.Options;
const Context = root.Context;

pub const ansi = struct {
    pub const reset = "\x1b[0m";
    pub const bold = "\x1b[1m";
    pub const dim = "\x1b[2m";
    pub const red = "\x1b[31m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const blue = "\x1b[34m";
    pub const magenta = "\x1b[35m";
    pub const cyan = "\x1b[36m";
    pub const bright_black = "\x1b[90m";
    pub const bright_red = "\x1b[91m";
    pub const bright_yellow = "\x1b[93m";
};

/// Controls how ANSI colors are applied when using `.styled_text` formatting.
pub const ColorMode = enum {
    /// Resolves color support using the configured detection callback each time a log line is written.
    auto,
    /// Always emit color escape sequences.
    force_on,
    /// Never emit color escape sequences.
    force_off,
};

/// Palette of ANSI escapes used by styled text formatting.
pub const Palette = struct {
    timestamp: []const u8 = ansi.bright_black,
    thread: []const u8 = ansi.magenta,
    scope: []const u8 = ansi.cyan,
    message: []const u8 = "",
    level_err: []const u8 = ansi.red,
    level_warn: []const u8 = ansi.yellow,
    level_info: []const u8 = ansi.green,
    level_debug: []const u8 = ansi.cyan,

    pub fn colorForLevel(self: Palette, level_text: []const u8) []const u8 {
        if (level_text.len == 0) return "";

        return switch (std.ascii.toLower(level_text[0])) {
            'e' => self.level_err,
            'w' => self.level_warn,
            'i' => self.level_info,
            'd' => self.level_debug,
            else => "",
        };
    }
};

/// Options for styled text formatting.
pub const TextFormatOptions = struct {
    /// Controls when color escapes are emitted.
    color_mode: ColorMode = .auto,
    /// Palette used to render individual components.
    palette: Palette = .{},
    /// Optional callback to decide if ANSI escapes should be used when `color_mode == .auto`.
    supports_color_fn: ?ColorSupportFn = null,

    pub const ColorSupportFn = *const fn () bool;

    pub fn colorEnabled(self: TextFormatOptions) bool {
        return switch (self.color_mode) {
            .force_on => true,
            .force_off => false,
            .auto => if (self.supports_color_fn) |detect| detect() else false,
        };
    }
};

/// Function type that is called to format log messages.
pub const FormatFn = *const fn (
    writer: *std.Io.Writer,
    context: *const Context,
) anyerror!void;

/// Formatting to be used when writting logs.
pub const Format = union(enum) {
    /// Text based formatting, logs are formatted the same as `std.log` by default.
    text,
    /// Text formatting with ANSI color and style support.
    styled_text: TextFormatOptions,
    /// Logs are outputted as JSON.
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
            .styled_text => |options| styledText(writer, context, options),
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

fn styledText(
    writer: *std.Io.Writer,
    context: *const Context,
    options: TextFormatOptions,
) !void {
    if (!options.colorEnabled()) return text(writer, context);

    const palette = options.palette;

    if (context.timestamp) |ts| {
        try writeColored(writer, ts, palette.timestamp);
        try writer.writeByte(' ');
    }

    if (context.thread) |th| {
        try writeColored(writer, th, palette.thread);
        try writer.writeByte(' ');
    }

    try writeColored(writer, context.level, palette.colorForLevel(context.level));
    try writer.writeByte('(');
    try writeColored(writer, context.scope, palette.scope);
    try writer.print("): ", .{});
    try writeColored(writer, context.message, palette.message);
    try writer.writeByte('\n');
}

fn writeColored(writer: *std.Io.Writer, payload: []const u8, color: []const u8) !void {
    if (color.len == 0) {
        try writer.print("{s}", .{payload});
        return;
    }

    try writer.print("{s}{s}{s}", .{ color, payload, ansi.reset });
}

test "styled text emits ansi escapes when enabled" {
    var buffer: [256]u8 = undefined;
    var writer = std.io.Writer.fixed(buffer[0..]);

    const context: Context = .{
        .level = "info",
        .scope = "app",
        .message = "hello world",
    };

    const fmt = Format{ .styled_text = .{ .supports_color_fn = fakeSupportsColorTrue } };

    try fmt.write(&writer, &context);
    const written = writer.buffer[0..writer.end];

    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b[") != null);
    try std.testing.expect(std.mem.endsWith(u8, written, "\n"));
}

test "styled text respects auto color detection" {
    var buffer: [256]u8 = undefined;
    var writer = std.io.Writer.fixed(buffer[0..]);

    const context: Context = .{
        .level = "debug",
        .scope = "app",
        .message = "no color",
    };

    const fmt = Format{ .styled_text = .{ .color_mode = .auto, .supports_color_fn = fakeSupportsColorFalse } };

    try fmt.write(&writer, &context);
    const written = writer.buffer[0..writer.end];

    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b[") == null);
    try std.testing.expectEqualStrings("debug(app): no color\n", written);
}

test "styled text force on bypasses support check" {
    var buffer: [256]u8 = undefined;
    var writer = std.io.Writer.fixed(buffer[0..]);

    const context: Context = .{
        .level = "error",
        .scope = "main",
        .message = "forced",
    };

    const fmt = Format{ .styled_text = .{
        .color_mode = .force_on,
        .supports_color_fn = fakeSupportsColorFalse,
    } };

    try fmt.write(&writer, &context);
    const written = writer.buffer[0..writer.end];

    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b[") != null);
}

test "styled text force off disables colors" {
    var buffer: [256]u8 = undefined;
    var writer = std.io.Writer.fixed(buffer[0..]);

    const context: Context = .{
        .level = "warning",
        .scope = "main",
        .message = "muted",
    };

    const fmt = Format{ .styled_text = .{
        .color_mode = .force_off,
        .supports_color_fn = fakeSupportsColorTrue,
    } };

    try fmt.write(&writer, &context);
    const written = writer.buffer[0..writer.end];

    try std.testing.expect(std.mem.indexOf(u8, written, "\x1b[") == null);
}

test "styled text applies custom palette" {
    var buffer: [256]u8 = undefined;
    var writer = std.io.Writer.fixed(buffer[0..]);

    const highlight = ansi.bright_yellow;
    const options = TextFormatOptions{
        .color_mode = .force_on,
        .palette = .{
            .message = highlight,
            .level_info = ansi.blue,
            .level_debug = ansi.magenta,
            .level_warn = ansi.bright_yellow,
            .level_err = ansi.bright_red,
        },
    };

    const context: Context = .{
        .level = "info",
        .scope = "palette",
        .message = "custom",
    };

    const fmt = Format{ .styled_text = options };

    try fmt.write(&writer, &context);
    const written = writer.buffer[0..writer.end];

    try std.testing.expect(std.mem.indexOf(u8, written, highlight) != null);
    try std.testing.expect(std.mem.indexOf(u8, written, ansi.blue) != null);
}

fn fakeSupportsColorTrue() bool {
    return true;
}

fn fakeSupportsColorFalse() bool {
    return false;
}
