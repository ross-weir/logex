const std = @import("std");
const fmt = @import("format.zig");

pub const ConsoleTargetOptions = struct {
    level: std.log.Level,
    formatFn: fmt.FormatFn = fmt.defaultFormat,
};

pub fn ConsoleTarget(comptime options: ConsoleTargetOptions) type {
    return struct {
        const Self = @This();

        pub const init: Self = .{};

        pub fn log(
            _: *Self,
            comptime level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            if (comptime @intFromEnum(level) > @intFromEnum(options.level)) return;

            const message = options.formatFn(level, scope, format, args);
            const stderr = std.io.getStdErr().writer();
            var bw = std.io.bufferedWriter(stderr);
            const writer = bw.writer();

            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            nosuspend {
                try writer.writeAll(message);
                try bw.flush();
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
            const flags: std.fs.File.CreateFlags = .{ .truncate = false };
            const file = try if (std.fs.path.isAbsolute(filepath))
                std.fs.createFileAbsolute(filepath, flags)
            else
                std.fs.cwd().createFile(filepath, flags);
            try file.seekTo(try file.getEndPos());

            return .{ .file = file };
        }

        pub fn log(
            self: *Self,
            comptime level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            if (comptime @intFromEnum(level) > @intFromEnum(options.level)) return;

            const message = options.formatFn(level, scope, format, args);

            self.mutex.lock();
            defer self.mutex.unlock();
            try self.file.writer().writeAll(message);
        }
    };
}
