const std = @import("std");
const root = @import("root.zig");

const LogexOptions = root.LogexOptions;
const TimestampOptions = root.TimestampOptions;

/// Provides context that is needed to write the log line.
/// The extra context could be added depending on option
/// configuration and will be determined at runtime.
///
/// This struct is separate to `Record` because it contains
/// runtime fields and thus can't be used at comptime.
pub const Context = struct {
    /// The formatted log message
    message: []const u8,
    /// If `logex` was configured to show a timestamp
    /// then this field will contain the timestamp formatted
    /// according to the configuration.
    ///
    /// If showing of timestamps  was not configured then this field will be `null`.
    timestamp: ?[]const u8 = null,

    pub fn initFromOptions(message: []const u8, opts: *const LogexOptions) Context {
        var self: Context = .{ .message = message };

        if (opts.show_timestamp) |format| {
            const timestamp = std.time.milliTimestamp();
            var buf: [128]u8 = undefined;
            self.timestamp = formatTimestamp(format, &buf, timestamp);
        }

        return self;
    }
};

fn formatTimestamp(ts: TimestampOptions, buf: []u8, millitimestamp: i64) []u8 {
    return switch (ts) {
        .default => blk: {
            const seconds = @divFloor(millitimestamp, 1000);
            const remaining_ms = @mod(millitimestamp, 1000);
            const ms_formatted = if (remaining_ms < 0)
                1000 + remaining_ms
            else
                remaining_ms;
            var epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(seconds) };

            const epoch_day = epoch_seconds.getEpochDay();
            const year_day = epoch_day.calculateYearDay();
            const month_day = year_day.calculateMonthDay();

            const day_seconds = epoch_seconds.getDaySeconds();
            const hours = @divTrunc(day_seconds.secs, 60 * 60);
            const minutes = @divTrunc(day_seconds.secs % (60 * 60), 60);
            const secs = day_seconds.secs % 60;

            break :blk std.fmt.bufPrint(
                buf,
                "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}Z",
                .{
                    year_day.year,
                    @intFromEnum(month_day.month),
                    month_day.day_index + 1,
                    hours,
                    minutes,
                    secs,
                    @as(u32, @intCast(ms_formatted)),
                },
            ) catch unreachable;
        },
        .custom => |func| func(millitimestamp, buf),
    };
}
