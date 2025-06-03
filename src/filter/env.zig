const std = @import("std");
const Filter = @import("./Filter.zig");

const Allocator = std.mem.Allocator;

const Directive = struct {
    scope: ?[]const u8,
    level: std.log.Level,
};

fn sortDirectives(_: void, a: Directive, b: Directive) bool {
    if (a.scope == null and b.scope == null) return false;
    if (a.scope == null) return false;
    if (b.scope == null) return true;
    return std.ascii.lessThanIgnoreCase(a.scope.?, b.scope.?);
}

fn parse(allocator: Allocator, slice: []const u8) ![]Directive {
    var list: std.ArrayListUnmanaged(Directive) = .empty;
    var iter = std.mem.tokenizeScalar(u8, slice, ',');

    while (iter.next()) |directive| {
        if (std.mem.indexOf(u8, directive, "=")) |pos| {
            const scope_part = directive[0..pos];
            const level_part = directive[pos + 1 ..];
            const level = std.meta.stringToEnum(std.log.Level, level_part) orelse continue;
            const scope = try allocator.dupe(u8, scope_part);

            try list.append(allocator, .{ .scope = scope, .level = level });
        } else {
            const level = std.meta.stringToEnum(std.log.Level, directive) orelse continue;
            try list.append(allocator, .{ .scope = null, .level = level });
        }
    }

    const dirs = try list.toOwnedSlice(allocator);
    std.sort.block(Directive, dirs, {}, sortDirectives);

    return dirs;
}

fn deinitDirectives(allocator: Allocator, directives: []Directive) void {
    for (directives) |directive| {
        if (directive.scope) |scope| {
            allocator.free(scope);
        }
    }
    allocator.free(directives);
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

    pub fn deinit(self: *const Self, allocator: Allocator) void {
        deinitDirectives(allocator, self.directives);
    }

    pub fn filter(self: *const Self) Filter {
        return .{
            .context = self,
            .enabledFn = typeErasedEnabledFn,
        };
    }

    pub fn enabled(self: *const Self, level: std.log.Level, scope: []const u8) bool {
        for (self.directives) |directive| {
            if (directive.scope) |s| {
                if (!std.mem.eql(u8, s, scope)) continue;
            }
            return @intFromEnum(level) <= @intFromEnum(directive.level);
        }

        return false;
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

const expectEqualDeep = std.testing.expectEqualDeep;

test parse {
    const dirs = try parse(std.testing.allocator, "scope1=debug,scope2=info,scope3=warn,scope55=err");
    defer deinitDirectives(std.testing.allocator, dirs);
    const expected = [_]Directive{
        .{ .scope = "scope1", .level = .debug },
        .{ .scope = "scope2", .level = .info },
        .{ .scope = "scope3", .level = .warn },
        .{ .scope = "scope55", .level = .err },
    };

    try expectEqualDeep(&expected, dirs);
}

test "parse - multiple levels" {
    const dirs = try parse(std.testing.allocator, "scope1=info=debug");
    try std.testing.expectEqual(&[_]Directive{}, dirs);
}

test "parse - invalid level" {
    const dirs = try parse(std.testing.allocator, "scope1=invalidLevel");
    try std.testing.expectEqual(&[_]Directive{}, dirs);
}

test "parse - sorting" {
    const dirs = try parse(std.testing.allocator, "scope1=debug,alpha=info,info,zebra=err,batman=warn");
    defer deinitDirectives(std.testing.allocator, dirs);
    const expected = [_]Directive{
        .{ .scope = "alpha", .level = .info },
        .{ .scope = "batman", .level = .warn },
        .{ .scope = "scope1", .level = .debug },
        .{ .scope = "zebra", .level = .err },
        .{ .scope = null, .level = .info },
    };
    try expectEqualDeep(
        &expected,
        dirs,
    );
}
