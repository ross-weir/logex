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

pub const InitializeError = error{AlreadyInitialized};

pub fn Logex(comptime appenders: anytype) type {
    return struct {
        pub const Options = LoggerOptions(appenders);
        var options: Options = undefined;

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
