# getopt

This is a type-safe getopt-style options parsing library for zig. Type-safe, in this context, means that it can distinguish between options that take arguments, and options that don't. It's built on ugly metaprogramming constructs, and has a tendency to crash zls. This was written as a proof of concept while I tried to explore what was possible with Zig's comptime facilities. You probably shouldn't use this; I know I won't.

## Example usage

    const getopt = @import("getopt");

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

## License

    Copyright (c) 2021 Joe Davis <me@jo.ie>

    Permission to use, copy, modify, and distribute this software for any
    purpose with or without fee is hereby granted, provided that the above
    copyright notice and this permission notice appear in all copies.

    THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
    WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
    MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
    ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
    WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
    ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
    OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
