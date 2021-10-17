const std = @import("std");
const testing = std.testing;
const expect = testing.expect;

fn FlagType(comptime optstring: []const u8) type {
    return struct {
        pub fn has_arg(opt: u8) bool {
            for (optstring) |cur, i| {
                if (opt != cur) continue;

                if (i + 1 < optstring.len and optstring[i + 1] == ':') {
                    return true;
                } else {
                    return false;
                }
            }
            return false;
        }

        pub fn get(comptime opt: u8) type {
            if (opt == ':') @compileError(": cannot be a parameter");
            return if (@This().has_arg(opt)) ?[:0]const u8 else void;
        }
    };
}

fn ParsedOption(comptime optstring: []const u8) type {
    const T = FlagType(optstring);
    const n_fields = optstring.len - std.mem.count(u8, optstring, ":");

    // There's (quite) a few bits below that I'm not particularly happy with. 
    // My main problem is the fact that returning slices of arrays defined in
    // inner blocks. This seems ok, because it's comptime. I'm not 100% though
    // But it does appear to work. 

    const TagType = blk: {
        var fields: [n_fields + 2]std.builtin.TypeInfo.EnumField = undefined;
        var skip = 0;
        for (optstring) |_, i| {
            if (optstring[i] == ':') {
                skip += 1;
                continue;
            }
            fields[i - skip] = std.builtin.TypeInfo.EnumField{
                .name = optstring[i .. i + 1],
                .value = i - skip,
            };
        }
        fields[n_fields] = std.builtin.TypeInfo.EnumField{
            .name = "unknown",
            .value = n_fields,
        };
        fields[n_fields + 1] = std.builtin.TypeInfo.EnumField{
            .name = "missing",
            .value = n_fields + 1,
        };

        const decls = blk2: {
            var decls: [0]std.builtin.TypeInfo.Declaration = .{};
            break :blk2 decls[0..];
        };

        const ti: std.builtin.TypeInfo = .{
            .Enum = .{
                .layout = .Auto,
                // we're using single char args, so u8 is sufficient
                .tag_type = u8,
                .fields = fields[0..],
                .is_exhaustive = true,
                .decls = decls,
            },
        };
        break :blk @Type(ti);
    };

    const fields = blk: {
        var fields: [n_fields + 2]std.builtin.TypeInfo.UnionField = undefined;
        var skip = 0;
        for (optstring) |_, i| {
            if (optstring[i] == ':') {
                skip += 1;
                continue;
            }
            fields[i - skip] = std.builtin.TypeInfo.UnionField{
                .name = optstring[i .. i + 1],
                .field_type = T.get(optstring[i]),
                //.default_value = if (T.get(optstring[i]) == void) undefined else null,
                .alignment = if (T.get(optstring[i]) == void) 0 else @alignOf(T.get(optstring[i])),
            };
        }

        fields[n_fields] = std.builtin.TypeInfo.UnionField{
            .name = "unknown",
            .field_type = u8,
            .alignment = @alignOf([][:0]const u8),
        };
        fields[n_fields + 1] = std.builtin.TypeInfo.UnionField{
            .name = "missing",
            .field_type = u8,
            .alignment = @alignOf([][:0]const u8),
        };

        break :blk fields[0..];
    };

    const decls = blk: {
        var decls: [0]std.builtin.TypeInfo.Declaration = .{};
        break :blk decls[0..];
    };

    const ti = std.builtin.TypeInfo{
        .Union = std.builtin.TypeInfo.Union{
            .layout = .Auto,
            .fields = fields,
            .decls = decls,
            .tag_type = TagType,
        },
    };

    return @Type(ti);
}

