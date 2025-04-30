const std = @import("std");
const logex = @import("logex");

pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

const Logger = logex.Logex(.{
    .console = logex.targets.ConsoleTarget(.{ .level = .debug }),
});

pub fn main() !void {
    Logger.init(.{
        .console = .{},
    });

    std.log.debug("hello world!", .{});
}
