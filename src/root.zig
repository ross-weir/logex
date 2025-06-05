const std = @import("std");

const logex = @import("logex.zig");
pub const Logex = logex.Logex;
pub const LogexOptions = logex.LogexOptions;
pub const TimestampOptions = logex.TimestampOptions;
pub const Context = logex.Context;
pub const Record = logex.Record;
pub const InitializeError = logex.InitializeError;

pub const format = @import("format.zig");
pub const appenders = @import("appenders.zig");
pub const filter = @import("filter.zig");

test "logex" {
    _ = @import("filter.zig");
}
