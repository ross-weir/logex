const std = @import("std");

const Allocator = std.mem.Allocator;

context: *const anyopaque,
enabledFn: *const fn (
    context: *const anyopaque,
    level: std.log.Level,
    scope: []const u8,
) bool,

pub fn enabled(
    self: @This(),
    level: std.log.Level,
    scope: []const u8,
) bool {
    return self.enabledFn(self.context, level, scope);
}
