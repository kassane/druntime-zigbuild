//! Based on: https://github.com/denizzzka/ldc-external_druntime_backend/blob/external_druntime_backend_support/runtime/druntime/meson.build

const std = @import("std");
const ldc2 = @import("abs").ldc2;
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    // ldc2/ldmd2 not have mingw-support
    const target = b.standardTargetOptions(.{
        .default_target = if (builtin.os.tag == .windows)
            try std.Target.Query.parse(.{
                .arch_os_abi = "native-windows-msvc",
            })
        else
            .{},
    });
    const optimize = b.standardOptimizeOption(.{});

    // Send the triple-target to zigcc (if enabled)
    const zigcc_options = b.addOptions();
    if (target.query.isNative()) {
        zigcc_options.addOption([]const u8, "triple", b.fmt("native-native-{s}", .{@tagName(target.result.abi)}));
    } else {
        zigcc_options.addOption([]const u8, "triple", try target.result.linuxTriple(b.allocator));
    }

    const source = switch (target.result.cpu.arch) {
        .aarch64, .arm, .aarch64_32, .aarch64_be, .armeb => &[_][]const u8{
            "druntime/src/ldc/arm_unwind.c",
        } ++ src,
        else => src,
    };

    const threadAsm = b.addStaticLibrary(.{
        .name = "threadasm",
        .target = target,
        .optimize = optimize,
    });
    threadAsm.addAssemblyFile(b.path("druntime/src/core/threadasm.S"));

    const versions_config = switch (target.result.cpu.arch) {
        .aarch64, .x86_64, .x86 => &[_][]const u8{
            "AsmExternal", // used by fiber module
            "OnlyLowMemUnittest", // disables memory-greedy unittests
        },
        else => &[_][]const u8{
            "OnlyLowMemUnittest", // disables memory-greedy unittests
        },
    };

    try buildD(b, .{
        .name = "druntime",
        .kind = .lib,
        .target = target,
        .optimize = optimize,
        .sources = source,
        .dflags = &.{
            "-Idruntime/src",
            "-w",
            "-conf=",
            "-defaultlib=",
        },
        .versions = versions_config,
        .artifact = threadAsm,
        .use_zigcc = true,
        .t_options = zigcc_options,
    });
}

fn buildD(b: *std.Build, options: ldc2.DCompileStep) !void {
    const exe = try ldc2.BuildStep(b, options);
    b.default_step.dependOn(&exe.step);
}

const src = &[_][]const u8{
    "druntime/src/core/bitop.d",
    "druntime/src/core/cpuid.d",
    "druntime/src/core/gc/config.d",
    "druntime/src/core/gc/gcinterface.d",
    "druntime/src/core/gc/registry.d",
    "druntime/src/core/demangle.d",
    "druntime/src/core/exception.d",
    "druntime/src/core/internal/abort.d",
    "druntime/src/core/internal/array/appending.d",
    "druntime/src/core/internal/array/capacity.d",
    "druntime/src/core/internal/array/concatenation.d",
    "druntime/src/core/internal/array/equality.d",
    "druntime/src/core/internal/array/utils.d",
    "druntime/src/core/internal/backtrace/unwind.d",
    "druntime/src/core/internal/container/common.d",
    "druntime/src/core/internal/convert.d",
    "druntime/src/core/internal/container/treap.d",
    "druntime/src/core/internal/entrypoint.d",
    "druntime/src/core/internal/gc/bits.d",
    "druntime/src/core/internal/gc/impl/conservative/gc.d",
    "druntime/src/core/internal/gc/impl/manual/gc.d",
    "druntime/src/core/internal/gc/impl/proto/gc.d",
    "druntime/src/core/internal/gc/os.d",
    "druntime/src/core/internal/gc/proxy.d",
    "druntime/src/core/internal/lifetime.d",
    "druntime/src/core/internal/parseoptions.d",
    "druntime/src/core/internal/qsort.d",
    "druntime/src/core/internal/spinlock.d",
    "druntime/src/core/internal/string.d",
    "druntime/src/core/internal/traits.d",
    "druntime/src/core/internal/util/array.d",
    "druntime/src/core/lifetime.d",
    "druntime/src/core/runtime.d",
    "druntime/src/core/memory.d",
    "druntime/src/core/sync/condition.d",
    "druntime/src/core/sync/event.d",
    "druntime/src/core/sync/exception.d",
    "druntime/src/core/sync/semaphore.d",
    "druntime/src/core/time.d",
    "druntime/src/core/thread/fiber.d",
    "druntime/src/core/thread/osthread.d",
    "druntime/src/core/thread/threadbase.d",
    "druntime/src/core/thread/threadgroup.d",
    "druntime/src/core/thread/types.d",
    "druntime/src/core/thread/context.d",
    "druntime/src/core/thread/package.d",
    "druntime/src/core/stdc/fenv.d",
    "druntime/src/core/stdc/errno.d",
    "druntime/src/core/stdc/stdint.d",
    "druntime/src/core/stdc/stdio.d",
    "druntime/src/core/stdc/wchar_.d",
    "druntime/src/object.d",
    "druntime/src/rt/adi.d",
    "druntime/src/rt/aaA.d",
    "druntime/src/rt/arraycat.d",
    "druntime/src/rt/cast_.d",
    "druntime/src/rt/config.d",
    "druntime/src/rt/critical_.d",
    "druntime/src/rt/deh.d",
    "druntime/src/rt/deh_win64_posix.d",
    "druntime/src/rt/dmain2.d",
    "druntime/src/rt/dwarfeh.d",
    "druntime/src/rt/ehalloc.d",
    "druntime/src/rt/invariant.d",
    "druntime/src/rt/lifetime.d",
    "druntime/src/rt/memory.d",
    "druntime/src/rt/minfo.d",
    "druntime/src/rt/monitor_.d",
    "druntime/src/rt/profilegc.d",
    "druntime/src/rt/tlsgc.d",
    "druntime/src/rt/util/typeinfo.d",
    "druntime/src/rt/util/utility.d",
    "druntime/src/rt/sections.d",
    "druntime/src/rt/sections_android.d",
    "druntime/src/rt/sections_elf_shared.d",
    "druntime/src/rt/sections_ldc.d",
    "druntime/src/rt/sections_osx_x86.d",
    // "druntime/src/ldc/sanitizers_optionally_linked.d",
};
