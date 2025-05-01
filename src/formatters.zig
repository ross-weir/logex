const std = @import("std");

pub fn TextFormatter() type {
    return struct {
        const Self = @This();

        pub const init: Self = .{};

        pub fn format(
            _: *Self,
            writer: anytype,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime fmt: []const u8,
            args: anytype,
        ) @TypeOf(writer).Error!void {
            const level_txt = comptime message_level.asText();
            const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
            try writer.print(level_txt ++ prefix2 ++ fmt ++ "\n", args);
        }
    };
}

pub fn JsonFormatter() type {
    return struct {
        const Self = @This();

        pub const init: Self = .{};

        pub fn format(
            _: *Self,
            writer: anytype,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime fmt: []const u8,
            args: anytype,
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
    };
}
