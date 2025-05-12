const std = @import("std");
const root = @import("root.zig");

const LogexOptions = root.LogexOptions;
const DateTimeOptions = root.DateTimeOptions;

/// Provides context that is needed to write the log line.
/// The extra context could be added depending on option
/// configuration and will be determined at runtime.
///
/// This struct is separate to `Record` because it contains
/// runtime fields and thus can't be used at comptime.
pub const Context = struct {
    /// The formatted log message
    message: []const u8,
    datetime: ?[]const u8 = null,

    // This struct currently only contains one field but in the future
    // will likely include datetime/thread ids/etc
    // Starting with a struct means we don't introduce breaking changes when the
    // extra fields get added.

    pub fn initFromOptions(
        message: []const u8,
        comptime opts: *const LogexOptions,
    ) Context {
        var self: Context = .{ .message = message };

        if (comptime opts.show_datetime) |format| {
            const timestamp = std.time.milliTimestamp();
            self.datetime = formatTimestamp(format, timestamp);
        }

        return self;
    }
};

fn formatTimestamp(datetime: DateTimeOptions, millitimestamp: i64) []const u8 {
    return switch (datetime) {
        .iso_8601_utc => "stuff",
        .custom => |func| func(millitimestamp),
    };
}
