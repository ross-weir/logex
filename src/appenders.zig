const std = @import("std");

pub fn Console(comptime level: std.log.Level, comptime Formatter: type) type {
    return struct {
        const Self = @This();

        formatter: Formatter,

        pub fn init(formatter: Formatter) Self {
            return .{ .formatter = formatter };
        }

        pub fn log(
            self: *Self,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            if (comptime @intFromEnum(message_level) > @intFromEnum(level)) return;

            const stderr = std.io.getStdErr().writer();
            var bw = std.io.bufferedWriter(stderr);
            const writer = bw.writer();

            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            nosuspend {
                try self.formatter.format(writer, message_level, scope, format, args);
                try bw.flush();
            }
        }
    };
}

pub fn File(comptime level: std.log.Level, comptime Formatter: type) type {
    return struct {
        const Self = @This();

        formatter: Formatter,
        file: std.fs.File,
        mutex: std.Thread.Mutex = .{},

        pub fn init(formatter: Formatter, filepath: []const u8) !Self {
            const flags: std.fs.File.CreateFlags = .{ .truncate = false };
            const file = try if (std.fs.path.isAbsolute(filepath))
                std.fs.createFileAbsolute(filepath, flags)
            else
                std.fs.cwd().createFile(filepath, flags);
            try file.seekTo(try file.getEndPos());

            return .{ .formatter = formatter, .file = file };
        }

        pub fn log(
            self: *Self,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            if (comptime @intFromEnum(message_level) > @intFromEnum(level)) return;

            self.mutex.lock();
            defer self.mutex.unlock();
            try self.formatter.format(self.file.writer(), message_level, scope, format, args);
        }
    };
}
