const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const demo = b.addExecutable("demo", "examples/demo.zig");
    demo.addPackagePath("getopt", "src/getopt.zig");
    demo.setBuildMode(mode);
    demo.install();

    var main_tests = b.addTest("src/getopt.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&main_tests.step);

    const all_step = b.step("all", "Build demo and run all tests");
    all_step.dependOn(test_step);
    all_step.dependOn(&demo.step);
}
