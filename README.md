# sillylisp

A sort-of-a-lisp extracted from a previous project.

Originally intended to be used as a configuration language.
Designed to be easy to grok and fast.
It doesn't have a garbage collector but instead frees everything when the environment is destroyed.
Uses lists instead of cons cells internally.

Supported lambdas, special forms, recursion, debugging, tracing, defining functions and variables, etc.

## Building
```zig
zig build
```

## Running
```zig
zig build run
```

This will open an interactive REPL.

## Usage

```zig
const std = @import("std");
const environment = @import("environment.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .enable_memory_limit = true }){};
    var allocator = gpa.allocator();
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var env = try environment.Environment.init(allocator);
    defer env.deinit();

    var expression = "(+ 1 2 3)"
    const result = try env.load(expression);
    try result.toString(stdout);
    try stdout.print("\n", .{});
}
```
