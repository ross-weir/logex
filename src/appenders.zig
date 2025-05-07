const std = @import("std");
const Options = @import("root.zig").Options;

/// A generic writer based appender.
/// Writes logs to the provided `Writer` type.
/// Uses a mutex internally to provide thread-safety when performing writes.
pub fn Writer(
    comptime level: std.log.Level,
    comptime opts: Options,
    comptime WriterType: type,
) type {
    return struct {
        const Self = @This();

        writer: WriterType,
        mutex: std.Thread.Mutex = .{},

        pub fn init(writer: WriterType) Self {
            return .{ .writer = writer };
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
            try opts.format.write(self.writer, message_level, scope, format, args, opts);
        }
    };
}

/// Console appender writes logs to stderr.
/// Uses the `std.debug` stderr mutex so Console appender
/// is compitable with std.Progress.
pub fn Console(
    comptime level: std.log.Level,
    comptime opts: Options,
) type {
    return struct {
        const Self = @This();

        pub const init: Self = .{};

        pub fn log(
            _: *Self,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            if (comptime @intFromEnum(message_level) > @intFromEnum(level)) return;

            const stderr = std.io.getStdErr().writer();
            var bw = std.io.bufferedWriter(stderr);
            const writer = bw.writer();

            // we use this lock to be compitable with std.Progress
            // because of this we can't use `Writer` appender as it has its own mutex
            // and the std.Progress mutex isn't pub
            std.debug.lockStdErr();
            defer std.debug.unlockStdErr();
            nosuspend {
                try opts.format.write(writer, message_level, scope, format, args, opts);
                try bw.flush();
            }
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

        inner: Writer(level, opts, std.fs.File.Writer),

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
            return .{ .inner = .init(file.writer()) };
        }

        pub inline fn log(
            self: *Self,
            comptime message_level: std.log.Level,
            comptime scope: @Type(.enum_literal),
            comptime format: []const u8,
            args: anytype,
        ) !void {
            return self.inner.log(message_level, scope, format, args);
        }
    };
}
