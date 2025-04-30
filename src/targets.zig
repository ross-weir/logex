const std = @import("std");
const fmt = @import("format.zig");

pub const ConsoleTargetOptions = struct {
    level: std.log.Level,
    formatFn: fmt.FormatFn = fmt.defaultFormat,
};

pub fn ConsoleTarget(comptime options: ConsoleTargetOptions) type {
    return struct {
        const Self = @This();

        var default: Self = .{};

        pub fn log(
            _: *Self,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            if (comptime @intFromEnum(message_level) > @intFromEnum(options.level)) return;

            const message = options.formatFn(message_level, scope, format, args);
            const stderr = std.io.getStdErr().writer();
            var bw = std.io.bufferedWriter(stderr);
            const writer = bw.writer();

            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            nosuspend {
                writer.writeAll(message) catch return;
                bw.flush() catch return;
            }
        }
    };
}

pub const FileTargetOptions = struct {
    level: std.log.Level,
    formatFn: fmt.FormatFn = fmt.defaultFormat,
};

pub fn FileTarget(comptime options: FileTargetOptions) type {
    return struct {
        const Self = @This();

        file: std.fs.File,
        mutex: std.Thread.Mutex = .{},

        pub fn init(filepath: []const u8) !Self {
            const file = try std.fs.cwd().createFile(
                filepath,
                .{ .read = true, .truncate = false },
            );

            return .{ .file = file };
        }

        pub fn log(
            self: *Self,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) void {
            if (comptime @intFromEnum(message_level) > @intFromEnum(options.level)) return;

            const message = options.formatFn(message_level, scope, format, args);

            self.mutex.lock();
            defer self.mutex.unlock();
            self.file.writer().writeAll(message) catch return;
        }
    };
}
