# Logex

[![CI](https://github.com/ross-weir/logex/actions/workflows/ci.yaml/badge.svg)](https://github.com/ross-weir/logex/actions/workflows/ci.yaml)

`logex` (log extensions) is a minimal, extensible logging library for Zig that enhances `std.log` with additional features while maintaining a simple, drop-in interface.

## Table of Contents

- [Features](#features)
- [Install](#install)
- [Quick Start](#quick-start)
- [Appenders](#appenders)
  - [Creating Custom Appenders](#creating-custom-appenders)
- [Formatting](#formatting)
- [Runtime Filtering](#runtime-filtering)
  - [Environment Variable Configuration](#environment-variable-configuration)
- [Examples](#examples)

## Features

- **Drop-in Extension**: Extends `std.log` with extra features - easy to add and remove without changing logging calls throughout your project
- **Extensible Appenders**: Comes with console and file appenders, with the ability to implement custom appenders for any logging destination
- **ANSI Styling**: Optional ANSI color formatting for console output with palette customization and automatic TTY detection
- **Customize Formatting**: Multiple format options:
  - Text (compatible with `std.log` default format)
  - JSON
  - Custom (implement your own formatting function)
- **Runtime filtering**: Extends scope/log level filtering with runtime options, this allows for environment variable based filtering similar to [`env_logger`](https://github.com/rust-cli/env_logger) from the Rust logging ecosystem
- **Minimal Impact**: `logex` aims to add minimal overhead by remaining comptime as much as possible like the default `std.log` implementation

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
// Log to the console at debug and above levels, emitting ANSI colors when supported
const ConsoleAppender = logex.appenders.Console(.debug, .{
    .format = .{ .styled_text = .{} },
});
// Log to file at info and above levels, using JSON formatting
const FileAppender = logex.appenders.File(.info, .{
    .format = .json,
});

// Create logger type with both appender types
const Logger = logex.Logex(.{}, .{ ConsoleAppender, FileAppender });

// Use in std_options
pub const std_options: std.Options = .{
    .logFn = Logger.logFn,
};

pub fn main() !void {
    // Initialize appender instances
    const console_appender = ConsoleAppender.init;
    const file_appender = try FileAppender.init("app.log");

    // Initialize logger
    try Logger.init(.{}, .{ console_appender, file_appender });

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

- **Writer Appender**: A generic threadsafe appender that writes to an underlying `AnyWriter`
- **Console Appender**: Logs to `stderr`, works the same as the default `logFn` from `std.log`
- **File Appender**: Logs to file

### Creating Custom Appenders

You can create custom appenders by implementing the `Appender` interface:

```zig
const logex = @import("logex");

const MyCustomAppender = struct {
    pub fn log(
        self: *@This(),
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
- **Styled Text**: ANSI colored text output with configurable palettes and detection modes
- **JSON**: Structured logging in JSON format
- **Custom**: Implement your own formatting function

#### Styled Text Formatting

Styled text formatting mirrors the Zerolog style shown above and can be enabled per appender. Colors are only emitted when the optional `supports_color_fn` reports that the writer supports ANSI sequences (the console appender wires this automatically to stderr's TTY detection).

```zig
const ConsoleAppender = logex.appenders.Console(.info, .{
    .format = .{ .styled_text = .{
        .color_mode = .auto, // default: enable colors when stderr is a TTY
        .palette = .{
            .scope = logex.format.ansi.cyan,
        },
    } },
});
```

To force colors on or off regardless of terminal detection, set `color_mode` to `.force_on` or `.force_off`. Custom palettes let you override any of the timestamp, level, scope, thread, or message colors, or even replace them with empty strings to suppress styling entirely.

> **Windows terminals:** Virtual Terminal Processing must be enabled (Windows 10+ terminals do this automatically). When the console does not advertise ANSI support, the auto mode will disable colors.

See a complete example using a custom formatter [here](example/src/custom_format.zig).

## Runtime Filtering

`logex` provides filtering at runtime that works alongside comptime filtering (`std.options.log_scope_levels` / `std.options.log_level`).

An environment variable based filter is provided out of the box with capabilities similar to the Rust ecosystem's `env_logger`. This allows you to configure log levels for different scopes at runtime through environment variables, without recompiling your application.

### Environment Variable Configuration

By default, `logex` uses the `ZIG_LOG` environment variable for configuration. The format is:

```
scope1=level1,scope2=level2,level3
```

Where:

- `scope` is the logging scope (e.g., "my_module")
- `level` is one of: debug, info, warn, err
- A level without a scope sets the default level

Examples:

```bash
# Set default level to info
export ZIG_LOG=info

# Set specific scopes
export ZIG_LOG=my_module=debug,other_module=warn

# Mix of scoped and default levels
export ZIG_LOG=info,my_module=debug,other_module=warn
```

See a complete example of runtime filtering [here](example/src/filter.zig).

## Examples

Check out the [example](example/) directory for complete usage examples.
