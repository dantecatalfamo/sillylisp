const std = @import("std");
const debug = std.debug;
const fs = std.fs;
const mem = std.mem;
const os = std.os;
const testing = std.testing;

const environment = @import("environment.zig");
const Environment = environment.Environment;
const Lambda = environment.Lambda;
const Value = environment.Value;
const eval = environment.eval;
const ValueList = environment.ValueList;

pub fn def(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .identifier, null });

    try env.put(args[0].identifier, args[1]);
    return args[1];
}

pub fn plus(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgsType(args, .integer);

    var acc: i64 = 0;
    for (args) |arg| {
        acc += arg.integer;
    }
    return Value{ .integer = acc };
}

test plus {
    try expectEval(testing.allocator, "(+)", Value{ .integer = 0 });
    try expectEval(testing.allocator, "(+ 5)", Value{ .integer = 5 });
    try expectEval(testing.allocator, "(+ 1 2)", Value{ .integer = 3 });
    try expectEval(testing.allocator, "(+ 1 2 3 4)", Value{ .integer = 10 });
}

pub fn minus(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgsType(args, .integer);
    if (args.len == 0) return Value{ .integer = -0 };
    if (args.len == 1) return Value{ .integer = -args[0].integer };

    var acc = args[0].integer;
    for (args[1..]) |arg| {
        acc -= arg.integer;
    }
    return Value{ .integer = acc };
}

test minus {
    try expectEval(testing.allocator, "(-)", Value{ .integer = 0 });
    try expectEval(testing.allocator, "(- 5)", Value{ .integer = -5 });
    try expectEval(testing.allocator, "(- 1 2)", Value{ .integer = -1 });
    try expectEval(testing.allocator, "(- 2 1)", Value{ .integer = 1 });
    try expectEval(testing.allocator, "(- 1 2 3 4)", Value{ .integer = -8 });
}

pub fn mul(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgsType(args, .integer);
    if (args.len == 0) {
        return Value{ .integer = 0 };
    }

    var acc = args[0].integer;
    for (args[1..]) |arg| {
        acc *= arg.integer;
    }
    return Value{ .integer = acc };
}

test mul {
    try expectEval(testing.allocator, "(*)", Value{ .integer = 0 });
    try expectEval(testing.allocator, "(* 5)", Value{ .integer = 5 });
    try expectEval(testing.allocator, "(* 2 3)", Value{ .integer = 6 });
    try expectEval(testing.allocator, "(* 2 3 4)", Value{ .integer = 24 });
}

pub fn divide(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgsType(args, .integer);
    if (args.len == 0) {
        return Value{ .integer = 0 };
    }

    var acc = args[0].integer;
    for (args[1..]) |arg| {
        if (arg.integer == 0) {
            return error.DivisionByZero;
        }
        acc = @divFloor(acc, arg.integer);
    }

    return Value{ .integer = acc };
}

pub fn pow(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .integer, .integer });

    var acc: i64 = args[0].integer;
    for (args[1..]) |arg| {
        acc = std.math.pow(i64, acc, arg.integer);
    }
    return Value{ .integer = acc };
}

pub fn shl(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .integer, .integer });

    if (args[1].integer > std.math.maxInt(u6)) {
        return error.Overflow;
    }
    const out = args[0].integer << @intCast(args[1].integer);
    return Value{ .integer = out };
}

pub fn shr(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .integer, .integer });

    if (args[1].integer > std.math.maxInt(u6)) {
        return error.Overflow;
    }
    const out = args[0].integer >> @intCast(args[1].integer);
    return Value{ .integer = out };
}



pub fn inc(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .identifier });

    var stored = env.get(args[0].identifier) orelse return error.NoBindings;
    if (stored != .integer) {
        return error.ArgType;
    }
    var new_val = Value{ .integer = stored.integer + 1 };
    try env.put(args[0].identifier, new_val);
    return new_val;
}

pub fn dec(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .identifier });

    var stored = env.get(args[0].identifier) orelse return error.NoBindings;
    if (stored != .integer) {
        return error.ArgType;
    }
    var new_val = Value{ .integer = stored.integer - 1 };
    try env.put(args[0].identifier, new_val);
    return new_val;
}

pub fn concat(env: *Environment, args: []const Value) !Value {
    var strings = std.ArrayList([]const u8).init(env.allocator());
    errdefer strings.deinit();

    for (args) |arg| {
        if (arg == .integer) {
            const int_str = try std.fmt.allocPrint(env.allocator(), "{d}", .{ arg.integer });
            try strings.append(int_str);
            continue;
        }
        if (arg != .string) {
            return error.ArgType;
        }
        try strings.append(arg.string);
    }
    const new_str = try mem.concat(env.allocator(), u8, strings.items);
    return Value{ .string = new_str };
}

pub fn eq(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ null, null });

    const arg1 = args[0];
    for (args[1..]) |arg| {
        if (!eqInternal(arg1, arg)) {
            return nil;
        }
    }
    return t;
}

pub fn progn(env: *Environment, args: []const Value) !Value {
    for (args, 0..) |arg, idx| {
        const val = eval(env, arg);
        if (idx == args.len-1) {
            return val;
        }
    }
    return Value.nil;
}