pub fn OptionParser(comptime optstring: []const u8) type {
    return struct {
        const Self = @This();

        argv: [][:0]const u8,

        /// index into the argv array
        opt_index: usize = 0,
        /// index into the individual argument
        char_offset: usize = 1,

        const OptType = ParsedOption(optstring);

        pub fn next(self: *Self) ?OptType {
            // There's definitely some off-by-one errors lurking below that I
            // haven't managed to eliminate.

            while (self.opt_index < self.argv.len) : (self.opt_index += 1) {
                const arg = self.argv[self.opt_index];
                if (std.mem.eql(u8, arg, "--")) {
                    self.opt_index += 1;
                    return null;
                }
                if (arg.len == 0) return null;
                if (arg[0] != '-') return null;
                if (arg.len == 1) return null;

                inline for (optstring) |opt| {
                    const opts = [_]u8{opt};
                    if (opt != ':') {
                        if (opt == arg[self.char_offset]) {
                            if (FlagType(optstring).get(opt) == void) {
                                self.char_offset += 1;
                                if (self.char_offset == arg.len) {
                                    self.char_offset = 1;
                                    self.opt_index += 1;
                                }

                                return @unionInit(OptType, opts[0..], undefined);
                            } else {
                                if (self.char_offset + 1 < arg.len) {
                                    const off = self.char_offset;
                                    self.char_offset = 1;
                                    self.opt_index += 1;
                                    return @unionInit(OptType, opts[0..], arg[off + 1 ..]);
                                } else {
                                    self.opt_index += 2;
                                    if (self.opt_index - 1 >= self.argv.len) {
                                        self.opt_index = self.argv.len;
                                        return OptType{ .missing = opt };
                                    } else {
                                        self.char_offset = 1;
                                        return @unionInit(OptType, opts[0..], self.argv[self.opt_index - 1]);
                                    }
                                }
                            }
                        }
                    }
                }
                return ParsedOption(optstring){
                    .unknown = arg[self.char_offset],
                };
            }
            return null;
        }

        pub fn rest(self: Self) [][:0]const u8 {
            return self.argv[self.opt_index..];
        }
    };
}

test "parse options" {
    var args = [_][:0]const u8{
        "-a",
        "-bc",
        "-delf",
        "-e",
        "dwarf",
        "-g",
        "-h",
        "x",
        "y",
        "z",
    };
    const Flags = struct {
        a_flag: bool = false,
        b_flag: bool = false,
        c_flag: bool = false,
        d_flag: ?[]const u8 = null,
        e_flag: ?[]const u8 = null,
        f_flag: bool = false,
    };
    var flags: Flags = .{};

    var opts = OptionParser("abcd:e:fg:h"){ .argv = args[0..] };
    while (opts.next()) |opt| {
        switch (opt) {
            .a => flags.a_flag = true,
            .b => flags.b_flag = true,
            .c => flags.c_flag = true,
            .d => |d_opt| flags.d_flag = d_opt,
            .e => |e_opt| flags.e_flag = e_opt,
            .f => flags.f_flag = true,
            //else => break,
        }
    }

    try expect(flags.a_flag == true);
    try expect(flags.b_flag == true);
    try expect(flags.c_flag == true);

    const d_opt = flags.d_flag;
    try expect(d_opt != null);
    try expect(std.mem.eql(u8, d_opt.?, "elf"));

    const e_opt = flags.e_flag;
    try expect(e_opt != null);
    try expect(std.mem.eql(u8, e_opt.?, "dwarf"));

    try expect(flags.f_flag == false);

    try expect(opts.rest().len == 3);
}

test "missing parameter" {
    var args = [_][:0]const u8{
        "-ab", "-e",
    };
    var opts = OptionParser("abcd:e:fg:h"){ .argv = args[0..] };
    var found_missing = false;
    while (opts.next()) |opt| {
        switch (opt) {
            .missing => |c| { 
                try expect(c == 'e');
                found_missing = true;
            },
            .unknown => unreachable,
            else => continue,
        }
    }
    try expect(found_missing);
}

test "arg list cut short" {
    var args = [_][:0]const u8{
        "-ab", "--", "-e",
    };
    var opts = OptionParser("abcd:e:fg:h"){ .argv = args[0..] };
    while (opts.next()) |opt| {
        switch (opt) {
            .missing => unreachable,
            .unknown => unreachable,
            else => continue,
        }
    }
    try expect(opts.rest().len == 1);
}
