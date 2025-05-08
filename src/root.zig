const std = @import("std");

pub const Logex = @import("logex.zig").Logex;
pub const InitializeError = @import("logex.zig").InitializeError;
pub const format = @import("format.zig");
pub const appenders = @import("appenders.zig");

/// General Logex & Appender options.
pub const Options = struct {
    /// The format to use when writting log lines.
    format: format.Format = .text,
};

pub const Record = struct {
    level: std.log.Level,
    scope: @Type(.enum_literal),
};

pub const Context = struct {
    message: []const u8,
    datetime: ?[]const u8 = null,
    // thread id
};