pub fn eqInternal(lhs: Value, rhs: Value) bool {
    if (!mem.eql(u8, @tagName(lhs), @tagName(rhs))) {
        return false;
    }
    switch(lhs) {
        .nil => return true,
        .integer => return lhs.integer == rhs.integer,
        .function => return lhs.function.impl == rhs.function.impl,
        .string => return mem.eql(u8, lhs.string, rhs.string),
        .identifier => return mem.eql(u8, lhs.identifier, rhs.identifier),
        .symbol => return mem.eql(u8, lhs.symbol, rhs.symbol),
        .list => {
            if (rhs.list.len != rhs.list.len) {
                return false;
            }
            for (0..lhs.list.len) |idx| {
                if (!eqInternal(lhs.list[idx], rhs.list[idx])) {
                    return false;
                }
            }
            return true;
        },
        .lambda => {
            if (rhs.lambda.body.len != rhs.lambda.body.len) {
                return false;
            }
            for (rhs.lambda.body, lhs.lambda.body) |rhb, lhb| {
                if (!eqInternal(rhb, lhb)) {
                    return false;
                }
            }
            // for (0..lhs.lambda.len) |idx| {
            //     if (!eqInternal(lhs.lambda[idx], rhs.lambda[idx])) {
            //         return false;
            //     }
            // }
            return true;
        },
    }
}

pub const t = Value{ .identifier = "t" };
pub const nil = Value.nil;

pub fn list(env: *Environment, args: []const Value) !Value {
    _ = env;
    return Value{ .list = args };
}

pub fn quote(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ null });

    return args[0];
}

pub fn eval_fn(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ null });

    return eval(env, args[0]);
}

pub fn lambda(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgsVar(args, &.{ .list }, 2);

    for (args[0].list) |arg| {
        if (arg != .identifier) {
            return error.ArgType;
        }
    }
    return Value{ .lambda = Lambda{ .args = args[0].list, .body = args[1..] }};
}

pub fn if_fn (env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ null, null, null });

    const condition = args[0];
    const if_true = args[1];
    const if_false = args[2];

    if (try eval(env, condition) != Value.nil) {
        return try eval(env, if_true);
    }
    return try eval(env, if_false);
}

pub fn println(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ null });

    const writer = std.io.getStdIn().writer();
    if (args.len == 1) {
        try args[0].toString(writer);
    }
    try writer.print("\n", .{});
    return nil;
}

pub fn trace(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ null });
    if (args[0] == .nil) {
        env.trace = false;
        return nil;
    }

    env.trace = true;
    env.trace_depth += 1;
    return t;
}

pub fn typeOf(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ null });

    const ident = @tagName(args[0]);
    return Value{ .identifier = ident };
}

pub fn map(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ null, .list });
    if (!args[0].functionIsh()) {
        return error.ArgType;
    }

    var output = ValueList{};

    for (args[1].list) |item| {
        const func = Value{ .list = &.{ args[0], item }};
        const result = try eval(env, func);
        try output.append(env.allocator(), result);
    }

    return Value{ .list = try output.toOwnedSlice(env.allocator()) };
}

pub fn each(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ null, .list });
    if (!args[0].functionIsh()) {
        return error.ArgType;
    }

    for (args[1].list) |item| {
        const func = Value{ .list = &.{ args[0], item }};
        _ = try eval(env, func);
    }

    return t;
}

pub fn plistGet(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .symbol, .list });

    if (try plistValue(args[1].list, args[0].symbol)) |val| {
        return val;
    }
    return nil;
}

pub fn plistValue(plist: []const Value, key: []const u8) !?Value {
    var iter = try plistIter(plist);
    while (try iter.next()) |pair| {
        if (mem.eql(u8, key, pair.symbol)) {
            return pair.value;
        }
    }
    return null;
}

pub fn plistIter(args: []const Value) !PlistIter {
    if (args.len % 2 != 0) {
        return error.NumArgs;
    }
    return .{
        .args = args,
        .index = 0,
    };
}

pub const PlistIter = struct {
    args: []const Value,
    index: usize,

    pub fn next(self: *PlistIter) !?Pair {
        if (self.index == self.args.len) {
            return null;
        }
        const symbol = self.args[self.index];
        if (symbol != .symbol) {
            return error.ArgType;
        }
        const value = self.args[self.index+1];
        self.index += 2;
        return Pair{
            .symbol = symbol.symbol,
            .value = value,
        };
    }

    pub fn reset(self: *PlistIter) void {
        self.index = 0;
    }
};

pub const Pair = struct {
    symbol: []const u8,
    value: Value,
};

pub fn nth(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .integer, .list });

    if (args[0].integer > args[1].list.len or args[0].integer < 0) {
        return error.OutOfRange;
    }
    return args[1].list[@intCast(args[0].integer)];
}

pub fn arenaCapacity(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{});

    return Value{ .integer = @intCast(env.arena.queryCapacity()) };
}

pub fn first(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .list });

    return args[0].list[0];
}

