const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Filter = struct {
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
};

const Directive = struct {
    scope: ?[]const u8,
    level: std.log.Level,
};

fn parse(allocator: Allocator, slice: []const u8) ![]Directive {
    var list: std.ArrayListUnmanaged(Directive) = .empty;
    const iter = std.mem.tokenizeSequence(u8, slice, ", \t\n");

    while (iter.next()) |directive| {
        if (std.mem.indexOf(u8, directive, "=")) |pos| {
            const scope = directive[0..pos];
            const level = directive[pos + 1 ..];
            _ = level;

            // try parse level string into log level
            const owned_scope = try allocator.dupe(u8, scope);
            try list.append(allocator, .{ .scope = owned_scope, .level = .info });
        } else {
            // try parse string into log level
            try list.append(allocator, .{ .scope = null, .level = .info });
        }
    }

    // TODO: sort the directives by name so runtime checks are faster
    return list.toOwnedSlice(allocator);
}

pub const EnvFilter = struct {
    directives: []Directive,

    const Self = @This();
    pub const default_env = "ZIG_LOG";

    pub fn init(allocator: Allocator) !Self {
        return initEnvVar(allocator, default_env);
    }

    pub fn initEnvVar(allocator: Allocator, key: []const u8) !Self {
        const slice = std.process.getEnvVarOwned(allocator, key);
        defer allocator.free(slice);
        return initSlice(allocator, slice);
    }

    pub fn initSlice(allocator: Allocator, slice: []const u8) !Self {
        return .{
            .directives = try parse(allocator, slice),
        };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        for (self.directives) |directive| {
            if (directive.scope) |scope| {
                allocator.free(scope);
            }
        }
        allocator.free(self.directives);
    }

    pub fn filter(self: *const Self) Filter {
        return .{
            .context = self,
            .enabledFn = typeErasedEnabledFn,
        };
    }

    pub fn enabled(self: *const Self, level: std.log.Level, scope: []const u8) bool {
        _ = self;
        _ = level;
        _ = scope;
        return true;
    }

    fn typeErasedEnabledFn(
        context: *const anyopaque,
        level: std.log.Level,
        scope: []const u8,
    ) bool {
        const self: *Self = @alignCast(@ptrCast(context));
        return self.enabled(level, scope);
    }
};
