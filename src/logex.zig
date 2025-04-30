const std = @import("std");

fn LoggerOptions(comptime sinks: anytype) type {
    const info = @typeInfo(@TypeOf(sinks));
    var fields: [info.@"struct".fields.len]std.builtin.Type.StructField = undefined;

    inline for (info.@"struct".fields, 0..) |field, i| {
        const T = @field(sinks, field.name);

        fields[i] = .{
            .name = field.name,
            .type = ?T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(?T),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

const State = enum(u8) {
    uninitialized,
    initializing,
    initialized,
};
var state: std.atomic.Value(State) = .init(.uninitialized);

pub const LogexError = error{AlreadyInitialized};

pub fn Logex(comptime sink_types: anytype) type {
    return struct {
        const Options = LoggerOptions(sink_types);
        var options: ?Options = null;

        pub fn init(opts: Options) LogexError!void {
            if (state.cmpxchgStrong(.uninitialized, .initializing, .acquire, .acquire)) |current| {
                switch (current) {
                    .initialized => return LogexError.AlreadyInitialized,
                    .initializing => {
                        while (state.load(.acquire) == .initializing) {
                            std.atomic.spinLoopHint();
                        }
                        return LogexError.AlreadyInitialized;
                    },
                    .uninitialized => unreachable,
                }
            } else {
                options = opts;
                state.store(.initialized, .seq_cst);
            }
        }

        pub fn logFn(
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            if (options == null) return;

            const opts = @typeInfo(@TypeOf(options.?));

            inline for (opts.@"struct".fields) |field| {
                var sink_opt = @field(options.?, field.name);
                if (sink_opt) |*sink| {
                    sink.log(message_level, scope, fmt, args);
                }
            }
        }
    };
}
