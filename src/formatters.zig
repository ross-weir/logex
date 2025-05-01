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
    return struct {};
}
