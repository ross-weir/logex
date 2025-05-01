const std = @import("std");

fn LoggerOptions(comptime targets: anytype) type {
    const info = @typeInfo(@TypeOf(targets));
    var fields: [info.@"struct".fields.len]std.builtin.Type.StructField = undefined;

    inline for (info.@"struct".fields, 0..) |field, i| {
        const T = @field(targets, field.name);

        fields[i] = .{
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

pub const InitializeError = error{AlreadyInitialized};

pub fn Logex(comptime targets: anytype) type {
    return struct {
        pub const Options = LoggerOptions(targets);
        var options: ?Options = null;

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
            if (options == null) return;

            const opts = @typeInfo(@TypeOf(options.?));

            inline for (opts.@"struct".fields) |field| {
                if (@field(options.?, field.name)) |*target| {
                    // TODO: allow users to provide a error handler?
                    target.log(level, scope, fmt, args) catch {};
                }
            }
        }
    };
}
