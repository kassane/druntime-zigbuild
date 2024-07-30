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
            .dependency = b.dependency("phobos", .{}),
        });
}

fn buildRuntime(b: *std.Build, options: buildOptions) !void {
    const source = switch (options.target.result.os.tag) {
        .windows => runtime_src ++ &[_][]const u8{
            "druntime/src/ldc/eh_msvc.d",
            "druntime/src/ldc/msvc.c",
        },
        else => runtime_src,
    };

    const complementary = b.addStaticLibrary(.{
        .name = "asm",
        .target = options.target,
        .optimize = options.optimize,
    });
    complementary.addAssemblyFile(b.path("druntime/src/core/threadasm.S"));
    complementary.addAssemblyFile(b.path("druntime/src/ldc/eh_asm.S"));
    if (options.target.result.cpu.arch.isAARCH64()) {
        complementary.addCSourceFile(.{
            .file = b.path("druntime/src/ldc/arm_unwind.c"),
        });
        complementary.linkLibC();
    }

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
        .Debug => "-debug",
        else => "",
    };
    const linkMode = switch (options.linkage) {
        .static => "-static",
        .dynamic => "-shared",
    };
    try buildD(b, .{
        .name = b.fmt("druntime-ldc{s}{s}", .{
            tagLabel,
            linkMode,
        }),
        .kind = .lib,
        .linkage = options.linkage,
        .target = options.target,
        .optimize = options.optimize,
        .sources = source,
        .dflags = &.{
            "-w",
            "-de",
            "-preview=dip1000",
            "-preview=dtorfields",
            "-preview=fieldwise",
            "-conf=",
            "-defaultlib=",
            "-debuglib=",
        },
        .importPaths = &.{
            "druntime/src",
        },
        .cIncludePaths = &.{
            "druntime/src", // importc header
        },
        .versions = versions_config,
        .artifact = complementary,
        .use_zigcc = true,
        .t_options = try zcc.buildOptions(b, options.target),
    });
}

fn buildD(b: *std.Build, options: ldc2.DCompileStep) !void {
    const exe = try ldc2.BuildStep(b, options);
    b.default_step.dependOn(&exe.step);
}

