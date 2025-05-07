const std = @import("std");

fn LoggerOptions(comptime appenders: anytype) type {
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
///         comptime message_level: std.log.Level,
///         comptime scope: @Type(.enum_literal),
///         comptime format: []const u8,
///         args: anytype,
///     ) !void {}
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
/// const Logger = Logex(.{FileAppender(), ConsoleAppender()});
///
/// // ..snip
/// const file_appender = .init("app.log");
/// const console_appender = .init;
///
/// // note the we must use the same order here,
/// // if we provided `console_appender` first this would be incorrect.
/// Logger.init(file_appender, console_appender);
/// ```
pub fn Logex(comptime appenders: anytype) type {
    return struct {
        pub const Options = LoggerOptions(appenders);
        var options: Options = undefined;

        /// Initializes logex in a thread-safe manner.
        ///
        /// - If logex is already initialized this function returns immediately with a `InitializeError`.
        /// - If logex is currently being initialized by a different thread then this function will block
        /// until initialization is complete at which time it will return an `InitializeError` error.
        ///
        /// Options argument is a tuple containing appender instances in the same order that the types
        /// were provided to the `Logex` type constructor.
        pub fn init(opts: Options) InitializeError!void {
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
                options = opts;
                state.store(.initialized, .seq_cst);
            }
        }

        pub fn logFn(
            comptime level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            if (state.load(.seq_cst) != .initialized) return;

            inline for (std.meta.fields(@TypeOf(options))) |field| {
                if (@field(options, field.name)) |*appender| {
                    // TODO: allow users to provide a error handler?
                    appender.log(level, scope, fmt, args) catch {};
                }
            }
        }
    };
}
