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

pub fn LogEx(comptime sink_types: anytype) type {
    return struct {
        const Self = @This();

        const Options = LoggerOptions(sink_types);
        var options: Options = undefined;

        pub fn init(opts: Self.Options) void {
            // make thread-safe
            options = opts;
        }

        pub fn logFn(
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime fmt: []const u8,
            args: anytype,
        ) void {
            // make thread safe

            const opt = @typeInfo(@TypeOf(options));

            inline for (opt.@"struct".fields) |field| {
                var sink_opt = @field(options, field.name);
                if (sink_opt) |*sink| {
                    sink.log(message_level, scope, fmt, args);
                }
            }
        }
    };
}
