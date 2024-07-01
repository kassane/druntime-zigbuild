//! Build D runtime + std (phobos) using zig-build with ABS
const std = @import("std");
const ldc2 = @import("abs").ldc2;
const zcc = @import("abs").zcc;
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

    const linkMode = b.option(std.builtin.LinkMode, "linkage", "Change linking mode (default: static)") orelse .static;
    const enable_phobos = b.option(bool, "phobos", "Build phobos library (default: false)") orelse false;

    try buildRuntime(b, .{
        .target = target,
        .optimize = optimize,
        .linkage = linkMode,
    });
    if (enable_phobos)
        try buildPhobos(b, .{
            .target = target,
            .optimize = optimize,
            .linkage = linkMode,
        });
}

fn buildRuntime(b: *std.Build, options: buildOptions) !void {
    const source = switch (options.target.result.cpu.arch) {
        .aarch64, .aarch64_32 => &[_][]const u8{
            "druntime/src/ldc/arm_unwind.c",
        } ++ runtime_src,
        else => if (options.target.result.abi == .msvc)
            runtime_src ++ &[_][]const u8{
                "druntime/src/ldc/msvc.c",
                "druntime/src/ldc/eh_msvc.d",
            }
        else
            runtime_src,
    };

    const threadAsm = b.addStaticLibrary(.{
        .name = "threadasm",
        .target = options.target,
        .optimize = options.optimize,
    });
    threadAsm.addIncludePath(b.path("druntime/src")); // importc.h
    threadAsm.addAssemblyFile(b.path("druntime/src/core/threadasm.S"));
    threadAsm.addAssemblyFile(b.path("druntime/src/ldc/eh_asm.S"));

    const versions_config = switch (options.target.result.cpu.arch) {
        .aarch64, .x86_64, .x86 => &[_][]const u8{
            "AsmExternal", // used by fiber module
            "OnlyLowMemUnittest", // disables memory-greedy unittests
            "SupportSanitizers", // enables sanitizers support
        },
        else => &[_][]const u8{
            "OnlyLowMemUnittest", // disables memory-greedy unittests
            "SupportSanitizers", // enables sanitizers support
        },
    };

    const tagLabel = switch (options.optimize) {
        .Debug => "debug",
        else => "release",
    };
    const linkMode = switch (options.linkage) {
        .static => "static",
        .dynamic => "shared",
    };
    try buildD(b, .{
        .name = b.fmt("druntime-ldc-{s}-{s}", .{ linkMode, tagLabel }),
        .kind = .lib,
        .linkage = options.linkage,
        .target = options.target,
        .optimize = options.optimize,
        .sources = source,
        .dflags = &.{
            "-Idruntime/src",
            "-w",
            "-de",
            "-preview=dip1000",
            "-preview=fieldwise",
            "-conf=",
            "-defaultlib=",
            "-debuglib=",
        },
        .versions = versions_config,
        .artifact = threadAsm,
        .use_zigcc = true,
        .t_options = try zcc.buildOptions(b, options.target),
    });
}

fn buildD(b: *std.Build, options: ldc2.DCompileStep) !void {
    const exe = try ldc2.BuildStep(b, options);
    b.default_step.dependOn(&exe.step);
}

fn buildPhobos(b: *std.Build, options: buildOptions) !void {
    const tagLabel = switch (options.optimize) {
        .Debug => "debug",
        else => "release",
    };
    const linkMode = switch (options.linkage) {
        .static => "static",
        .dynamic => "shared",
    };
    try buildD(b, .{
        .name = b.fmt("phobos2-ldc-{s}-{s}", .{ linkMode, tagLabel }),
        .kind = .lib,
        .linkage = options.linkage,
        .target = options.target,
        .optimize = options.optimize,
        .sources = std_src,
        .dflags = &.{
            "-Iphobos",
            "-Idruntime/src",
            "-w",
            "-conf=",
            "-defaultlib=",
            "-debuglib=",
            "-de",
            "-preview=dip1000",
            "-preview=dtorfields",
            "-preview=fieldwise",
            "-lowmem",
        },
        .artifact = buildZlib(b, .{
            .target = options.target,
            .optimize = options.optimize,
        }),
        .use_zigcc = true,
        .t_options = try zcc.buildOptions(b, options.target),
    });
}

const buildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode = .static,
};

const runtime_src = &[_][]const u8{
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
    "druntime/src/ldc/attributes.d",
    "druntime/src/ldc/asan.d",
    "druntime/src/ldc/sanitizers_optionally_linked.d",
};

