const std = @import("std");
const Filter = @import("./filter.zig").Filter;

const Allocator = std.mem.Allocator;

fn AppenderInstances(comptime appenders: anytype) type {
    const fields = std.meta.fields(@TypeOf(appenders));
    var new_fields: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |field, i| {
        const T = @field(appenders, field.name);

        new_fields[i] = .{
            .name = field.name,
            .type = ?T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = std.meta.alignment(?T),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &new_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = true,
        },
    });
}

/// Configuration options for displaying timestamps in log messages.
pub const TimestampOptions = union(enum) {
    /// Default timestamp format, resembles RFC3339 UTC formatting
    /// but no strict guarantee of conformance.
    ///
    /// A sensible default for displaying timestamps.
    default,
    /// Provide a custom timestamp formatting function.
    custom: *const fn (millitimestamp: i64, buf: []u8) anyerror![]u8,

    pub fn write(self: TimestampOptions, buf: []u8, millitimestamp: i64) ![]u8 {
        return switch (self) {
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

                break :blk try std.fmt.bufPrint(
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
                );
            },
            .custom => |func| try func(millitimestamp, buf),
        };
    }
};

/// Main logex comptime configuration.
pub const LogexOptions = struct {
    /// The size of the buffer used to format log messages.
    buffer_size: usize = 2048,
    /// Configuration for timestamps in log messages.
    ///
    /// If not provided no timestamps will be included
    /// in logs. If it is included the timestamp will
    /// be formatted according to the specified option.
    show_timestamp: ?TimestampOptions = null,
    /// Display thread ids in log messages.
    ///
    /// If not provided no thread ids will be included
    /// otherwise the thread will be displayed according
    /// to the selected option.
    show_thread: ?enum {
        id,
    } = null,
};

/// Main logex runtime configuration.
pub const InitOptions = struct {
    /// A runtime filter that will be applied to log messages.
    ///
    /// This filter operates alongside any comptime filtering configured
    /// via `std.options.log_scope_levels`.
    filter: ?Filter = null,
};

/// Provides context that is needed to write the log line.
/// The extra context could be added depending on option
/// configuration and will be determined at runtime.
pub const Context = struct {
    /// The std.log.Level as a string.
    level: []const u8,
    /// The scope that emitted the log as a string.
    scope: []const u8,
    /// The formatted log message.
    message: []const u8,
    /// If `logex` was configured to show a timestamp
    /// then this field will contain the timestamp formatted
    /// according to the configuration.
    ///
    /// If showing of timestamps  was not configured then this field will be `null`.
    timestamp: ?[]const u8 = null,
    /// If `logex` was configured to show threads
    /// then this field will contain either the thread id
    /// or the thread name (if one exists).
    ///
    /// If displaying threads was not configured then this will be `null`.
    thread: ?[]const u8 = null,
};

const State = enum(u8) {
    uninitialized,
    initializing,
    initialized,
};
var state: std.atomic.Value(State) = .init(.uninitialized);

/// Error that occurs during logex initialization
pub const InitializeError = error{AlreadyInitialized};

/// Creates the Logex logger type.
/// `appenders` should be a tuple of appender types that will be used for logging.
///
/// An appender type is a struct with a method with this signature:
///
/// ```zig
/// const Appender = struct {
///     pub fn log(
///         _: *Appender,
///        context: *const logex.Context,
///     ) !void {}
///
///     pub fn enabled(comptime log_level: std.log.Level) bool {
///         return @intFromEnum(log_level) <= @intFromEnum(level);
///     }
/// };
/// ```
///
/// The order that `appenders` are specified in this tuple matches the order
/// the instances should be provided when calling `init`.
///
/// ## Example
///
/// ```zig
/// // Because the types are provided in order: file, console in this tuple the instances
/// // should also be provided in this order when we call Logger.init()
/// const Logger = Logex(.{}, .{FileAppender(), ConsoleAppender()});
///
/// // ..snip
/// const file_appender = .init("app.log");
/// const console_appender = .init;
///
/// // note the we must use the same order here,
/// // if we provided `console_appender` first this would be incorrect.
/// Logger.init(.{}, .{file_appender, console_appender});
/// ```
pub fn Logex(comptime opts: LogexOptions, comptime appender_types: anytype) type {
    return struct {
        const Self = @This();

        pub const Appenders = AppenderInstances(appender_types);
        var appenders: Appenders = undefined;
        var filter: ?Filter = null;

        /// Initializes logex in a thread-safe manner.
        ///
        /// - If logex is already initialized this function returns immediately with a `InitializeError`.
        /// - If logex is currently being initialized by a different thread then this function will block
        /// until initialization is complete at which time it will return an `InitializeError` error.
        ///
        /// Options argument is a tuple containing appender instances in the same order that the types
        /// were provided to the `Logex` type constructor.
        pub fn init(init_opts: InitOptions, appender_instances: Appenders) InitializeError!void {
            if (state.cmpxchgStrong(.uninitialized, .initializing, .acquire, .acquire)) |current| {
                switch (current) {
                    .initialized => return InitializeError.AlreadyInitialized,
                    .initializing => {
                        while (state.load(.acquire) == .initializing) {
                            std.atomic.spinLoopHint();
                        }
                        return InitializeError.AlreadyInitialized;
                    },
                    .uninitialized => unreachable,
                }
            } else {
                appenders = appender_instances;

                if (init_opts.filter) |f| {
                    filter = f;
                }

                state.store(.initialized, .seq_cst);
            }
        }

        pub fn logFn(
            comptime level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            if (comptime !shouldLog(level)) return;
            if (state.load(.seq_cst) != .initialized) return;
            if (filter) |f| {
                if (!f.enabled(level, @tagName(scope))) return;
            }

            // maybe better to use a thread local var
            // if there's many versions of this func it could add up
            var buf: [opts.buffer_size]u8 = undefined;
            // panic for now, see if we can get away with stack alloc buffer
            var context: Context = .{ .scope = @tagName(scope), .level = comptime level.asText(), .message = std.fmt.bufPrint(&buf, fmt, args) catch @panic("formatted buffer too small") };

            if (comptime opts.show_timestamp) |ts| {
                var timestamp: [64]u8 = undefined;
                context.timestamp = ts.write(&timestamp, std.time.milliTimestamp()) catch return;
            }

            if (comptime opts.show_thread) |id| {
                var thread: [std.Thread.max_name_len]u8 = undefined;
                context.thread = comptime switch (id) {
                    .id => std.fmt.bufPrint(&thread, "{d}", .{std.Thread.getCurrentId()}) catch unreachable,
                };
            }

            inline for (std.meta.fields(@TypeOf(appender_types))) |field| {
                const T = @field(appender_types, field.name);
                if (comptime T.enabled(level)) {
                    if (@field(appenders, field.name)) |*appender| {
                        // TODO: allow users to provide a error handler?
                        appender.log(&context) catch {};
                    }
                }
            }
        }

        fn shouldLog(comptime level: std.log.Level) bool {
            inline for (std.meta.fields(@TypeOf(appender_types))) |field| {
                const T = @field(appender_types, field.name);
                if (T.enabled(level)) return true;
            }
            return false;
        }
    };
}
