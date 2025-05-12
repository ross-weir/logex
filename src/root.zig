const std = @import("std");

const logex = @import("logex.zig");
pub const Logex = logex.Logex;
pub const LogexOptions = logex.LogexOptions;
pub const TimestampOptions = logex.TimestampOptions;
pub const InitializeError = @import("logex.zig").InitializeError;
pub const format = @import("format.zig");
pub const appenders = @import("appenders.zig");
pub const Context = @import("context.zig").Context;

/// A record structure containing information about a logging event.
/// This type contains fields that are comptime known only.
///
/// This struct is separate to `Context` so it can remain `comptime`
/// which is important for comptime log level checking.
pub const Record = struct {
    level: std.log.Level,
    scope: @Type(.enum_literal),
};
