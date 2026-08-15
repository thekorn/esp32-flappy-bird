// Adapted from this Zig custom test runner:
// https://gist.github.com/karlseguin/c6bea5b35e4e8d26af6f81c22cb5d76b

const std = @import("std");
const Io = std.Io;
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const border = "================================================================================";

var current_test: ?[]const u8 = null;

pub fn main(init: std.process.Init) !void {
    var mem: [8192]u8 = undefined;
    var fixed_buffer = std.heap.FixedBufferAllocator.init(&mem);
    const allocator = fixed_buffer.allocator();
    const env = Env.init(init.environ_map);

    std.testing.io_instance = .init(init.gpa, .{
        .argv0 = .init(init.minimal.args),
        .environ = init.minimal.environ,
    });
    defer std.testing.io_instance.deinit();

    const io = std.testing.io;
    var slowest = SlowTracker.init(allocator, io, 5);
    defer slowest.release();

    var pass: usize = 0;
    var fail: usize = 0;
    var skip: usize = 0;
    var leak: usize = 0;

    Printer.fmt("\r\x1b[0K", .{});

    for (builtin.test_functions) |t| {
        if (isSetup(t)) {
            t.func() catch |err| {
                Printer.status(.fail, "\nsetup \"{s}\" failed: {}\n", .{ t.name, err });
                return err;
            };
        }
    }

    for (builtin.test_functions) |t| {
        if (isSetup(t) or isTeardown(t)) continue;

        var status = Status.pass;
        slowest.startTiming(io);

        const is_unnamed_test = isUnnamed(t);
        if (env.filter) |filter| {
            if (!is_unnamed_test and std.mem.indexOf(u8, t.name, filter) == null) continue;
        }

        const friendly_name = blk: {
            var it = std.mem.splitScalar(u8, t.name, '.');
            while (it.next()) |value| {
                if (std.mem.eql(u8, value, "test")) {
                    const rest = it.rest();
                    break :blk if (rest.len > 0) rest else t.name;
                }
            }
            break :blk t.name;
        };

        current_test = friendly_name;
        std.testing.allocator_instance = .init(std.heap.page_allocator, .{});
        const result = t.func();
        current_test = null;

        const ns_taken = slowest.endTiming(io, friendly_name);
        if (std.testing.allocator_instance.deinit() != 0) {
            leak += 1;
            Printer.status(.fail, "\n{s}\n\"{s}\" - Memory Leak\n{s}\n", .{ border, friendly_name, border });
        }

        if (result) |_| {
            pass += 1;
        } else |err| switch (err) {
            error.SkipZigTest => {
                skip += 1;
                status = .skip;
            },
            else => {
                status = .fail;
                fail += 1;
                Printer.status(.fail, "\n{s}\n\"{s}\" - {s}\n{s}\n", .{ border, friendly_name, @errorName(err), border });
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
                if (env.fail_first) break;
            },
        }

        if (env.verbose) {
            const ms = @as(f64, @floatFromInt(ns_taken)) / 1_000_000.0;
            Printer.status(status, "{s} ({d:.2}ms)\n", .{ friendly_name, ms });
        } else {
            Printer.status(status, ".", .{});
        }
    }

    for (builtin.test_functions) |t| {
        if (isTeardown(t)) {
            t.func() catch |err| {
                Printer.status(.fail, "\nteardown \"{s}\" failed: {}\n", .{ t.name, err });
                return err;
            };
        }
    }

    const total_tests = pass + fail;
    const status = if (fail == 0 and leak == 0) Status.pass else Status.fail;
    Printer.status(status, "\n{d} of {d} test{s} passed\n", .{ pass, total_tests, if (total_tests != 1) "s" else "" });
    if (skip > 0) Printer.status(.skip, "{d} test{s} skipped\n", .{ skip, if (skip != 1) "s" else "" });
    if (leak > 0) Printer.status(.fail, "{d} test{s} leaked\n", .{ leak, if (leak != 1) "s" else "" });
    Printer.fmt("\n", .{});
    try slowest.display();
    Printer.fmt("\n", .{});
    std.process.exit(if (fail == 0 and leak == 0) 0 else 1);
}

