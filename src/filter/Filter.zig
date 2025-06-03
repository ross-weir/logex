const std = @import("std");

const Self = @This();

context: *const anyopaque,
enabledFn: *const fn (
    context: *const anyopaque,
    level: std.log.Level,
    scope: []const u8,
) bool,

pub fn enabled(
    self: Self,
    level: std.log.Level,
    scope: []const u8,
) bool {
    return self.enabledFn(self.context, level, scope);
}