pub fn rest(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .list });

    if (args[0].list.len == 0) {
        return Value{ .list = &.{} };
    }
    return Value{ .list = args[0].list[1..] };
}

pub fn apply(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ null, .list });
    if (!args[0].functionIsh()) {
        return error.ArgType;
    }

    var expr = ValueList{};
    try expr.append(env.allocator(), args[0]);
    for (args[1].list) |item| {
        try expr.append(env.allocator(), item);
    }
    return try eval(env, Value{ .list = try expr.toOwnedSlice(env.allocator()) });
}

pub fn times(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .integer, null });
    if (!args[1].functionIsh()) {
        return error.ArgType;
    }

    for (0..@intCast(args[0].integer)) |idx| {
        const expr = [_]Value{ args[1], Value{ .integer = @intCast(idx) } };
        _ = try eval(env, Value{ .list = &expr });
    }
    return Value.nil;
}

pub fn length(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .list });

    return Value{ .integer = @intCast(args[0].list.len) };
}

pub fn append(env: *Environment, args: []const Value) !Value {
    try checkArgsVar(args, &.{ .list }, 2);

    var new_list = try ValueList.initCapacity(env.allocator(), args[0].list.len + args[1..].len);
    new_list.appendSliceAssumeCapacity(args[0].list);
    new_list.appendSliceAssumeCapacity(args[1..]);
    return Value{ .list = try new_list.toOwnedSlice(env.allocator()) };
}

pub fn memUsage(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{});

    return Value{ .integer = @intCast(env.counting.count) };
}

pub fn loadFile(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .string });

    const allocator = env.arena.child_allocator;
    const file_contents = try fs.cwd().readFileAlloc(allocator, args[0].string, 12 * 1024 * 1024);
    defer allocator.free(file_contents);
    return try env.load(file_contents);
}

pub fn loadString(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .string });

    return try env.load(args[0].string);
}


pub fn logAllocs(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ null });

    if (args[0] == .nil) {
        env.counting.log = false;
        return nil;
    }
    env.counting.log = true;
    return t;
}

pub fn write(env: *Environment, args: []const Value) !Value {
    _ = env;
    try checkArgs(args, &.{ .string, .string });

    try fs.cwd().writeFile(args[0].string, args[1].string);
    return t;
}

pub fn read(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .string });

    const contents = try fs.cwd().readFileAlloc(env.allocator(), args[0].string, 12 * 1024 * 1024);
    return Value{ .string = contents };
}

pub fn join(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .string, .list });
    try checkArgsType(args[1].list, .string);

    const strings = try env.arena.child_allocator.alloc([]const u8, args[1].list.len);
    defer env.arena.child_allocator.free(strings);

    for (args[1].list, 0..) |val, idx| {
        strings[idx] = val.string;
    }

    return Value{ .string = try mem.join(env.allocator(), args[0].string, strings) };
}

pub fn cwd(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{});

    const path = try std.process.getCwdAlloc(env.allocator());
    return Value{ .string = path };
}

pub fn last(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .list });
    _ = env;
    return args[0].list[args[0].list.len-1];
}

pub fn chars(env: *Environment, args: []const Value) !Value {
    try checkArgs(args, &.{ .string });

    var char = try ValueList.initCapacity(env.allocator(), args[0].string.len);
    for (0..args[0].string.len) |idx| {
        const slice = args[0].string[idx..idx+1];
        char.appendAssumeCapacity(Value{ .string = slice });
    }
    return Value{ .list = try char.toOwnedSlice(env.allocator()) };
}

/// Same as checkArgs, except it allows more arguments than there are
/// in `types`, and doesn't check them.
/// Checks that there are at least `min_args` arguments.
pub fn checkArgsVar(args: []const Value, types: []const ?ArgType, min_args: usize) !void {
    if (args.len < min_args) {
        return error.NumArgs;
    }
    try checkArgs(args[0..types.len], types);
}

/// Check that all args are one type.
pub fn checkArgsType(args: []const Value, arg_type: ArgType) !void {
    for (args) |arg| {
        if (arg != arg_type) {
            return error.ArgType;
        }
    }
}

/// Check the number and type of arguments.
/// args is the arguments argument passed to the calling function
/// types if a list of desired types.
///
/// For example `try checkArgs(args, &.{ .string });`
/// means we would like to check if the function was called with a
/// single string argument
/// The types are optional, meaning if you don't care about the type
/// of one of the arguments, pass `null` in that position.
pub fn checkArgs(args: []const Value, types: []const ?ArgType) !void {
    if (args.len != types.len) {
        return error.NumArgs;
    }
    for (args, types) |arg, typ| {
        if (typ == null) {
            continue;
        }
        if (arg != typ.?) {
            return error.ArgType;
        }
    }
}

pub const ArgType = @typeInfo(Value).Union.tag_type.?;

pub fn expectEval(allocator: mem.Allocator, input: []const u8, expected: Value) !void {
    var env = try Environment.init(allocator);
    defer env.deinit();
    const output = try env.load(input);
    if (!eqInternal(output, expected)) {
        return error.NotEqual;
    }
}
