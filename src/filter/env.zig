/// Apply filtering based on environment variables
/// Inspired by env filtering from the Rust logging ecosystem: https://github.com/rust-cli/env_logger/tree/main/crates/env_filter
///
/// When no environment variable is set, the filter will fall back to using `std.options.log_level`
/// for all scopes. This means logs will be filtered based on the compile-time log level settings.
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

/// EnvFilter provides log filtering based on environment variables.
/// It allows configuring log levels for specific scopes through environment variables.
/// The default environment variable used is "ZIG_LOG".
///
/// When no environment variable is set, the filter will fall back to using `std.options.log_level`
/// for all scopes. This means logs will be filtered based on the compile-time log level settings.
pub const EnvFilter = struct {
    const Self = @This();
    /// The default environment variable name used for log configuration
    pub const default_env = "ZIG_LOG";

    directives: []Directive,

    /// Initializes a new EnvFilter using the default environment variable (ZIG_LOG)
    /// Returns an error if the environment variable cannot be read or parsed
    pub fn init(allocator: Allocator) !Self {
        return initEnvVar(allocator, default_env);
    }

    /// Initializes a new EnvFilter using a specific environment variable
    /// Returns an error if the environment variable cannot be read or parsed
    pub fn initEnvVar(allocator: Allocator, key: []const u8) !Self {
        const slice = std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
            error.EnvironmentVariableNotFound => return .{ .directives = &[_]Directive{} },
            else => return err,
        };
        defer allocator.free(slice);
        return initSlice(allocator, slice);
    }

    /// Initializes a new EnvFilter using a direct string slice
    /// The string should be in the format "scope1=level1,scope2=level2" or just "level" for global level
    /// Returns an error if the string cannot be parsed
    pub fn initSlice(allocator: Allocator, slice: []const u8) !Self {
        return .{
            .directives = try parse(allocator, slice),
        };
    }

    /// Frees all resources associated with this EnvFilter
    pub fn deinit(self: *const Self, allocator: Allocator) void {
        deinitDirectives(allocator, self.directives);
    }

    /// Creates a Filter instance that can be used with the logging system
    pub fn filter(self: *const Self) Filter {
        return .{
            .context = self,
            .enabledFn = typeErasedEnabledFn,
        };
    }

    /// Checks if a log message with the given level and scope should be enabled
    /// Returns true if the message should be logged, false otherwise
    pub fn enabled(self: *const Self, level: std.log.Level, scope: []const u8) bool {
        for (self.directives) |directive| {
            if (directive.scope) |s| {
                if (!std.mem.eql(u8, s, scope)) continue;
            }
            return @intFromEnum(level) <= @intFromEnum(directive.level);
        }

        return @intFromEnum(level) <= @intFromEnum(std.options.log_level);
    }

    fn typeErasedEnabledFn(
        context: *const anyopaque,
        level: std.log.Level,
        scope: []const u8,
    ) bool {
        const self: *const Self = @ptrCast(@alignCast(context));
        return self.enabled(level, scope);
    }
};

const expectEqualDeep = std.testing.expectEqualDeep;
const expect = std.testing.expect;

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

test "parse - global" {
    const dirs = try parse(std.testing.allocator, "warn");
    defer deinitDirectives(std.testing.allocator, dirs);
    try expectEqualDeep(
        &[_]Directive{
            .{ .scope = null, .level = .warn },
        },
        dirs,
    );
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

test "EnvFilter.enabled - global" {
    const filter: EnvFilter = try .initSlice(std.testing.allocator, "info");
    defer filter.deinit(std.testing.allocator);

    try expect(filter.enabled(.info, "scope1"));
    try expect(!filter.enabled(.debug, "scope1"));
}

test "EnvFilter.enabled - scoped" {
    const filter: EnvFilter = try .initSlice(std.testing.allocator, "scope1=info");
    defer filter.deinit(std.testing.allocator);

    try expect(filter.enabled(.info, "scope1"));
    try expect(!filter.enabled(.debug, "scope1"));
}

test "EnvFilter.enabled - scoped and global" {
    const filter: EnvFilter = try .initSlice(std.testing.allocator, "info,scope1=warn");
    defer filter.deinit(std.testing.allocator);

    try expect(filter.enabled(.warn, "scope1"));
    try expect(filter.enabled(.info, "scope2"));
}

test "EnvFilter.enabled - scoped preferred over global" {
    const filter: EnvFilter = try .initSlice(std.testing.allocator, "info,scope1=debug");
    defer filter.deinit(std.testing.allocator);

    try expect(filter.enabled(.debug, "scope1"));
    try expect(!filter.enabled(.debug, "scope2"));
    try expect(filter.enabled(.info, "scope2"));
}

test "EnvFilter.enabled - no match" {
    const filter: EnvFilter = try .initSlice(std.testing.allocator, "scope1=warn,scope2=debug");
    defer filter.deinit(std.testing.allocator);

    try expect(filter.enabled(std.options.log_level, "scope3"));
}

// Test that we cover all log level variants
// In the unlikely case that a new log level variant is added we ensure we catch it with this test
test "universe" {
    switch (std.options.log_level) {
        .debug, .info, .warn, .err => {},
    }
}
