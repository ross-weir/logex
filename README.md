# Logex

[![CI](https://github.com/ross-weir/logex/actions/workflows/ci.yaml/badge.svg)](https://github.com/ross-weir/logex/actions/workflows/ci.yaml)

`logex` (log extensions) is a minimal, extensible logging library for Zig that enhances `std.log` with additional features while maintaining a simple, drop-in interface.

## Features

- **Drop-in Extension**: Extends `std.log` with extra features - easy to add and remove without changing logging calls throughout your project
- **Extensible Appenders**: Comes with console and file appenders, with the ability to implement custom appenders for any logging destination
- **Customize Formatting**: Multiple format options:
  - Text (compatible with `std.log` default format)
  - JSON
  - Custom (implement your own formatting function)
- **Minimal Impact**: `logex` aims to add minimal overhead by remaining comptime as much as possible like the default `std.log` implementation.

## Install

Add `logex` as a dependency to your zig project like so:

```bash
zig fetch --save git+https://github.com/ross-weir/logex.git
```

And configure it in your `build.zig`:

```zig
// .. snip

const logex = b.dependency("logex", .{
    .target = target,
    .optimize = optimize,
});

const exe_mod = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
    .imports = &.{
        .{
            .name = "logex",
            .module = logex.module("logex"),
        },
    },
});
```

## Quick Start

```zig
const std = @import("std");
const logex = @import("logex");

// Create appender types
// Log to the console at debug and above levels, using default text formatting
const ConsoleAppender = logex.appenders.Console(.debug, .{});
// Log to file at info and above levels, using JSON formatting
const FileAppender = logex.appenders.File(.info, .{
    .format = .json,
});

// Create logger type with both appender types
const Logger = logex.Logex(.{ ConsoleAppender, FileAppender });

// Use in std_options
pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

pub fn main() !void {
    // Initialize appender instances
    const console_appender = ConsoleAppender.init;
    const file_appender = try FileAppender.init("app.log");

    // Initialize logger
    try Logger.init(.{ console_appender, file_appender });

    // Use std.log as usual
    // Debug message will only be displayed on console
    std.log.debug("Debug message", .{});
    // Info message will be logged to file and console
    std.log.info("Info message", .{});
}
```

Removing `logex` is as simple as removing `Logger.logFn` and deleting initialzation.

## Appenders

`logex` comes with two built-in appenders:

- **Console Appender**: Logs to `stderr`, works the same as the default `logFn` from `std.log`
- **File Appender**: Logs to file

### Creating Custom Appenders

You can create custom appenders by implementing the `Appender` interface:

```zig
const logex = @import("logex");

const MyCustomAppender = struct {
    pub fn log(
        self: *@This(),
        comptime record: *const logex.Record,
        context: *const logex.Context,
    ) !void {
        // Implement your logging logic
    }
};
```

See a more complete example [here](example/src/custom_appender.zig).

## Formatting

`logex` supports multiple output formats:

- **Text**: Default format compatible with `std.log`
- **JSON**: Structured logging in JSON format
- **Custom**: Implement your own formatting function

See a complete example using a custom formatter [here](example/src/custom_format.zig).

## Examples

Check out the [example](example/) directory for complete usage examples.