fn buildPhobos(b: *std.Build, options: buildOptions) !void {
    const phobos_path = if (options.dependency) |dep|
        dep.path("").getPath(b)
    else
        unreachable;
    const tagLabel = switch (options.optimize) {
        .Debug => "-debug",
        else => "",
    };
    const linkMode = switch (options.linkage) {
        .static => "-static",
        .dynamic => "-shared",
    };
    try buildD(b, .{
        .name = b.fmt("phobos2-ldc{s}{s}", .{
            tagLabel,
            linkMode,
        }),
        .kind = .lib,
        .linkage = options.linkage,
        .target = options.target,
        .optimize = options.optimize,
        .sources = &.{
            b.pathJoin(&.{ phobos_path, "etc/c/curl.d" }),
            b.pathJoin(&.{ phobos_path, "etc/c/odbc/sql.d" }),
            b.pathJoin(&.{ phobos_path, "etc/c/odbc/sqlext.d" }),
            b.pathJoin(&.{ phobos_path, "etc/c/odbc/sqltypes.d" }),
            b.pathJoin(&.{ phobos_path, "etc/c/odbc/sqlucode.d" }),
            b.pathJoin(&.{ phobos_path, "etc/c/sqlite3.d" }),
            b.pathJoin(&.{ phobos_path, "etc/c/zlib.d" }),
            b.pathJoin(&.{ phobos_path, "phobos/sys/compiler.d" }),
            b.pathJoin(&.{ phobos_path, "phobos/sys/meta.d" }),
            b.pathJoin(&.{ phobos_path, "phobos/sys/system.d" }),
            b.pathJoin(&.{ phobos_path, "phobos/sys/traits.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/comparison.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/internal.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/iteration.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/mutation.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/searching.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/setops.d" }),
            b.pathJoin(&.{ phobos_path, "std/algorithm/sorting.d" }),
            b.pathJoin(&.{ phobos_path, "std/array.d" }),
            b.pathJoin(&.{ phobos_path, "std/ascii.d" }),
            b.pathJoin(&.{ phobos_path, "std/base64.d" }),
            b.pathJoin(&.{ phobos_path, "std/bigint.d" }),
            b.pathJoin(&.{ phobos_path, "std/bitmanip.d" }),
            b.pathJoin(&.{ phobos_path, "std/checkedint.d" }),
            b.pathJoin(&.{ phobos_path, "std/compiler.d" }),
            b.pathJoin(&.{ phobos_path, "std/complex.d" }),
            b.pathJoin(&.{ phobos_path, "std/concurrency.d" }),
            b.pathJoin(&.{ phobos_path, "std/container/array.d" }),
            b.pathJoin(&.{ phobos_path, "std/container/binaryheap.d" }),
            b.pathJoin(&.{ phobos_path, "std/container/dlist.d" }),
            b.pathJoin(&.{ phobos_path, "std/container/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/container/rbtree.d" }),
            b.pathJoin(&.{ phobos_path, "std/container/slist.d" }),
            b.pathJoin(&.{ phobos_path, "std/container/util.d" }),
            b.pathJoin(&.{ phobos_path, "std/conv.d" }),
            b.pathJoin(&.{ phobos_path, "std/csv.d" }),
            b.pathJoin(&.{ phobos_path, "std/datetime/date.d" }),
            b.pathJoin(&.{ phobos_path, "std/datetime/interval.d" }),
            b.pathJoin(&.{ phobos_path, "std/datetime/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/datetime/stopwatch.d" }),
            b.pathJoin(&.{ phobos_path, "std/datetime/systime.d" }),
            b.pathJoin(&.{ phobos_path, "std/datetime/timezone.d" }),
            b.pathJoin(&.{ phobos_path, "std/demangle.d" }),
            b.pathJoin(&.{ phobos_path, "std/digest/crc.d" }),
            b.pathJoin(&.{ phobos_path, "std/digest/hmac.d" }),
            b.pathJoin(&.{ phobos_path, "std/digest/md.d" }),
            b.pathJoin(&.{ phobos_path, "std/digest/murmurhash.d" }),
            b.pathJoin(&.{ phobos_path, "std/digest/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/digest/ripemd.d" }),
            b.pathJoin(&.{ phobos_path, "std/digest/sha.d" }),
            b.pathJoin(&.{ phobos_path, "std/encoding.d" }),
            b.pathJoin(&.{ phobos_path, "std/exception.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/affix_allocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/aligned_block_list.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/allocator_list.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/ascending_page_allocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/bitmapped_block.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/bucketizer.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/fallback_allocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/free_list.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/free_tree.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/kernighan_ritchie.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/null_allocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/quantizer.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/region.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/scoped_allocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/segregator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/building_blocks/stats_collector.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/common.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/gc_allocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/mallocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/mmap_allocator.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/showcase.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/allocator/typed.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/checkedint.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/logger/core.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/logger/filelogger.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/logger/multilogger.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/logger/nulllogger.d" }),
            b.pathJoin(&.{ phobos_path, "std/experimental/logger/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/file.d" }),
            b.pathJoin(&.{ phobos_path, "std/format/internal/floats.d" }),
            b.pathJoin(&.{ phobos_path, "std/format/internal/read.d" }),
            b.pathJoin(&.{ phobos_path, "std/format/internal/write.d" }),
            b.pathJoin(&.{ phobos_path, "std/format/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/format/read.d" }),
            b.pathJoin(&.{ phobos_path, "std/format/spec.d" }),
            b.pathJoin(&.{ phobos_path, "std/format/write.d" }),
            b.pathJoin(&.{ phobos_path, "std/functional.d" }),
            b.pathJoin(&.{ phobos_path, "std/getopt.d" }),
            b.pathJoin(&.{ phobos_path, "std/int128.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/attributes.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/cstring.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/digest/sha_SSSE3.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/math/biguintarm.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/math/biguintcore.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/math/biguintnoasm.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/math/biguintx86.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/math/errorfunction.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/math/gammafunction.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/memory.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/scopebuffer.d" }),
            // b.pathJoin(&.{phobos_path, "std/internal/test/dummyrange.d"}),
            // b.pathJoin(&.{phobos_path, "std/internal/test/range.d"}),
            // b.pathJoin(&.{phobos_path, "std/internal/test/uda.d"}),
            b.pathJoin(&.{ phobos_path, "std/internal/unicode_comp.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/unicode_decomp.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/unicode_grapheme.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/unicode_norm.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/unicode_tables.d" }),
            b.pathJoin(&.{ phobos_path, "std/internal/windows/advapi32.d" }),
            b.pathJoin(&.{ phobos_path, "std/json.d" }),
            b.pathJoin(&.{ phobos_path, "std/logger/core.d" }),
            b.pathJoin(&.{ phobos_path, "std/logger/filelogger.d" }),
            b.pathJoin(&.{ phobos_path, "std/logger/multilogger.d" }),
            b.pathJoin(&.{ phobos_path, "std/logger/nulllogger.d" }),
            b.pathJoin(&.{ phobos_path, "std/logger/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/algebraic.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/constants.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/exponential.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/hardware.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/operations.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/remainder.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/rounding.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/traits.d" }),
            b.pathJoin(&.{ phobos_path, "std/math/trigonometry.d" }),
            b.pathJoin(&.{ phobos_path, "std/mathspecial.d" }),
            b.pathJoin(&.{ phobos_path, "std/meta.d" }),
            b.pathJoin(&.{ phobos_path, "std/mmfile.d" }),
            b.pathJoin(&.{ phobos_path, "std/net/curl.d" }),
            b.pathJoin(&.{ phobos_path, "std/net/isemail.d" }),
            b.pathJoin(&.{ phobos_path, "std/numeric.d" }),
            b.pathJoin(&.{ phobos_path, "std/outbuffer.d" }),
            b.pathJoin(&.{ phobos_path, "std/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/parallelism.d" }),
            b.pathJoin(&.{ phobos_path, "std/path.d" }),
            b.pathJoin(&.{ phobos_path, "std/process.d" }),
            b.pathJoin(&.{ phobos_path, "std/random.d" }),
            b.pathJoin(&.{ phobos_path, "std/range/interfaces.d" }),
            b.pathJoin(&.{ phobos_path, "std/range/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/range/primitives.d" }),
            b.pathJoin(&.{ phobos_path, "std/regex/internal/backtracking.d" }),
            b.pathJoin(&.{ phobos_path, "std/regex/internal/generator.d" }),
            b.pathJoin(&.{ phobos_path, "std/regex/internal/ir.d" }),
            b.pathJoin(&.{ phobos_path, "std/regex/internal/kickstart.d" }),
            b.pathJoin(&.{ phobos_path, "std/regex/internal/parser.d" }),
            // b.pathJoin(&.{phobos_path, "std/regex/internal/tests.d"}),
            // b.pathJoin(&.{phobos_path, "std/regex/internal/tests2.d"}),
            b.pathJoin(&.{ phobos_path, "std/regex/internal/thompson.d" }),
            b.pathJoin(&.{ phobos_path, "std/regex/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/signals.d" }),
            b.pathJoin(&.{ phobos_path, "std/socket.d" }),
            b.pathJoin(&.{ phobos_path, "std/stdint.d" }),
            b.pathJoin(&.{ phobos_path, "std/stdio.d" }),
            b.pathJoin(&.{ phobos_path, "std/string.d" }),
            b.pathJoin(&.{ phobos_path, "std/sumtype.d" }),
            b.pathJoin(&.{ phobos_path, "std/system.d" }),
            b.pathJoin(&.{ phobos_path, "std/traits.d" }),
            b.pathJoin(&.{ phobos_path, "std/typecons.d" }),
            b.pathJoin(&.{ phobos_path, "std/typetuple.d" }),
            b.pathJoin(&.{ phobos_path, "std/uni/package.d" }),
            b.pathJoin(&.{ phobos_path, "std/uri.d" }),
            b.pathJoin(&.{ phobos_path, "std/utf.d" }),
            b.pathJoin(&.{ phobos_path, "std/uuid.d" }),
            b.pathJoin(&.{ phobos_path, "std/variant.d" }),
            b.pathJoin(&.{ phobos_path, "std/windows/charset.d" }),
            b.pathJoin(&.{ phobos_path, "std/windows/registry.d" }),
            b.pathJoin(&.{ phobos_path, "std/windows/syserror.d" }),
            b.pathJoin(&.{ phobos_path, "std/zip.d" }),
            b.pathJoin(&.{ phobos_path, "std/zlib.d" }),
            // b.pathJoin(&.{phobos_path, "test/betterc_module_tests.d"}),
            // b.pathJoin(&.{phobos_path, "test/dub_stdx_allocator.d"}),
            // b.pathJoin(&.{phobos_path, "test/dub_stdx_checkedint.d"}),
            b.pathJoin(&.{ phobos_path, "tools/unicode_table_generator.d" }),
            // b.pathJoin(&.{phobos_path, "unittest.d"}),
        },
        .dflags = &.{
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
        .importPaths = &.{
            phobos_path,
            "druntime/src",
        },
        .artifact = buildZlib(b, options),
        .use_zigcc = true,
        .t_options = try zcc.buildOptions(b, options.target),
    });
}

const buildOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode = .static,
    dependency: ?*std.Build.Dependency = null,
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
    const phobos_path = if (options.dependency) |dep|
        dep.path("").getPath(b)
    else
        unreachable;
    const phobos_zlib_path = b.pathJoin(&.{ phobos_path, "etc", "c", "zlib" });
    const libz = b.addStaticLibrary(.{
        .name = "z",
        .target = options.target,
        .optimize = options.optimize,
    });
    libz.pie = true;

    libz.addIncludePath(.{ .cwd_relative = phobos_zlib_path });
    libz.addCSourceFiles(.{
        .root = .{ .cwd_relative = phobos_zlib_path },
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