const Printer = struct {
    fn fmt(comptime format: []const u8, args: anytype) void {
        std.debug.print(format, args);
    }

    fn status(value: Status, comptime format: []const u8, args: anytype) void {
        switch (value) {
            .pass => std.debug.print("\x1b[32m", .{}),
            .fail => std.debug.print("\x1b[31m", .{}),
            .skip => std.debug.print("\x1b[33m", .{}),
        }
        std.debug.print(format ++ "\x1b[0m", args);
    }
};

const Status = enum { pass, fail, skip };

const SlowTracker = struct {
    max: usize,
    slowest: SlowestQueue,
    start: Io.Timestamp,
    allocator: Allocator,

    const SlowestQueue = std.PriorityDequeue(TestInfo, void, compareTiming);
    const TestInfo = struct {
        ns: u64,
        name: []const u8,
    };

    fn init(allocator: Allocator, io: Io, count: u32) SlowTracker {
        var slowest: SlowestQueue = .empty;
        slowest.ensureTotalCapacity(allocator, count) catch @panic("OOM");
        return .{
            .max = count,
            .start = Io.Clock.awake.now(io),
            .slowest = slowest,
            .allocator = allocator,
        };
    }

    fn release(self: *SlowTracker) void {
        self.slowest.deinit(self.allocator);
    }

    fn startTiming(self: *SlowTracker, io: Io) void {
        self.start = Io.Clock.awake.now(io);
    }

    fn endTiming(self: *SlowTracker, io: Io, test_name: []const u8) u64 {
        const timestamp = Io.Clock.awake.now(io);
        const ns: u64 = @intCast(self.start.durationTo(timestamp).toNanoseconds());
        self.start = timestamp;

        if (self.slowest.count() < self.max) {
            self.slowest.push(self.allocator, .{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
            return ns;
        }

        const fastest_of_the_slow = self.slowest.peekMin() orelse unreachable;
        if (fastest_of_the_slow.ns > ns) return ns;

        _ = self.slowest.popMin();
        self.slowest.push(self.allocator, .{ .ns = ns, .name = test_name }) catch @panic("failed to track test timing");
        return ns;
    }

    fn display(self: *SlowTracker) !void {
        var slowest = self.slowest;
        const count = slowest.count();
        Printer.fmt("Slowest {d} test{s}: \n", .{ count, if (count != 1) "s" else "" });
        while (slowest.popMin()) |info| {
            const ms = @as(f64, @floatFromInt(info.ns)) / 1_000_000.0;
            Printer.fmt("  {d:.2}ms\t{s}\n", .{ ms, info.name });
        }
    }

    fn compareTiming(_: void, a: TestInfo, b: TestInfo) std.math.Order {
        return std.math.order(a.ns, b.ns);
    }
};

const Env = struct {
    verbose: bool,
    fail_first: bool,
    filter: ?[]const u8,

    fn init(map: *const std.process.Environ.Map) Env {
        return .{
            .verbose = readEnvBool(map, "TEST_VERBOSE", true),
            .fail_first = readEnvBool(map, "TEST_FAIL_FIRST", false),
            .filter = map.get("TEST_FILTER"),
        };
    }

    fn readEnvBool(map: *const std.process.Environ.Map, key: []const u8, default: bool) bool {
        const value = map.get(key) orelse return default;
        return std.ascii.eqlIgnoreCase(value, "true");
    }
};

pub const panic = std.debug.FullPanic(struct {
    pub fn panicFn(msg: []const u8, first_trace_addr: ?usize) noreturn {
        if (current_test) |test_name| {
            std.debug.print("\x1b[31m{s}\npanic running \"{s}\"\n{s}\x1b[0m\n", .{ border, test_name, border });
        }
        std.debug.defaultPanic(msg, first_trace_addr);
    }
}.panicFn);

fn isUnnamed(t: std.builtin.TestFn) bool {
    const marker = ".test_";
    const index = std.mem.indexOf(u8, t.name, marker) orelse return false;
    _ = std.fmt.parseInt(u32, t.name[index + marker.len ..], 10) catch return false;
    return true;
}

fn isSetup(t: std.builtin.TestFn) bool {
    return std.mem.endsWith(u8, t.name, "tests:beforeAll");
}

fn isTeardown(t: std.builtin.TestFn) bool {
    return std.mem.endsWith(u8, t.name, "tests:afterAll");
}
