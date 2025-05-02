pub const Logex = @import("logex.zig").Logex;
pub const InitializeError = @import("logex.zig").InitializeError;
pub const format = @import("format.zig");
pub const appenders = @import("appenders.zig");

pub const Options = struct {
    format: format.Format = .text,
};
