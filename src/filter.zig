const std = @import("std");

const Allocator = std.mem.Allocator;

pub const EnvFilter = struct {
    const Self = @This();
    const default_env = "ZIG_LOG";

    pub fn init(allocator: Allocator) !Self {
        return initEnvVar(allocator, default_env);
    }

    pub fn initEnvVar(allocator: Allocator, key: []const u8) !Self {
        const slice = std.process.getEnvVarOwned(allocator, key);
        defer allocator.free(slice);
        return initSlice(allocator, slice);
    }

    pub fn initSlice(allocator: Allocator, slice: []const u8) !Self {
        _ = allocator;
        _ = slice;
        return .{};
    }

    // parse the env filter string into directives
    fn parse() void {}

    // take scope and level
    pub fn should_log(self: *Self) bool {
        _ = self;
        return true;
    }
};
