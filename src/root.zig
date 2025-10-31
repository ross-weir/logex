const logex = @import("logex.zig");

pub const Logex = logex.Logex;
pub const LogexOptions = logex.LogexOptions;
pub const InitOptions = logex.InitOptions;
pub const TimestampOptions = logex.TimestampOptions;
pub const Context = logex.Context;
pub const InitializeError = logex.InitializeError;

pub const format = @import("format.zig");
pub const appenders = @import("appenders.zig");
pub const filter = @import("filter.zig");
pub const ColorMode = format.ColorMode;
pub const TextFormatOptions = format.TextFormatOptions;
pub const Palette = format.Palette;
pub const ansi = format.ansi;

test "logex" {
    _ = @import("filter.zig");
}
