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

/// A record structure containing information about a logging event.
/// This type contains fields that are comptime known only.
///
/// This struct is separate to `Context` so it can remain `comptime`
/// which is important for comptime log level checking.
pub const Record = struct {
    level: std.log.Level,
    scope: @Type(.enum_literal),
};

/// Provides context that is needed to write the log line.
/// The extra context could be added depending on option
/// configuration and will be determined at runtime.
///
/// This struct is separate to `Record` because it contains
/// runtime fields and thus can't be used at comptime.
pub const Context = struct {
    /// The formatted log message
    message: []const u8,
    /// The datetime of the log
    ///
    /// Will be available if logging was configured to include
    /// a timestamp, otherwise it will be null.
    datetime: ?[]const u8 = null,
    // thread id
};
