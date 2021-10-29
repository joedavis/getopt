const std = @import("std");
const getopt = @import("getopt");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpa.deinit());
    const args = try std.process.argsAlloc(&gpa.allocator);
    defer gpa.allocator.free(args);

    var opts = getopt.OptionParser("abcd:e:fg:h"){ .argv = args[1..] };
    while (opts.next()) |opt| {
        switch (opt) {
            .a => std.debug.print("a flag\n", .{}),
            .d => |arg| std.debug.print("d's arg: {s}\n", .{arg}),
            .unknown => |c| {
                std.debug.print("unknown option: {c}\n", .{c});
                break;
            },
            .missing => |c| {
                std.debug.print("missing parameter: {c}\n", .{c});
                break;
            },
            else => {},
        }
    }

    std.debug.print("rest: \n", .{});
    for (opts.rest()) |arg| {
        std.debug.print("  {s}\n", .{arg});
    }
}