fn buildZlib(b: *std.Build, options: buildOptions) *std.Build.Step.Compile {
    const phobos_zlib_path = b.pathJoin(&.{
        "phobos",
        "etc",
        "c",
        "zlib",
    });
    const libz = b.addStaticLibrary(.{
        .name = "z",
        .target = options.target,
        .optimize = options.optimize,
    });
    libz.pie = true;

    libz.addIncludePath(b.path(phobos_zlib_path));
    libz.addCSourceFiles(.{
        .root = b.path(phobos_zlib_path),
        .files = &.{
            "adler32.c",
            "crc32.c",
            "deflate.c",
            "infback.c",
            "inffast.c",
            "inflate.c",
            "inftrees.c",
            "trees.c",
            "zutil.c",
            "compress.c",
            "uncompr.c",
            "gzclose.c",
            "gzlib.c",
            "gzread.c",
            "gzwrite.c",
        },
        .flags = &.{
            "-std=c89",
            "-Wall",
            "-Wextra",
            "-Wno-unused-parameter",
        },
    });
    libz.linkLibC();
    return libz;
}

const std_src = &[_][]const u8{
    "phobos/etc/c/curl.d",
    "phobos/etc/c/odbc/sql.d",
    "phobos/etc/c/odbc/sqlext.d",
    "phobos/etc/c/odbc/sqltypes.d",
    "phobos/etc/c/odbc/sqlucode.d",
    "phobos/etc/c/sqlite3.d",
    "phobos/etc/c/zlib.d",
    "phobos/phobos/sys/compiler.d",
    "phobos/phobos/sys/meta.d",
    "phobos/phobos/sys/system.d",
    "phobos/phobos/sys/traits.d",
    "phobos/std/algorithm/comparison.d",
    "phobos/std/algorithm/internal.d",
    "phobos/std/algorithm/iteration.d",
    "phobos/std/algorithm/mutation.d",
    "phobos/std/algorithm/package.d",
    "phobos/std/algorithm/searching.d",
    "phobos/std/algorithm/setops.d",
    "phobos/std/algorithm/sorting.d",
    "phobos/std/array.d",
    "phobos/std/ascii.d",
    "phobos/std/base64.d",
    "phobos/std/bigint.d",
    "phobos/std/bitmanip.d",
    "phobos/std/checkedint.d",
    "phobos/std/compiler.d",
    "phobos/std/complex.d",
    "phobos/std/concurrency.d",
    "phobos/std/container/array.d",
    "phobos/std/container/binaryheap.d",
    "phobos/std/container/dlist.d",
    "phobos/std/container/package.d",
    "phobos/std/container/rbtree.d",
    "phobos/std/container/slist.d",
    "phobos/std/container/util.d",
    "phobos/std/conv.d",
    "phobos/std/csv.d",
    "phobos/std/datetime/date.d",
    "phobos/std/datetime/interval.d",
    "phobos/std/datetime/package.d",
    "phobos/std/datetime/stopwatch.d",
    "phobos/std/datetime/systime.d",
    "phobos/std/datetime/timezone.d",
    "phobos/std/demangle.d",
    "phobos/std/digest/crc.d",
    "phobos/std/digest/hmac.d",
    "phobos/std/digest/md.d",
    "phobos/std/digest/murmurhash.d",
    "phobos/std/digest/package.d",
    "phobos/std/digest/ripemd.d",
    "phobos/std/digest/sha.d",
    "phobos/std/encoding.d",
    "phobos/std/exception.d",
    "phobos/std/experimental/allocator/building_blocks/affix_allocator.d",
    "phobos/std/experimental/allocator/building_blocks/aligned_block_list.d",
    "phobos/std/experimental/allocator/building_blocks/allocator_list.d",
    "phobos/std/experimental/allocator/building_blocks/ascending_page_allocator.d",
    "phobos/std/experimental/allocator/building_blocks/bitmapped_block.d",
    "phobos/std/experimental/allocator/building_blocks/bucketizer.d",
    "phobos/std/experimental/allocator/building_blocks/fallback_allocator.d",
    "phobos/std/experimental/allocator/building_blocks/free_list.d",
    "phobos/std/experimental/allocator/building_blocks/free_tree.d",
    "phobos/std/experimental/allocator/building_blocks/kernighan_ritchie.d",
    "phobos/std/experimental/allocator/building_blocks/null_allocator.d",
    "phobos/std/experimental/allocator/building_blocks/package.d",
    "phobos/std/experimental/allocator/building_blocks/quantizer.d",
    "phobos/std/experimental/allocator/building_blocks/region.d",
    "phobos/std/experimental/allocator/building_blocks/scoped_allocator.d",
    "phobos/std/experimental/allocator/building_blocks/segregator.d",
    "phobos/std/experimental/allocator/building_blocks/stats_collector.d",
    "phobos/std/experimental/allocator/common.d",
    "phobos/std/experimental/allocator/gc_allocator.d",
    "phobos/std/experimental/allocator/mallocator.d",
    "phobos/std/experimental/allocator/mmap_allocator.d",
    "phobos/std/experimental/allocator/package.d",
    "phobos/std/experimental/allocator/showcase.d",
    "phobos/std/experimental/allocator/typed.d",
    "phobos/std/experimental/checkedint.d",
    "phobos/std/experimental/logger/core.d",
    "phobos/std/experimental/logger/filelogger.d",
    "phobos/std/experimental/logger/multilogger.d",
    "phobos/std/experimental/logger/nulllogger.d",
    "phobos/std/experimental/logger/package.d",
    "phobos/std/file.d",
    "phobos/std/format/internal/floats.d",
    "phobos/std/format/internal/read.d",
    "phobos/std/format/internal/write.d",
    "phobos/std/format/package.d",
    "phobos/std/format/read.d",
    "phobos/std/format/spec.d",
    "phobos/std/format/write.d",
    "phobos/std/functional.d",
    "phobos/std/getopt.d",
    "phobos/std/int128.d",
    "phobos/std/internal/attributes.d",
    "phobos/std/internal/cstring.d",
    "phobos/std/internal/digest/sha_SSSE3.d",
    "phobos/std/internal/math/biguintarm.d",
    "phobos/std/internal/math/biguintcore.d",
    "phobos/std/internal/math/biguintnoasm.d",
    "phobos/std/internal/math/biguintx86.d",
    "phobos/std/internal/math/errorfunction.d",
    "phobos/std/internal/math/gammafunction.d",
    "phobos/std/internal/memory.d",
    "phobos/std/internal/scopebuffer.d",
    // "phobos/std/internal/test/dummyrange.d",
    // "phobos/std/internal/test/range.d",
    // "phobos/std/internal/test/uda.d",
    "phobos/std/internal/unicode_comp.d",
    "phobos/std/internal/unicode_decomp.d",
    "phobos/std/internal/unicode_grapheme.d",
    "phobos/std/internal/unicode_norm.d",
    "phobos/std/internal/unicode_tables.d",
    "phobos/std/internal/windows/advapi32.d",
    "phobos/std/json.d",
    "phobos/std/logger/core.d",
    "phobos/std/logger/filelogger.d",
    "phobos/std/logger/multilogger.d",
    "phobos/std/logger/nulllogger.d",
    "phobos/std/logger/package.d",
    "phobos/std/math/algebraic.d",
    "phobos/std/math/constants.d",
    "phobos/std/math/exponential.d",
    "phobos/std/math/hardware.d",
    "phobos/std/math/operations.d",
    "phobos/std/math/package.d",
    "phobos/std/math/remainder.d",
    "phobos/std/math/rounding.d",
    "phobos/std/math/traits.d",
    "phobos/std/math/trigonometry.d",
    "phobos/std/mathspecial.d",
    "phobos/std/meta.d",
    "phobos/std/mmfile.d",
    "phobos/std/net/curl.d",
    "phobos/std/net/isemail.d",
    "phobos/std/numeric.d",
    "phobos/std/outbuffer.d",
    "phobos/std/package.d",
    "phobos/std/parallelism.d",
    "phobos/std/path.d",
    "phobos/std/process.d",
    "phobos/std/random.d",
    "phobos/std/range/interfaces.d",
    "phobos/std/range/package.d",
    "phobos/std/range/primitives.d",
    "phobos/std/regex/internal/backtracking.d",
    "phobos/std/regex/internal/generator.d",
    "phobos/std/regex/internal/ir.d",
    "phobos/std/regex/internal/kickstart.d",
    "phobos/std/regex/internal/parser.d",
    // "phobos/std/regex/internal/tests.d",
    // "phobos/std/regex/internal/tests2.d",
    "phobos/std/regex/internal/thompson.d",
    "phobos/std/regex/package.d",
    "phobos/std/signals.d",
    "phobos/std/socket.d",
    "phobos/std/stdint.d",
    "phobos/std/stdio.d",
    "phobos/std/string.d",
    "phobos/std/sumtype.d",
    "phobos/std/system.d",
    "phobos/std/traits.d",
    "phobos/std/typecons.d",
    "phobos/std/typetuple.d",
    "phobos/std/uni/package.d",
    "phobos/std/uri.d",
    "phobos/std/utf.d",
    "phobos/std/uuid.d",
    "phobos/std/variant.d",
    "phobos/std/windows/charset.d",
    "phobos/std/windows/registry.d",
    "phobos/std/windows/syserror.d",
    "phobos/std/zip.d",
    "phobos/std/zlib.d",
    // "phobos/test/betterc_module_tests.d",
    // "phobos/test/dub_stdx_allocator.d",
    // "phobos/test/dub_stdx_checkedint.d",
    "phobos/tools/unicode_table_generator.d",
    // "phobos/unittest.d",
};
