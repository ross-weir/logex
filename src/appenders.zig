const std = @import("std");
const root = @import("root.zig");
const format = @import("format.zig");

const Context = root.Context;

/// Configuration options that apply to `Appender`s.
pub const Options = struct {
    /// The format to use when writting log lines.
    format: format.Format = .text,
    buffer_size: usize = 4096,
};

/// Console appender writes logs to stderr.
/// Uses the `std.debug` stderr mutex so Console appender
/// is compitable with std.Progress.
pub fn Console(
    comptime level: std.log.Level,
    comptime opts: Options,
) type {
    return struct {
        const Self = @This();
        var buffer: [opts.buffer_size]u8 = undefined;

        pub const init: Self = .{};

        pub fn log(
            _: *Self,
            context: *const Context,
        ) !void {
            var writer = std.fs.File.stderr().writer(&buffer);
            var stderr = &writer.interface;

            // we use this lock to be compitable with std.Progress
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            nosuspend {
                try opts.format.write(stderr, context);
                try stderr.flush();
            }
        }

        pub fn enabled(comptime log_level: std.log.Level) bool {
            return @intFromEnum(log_level) <= @intFromEnum(level);
        }
    };
}

/// File appender writes logs to file.
/// Uses a mutex internally for thread-safety.
pub fn File(
    comptime level: std.log.Level,
    comptime opts: Options,
) type {
    return struct {
        const Self = @This();
        var buffer: [opts.buffer_size]u8 = undefined;

        file: std.fs.File,
        mutex: std.Thread.Mutex = .{},

        /// Create a File appender that writes to the supplied file path.
        /// The file will be appended to if it already exists.
        pub fn init(filepath: []const u8) !Self {
            const flags: std.fs.File.CreateFlags = .{ .truncate = false };
            const file = try if (std.fs.path.isAbsolute(filepath))
                std.fs.createFileAbsolute(filepath, flags)
            else
                std.fs.cwd().createFile(filepath, flags);

            return .initFromFile(file);
        }

        /// Creates the file appender using the provided File.
        /// The file will be appended to if it already contains content.
        pub fn initFromFile(file: std.fs.File) !Self {
            try file.seekTo(try file.getEndPos());

            return .{ .file = file };
        }

        pub fn log(
            self: *Self,
            context: *const Context,
        ) !void {
            var writer = self.file.writer(&buffer);
            var interface = &writer.interface;

            self.mutex.lock();
            defer self.mutex.unlock();

            try opts.format.write(interface, context);
            try interface.flush();
        }

        pub fn enabled(comptime log_level: std.log.Level) bool {
            return @intFromEnum(log_level) <= @intFromEnum(level);
        }
    };
}
