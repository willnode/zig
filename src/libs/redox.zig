const std = @import("std");
const Allocator = std.mem.Allocator;
const mem = std.mem;
const log = std.log;
const fs = std.fs;
const path = fs.path;
const assert = std.debug.assert;
const Version = std.SemanticVersion;
const Path = std.Build.Cache.Path;

const Compilation = @import("../Compilation.zig");
const build_options = @import("build_options");
const trace = @import("../tracy.zig").trace;
const Cache = std.Build.Cache;
const Module = @import("../Package/Module.zig");
const link = @import("../link.zig");

pub const CrtFile = enum {
    crt0_o,
};

pub fn needsCrt0(output_mode: std.builtin.OutputMode) ?CrtFile {
    return switch (output_mode) {
        .Obj, .Lib => null,
        .Exe => .crt0_o,
    };
}

fn includePath(comp: *Compilation, arena: Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &.{
        comp.dirs.zig_lib.path.?,
        "libc" ++ path.sep_str ++ "include",
        sub_path,
    });
}

fn csuPath(comp: *Compilation, arena: Allocator, sub_path: []const u8) ![]const u8 {
    return path.join(arena, &.{
        comp.dirs.zig_lib.path.?,
        "libc" ++ path.sep_str ++ "redox" ++ path.sep_str ++ "lib" ++ path.sep_str ++ "csu",
        sub_path,
    });
}

pub fn buildCrtFile(comp: *Compilation, crt_file: CrtFile, prog_node: std.Progress.Node) anyerror!void {
    if (!build_options.have_llvm) return error.ZigCompilerNotBuiltWithLLVMExtensions;

    const gpa = comp.gpa;
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = &comp.root_mod.resolved_target.result;

    switch (crt_file) {
        .crt0_o => {
            var acflags = std.array_list.Managed([]const u8).init(arena);
            try acflags.appendSlice(&.{
                "-I",
                try csuPath(comp, arena, "common"),
                "-Qunused-arguments",
            });

            const arch_name = switch (target.cpu.arch) {
                .x86_64 => "x86_64",
                .aarch64 => "aarch64",
                else => return error.UnsupportedRedoxArch,
            };

            const files = [_]Compilation.CSourceFile{
                .{
                    .src_path = try csuPath(comp, arena, try path.join(arena, &.{ arch_name, "crt0.S" })),
                    .cache_exempt_flags = acflags.items,
                    .owner = undefined,
                },
            };

            return comp.build_crt_file("crt0", .Obj, .@"redox libc crt0.o", prog_node, &files, .{
                .pic = true,
            });
        },
    }
}

pub const Lib = struct {
    name: []const u8,
    sover: u8,
};

pub const libs = [_]Lib{
    .{ .name = "c", .sover = 6 },
};

pub const abilists_path = "libc" ++ path.sep_str ++ "redox" ++ path.sep_str ++ "abilists";
pub const abilists_max_size = 512 * 1024;

pub const ABI = struct {
    all_versions: []const Version,
    all_targets: []const std.zig.target.ArchOsAbi,
    inclusions: []const u8,
    arena_state: std.heap.ArenaAllocator.State,

    pub fn destroy(abi: *ABI, gpa: Allocator) void {
        abi.arena_state.promote(gpa).deinit();
    }
};

pub fn loadMetaData(gpa: Allocator, contents: []const u8) !*ABI {
    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    errdefer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    var index: usize = 0;
    const libs_len = contents[index]; index += 1;
    var i: u8 = 0;
    while (i < libs_len) : (i += 1) {
        const lib_name = mem.sliceTo(contents[index..], 0);
        index += lib_name.len + 1;
    }

    const versions_len = contents[index]; index += 1;
    const versions = try arena.alloc(Version, versions_len);
    i = 0;
    while (i < versions.len) : (i += 1) {
        versions[i] = .{ .major = contents[index], .minor = contents[index+1], .patch = contents[index+2] };
        index += 3;
    }

    const targets_len = contents[index]; index += 1;
    const targets = try arena.alloc(std.zig.target.ArchOsAbi, targets_len);
    i = 0;
    while (i < targets.len) : (i += 1) {
        const target_name = mem.sliceTo(contents[index..], 0);
        index += target_name.len + 1;
        var it = mem.tokenizeScalar(u8, target_name, '-');
        const arch = std.meta.stringToEnum(std.Target.Cpu.Arch, it.next().?) orelse return error.ZigInstallationCorrupt;
        targets[i] = .{ .arch = arch, .os = .redox, .abi = .none };
    }

    const abi = try arena.create(ABI);
    abi.* = .{
        .all_versions = versions,
        .all_targets = targets,
        .inclusions = contents[index..],
        .arena_state = arena_allocator.state,
    };
    return abi;
}

pub fn buildSharedObjects(comp: *Compilation, prog_node: std.Progress.Node) anyerror!void {
    const tracy = trace(@src());
    defer tracy.end();

    if (!build_options.have_llvm) {
        return error.ZigCompilerNotBuiltWithLLVMExtensions;
    }

    const gpa = comp.gpa;
    const io = comp.io;

    var arena_allocator = std.heap.ArenaAllocator.init(gpa);
    defer arena_allocator.deinit();
    const arena = arena_allocator.allocator();

    const target = comp.getTarget();
    const target_version = target.os.version_range.semver.min;

    var cache: Cache = .{
        .gpa = gpa,
        .io = io,
        .manifest_dir = try comp.dirs.global_cache.handle.makeOpenPath("h", .{}),
    };
    cache.addPrefix(.{ .path = null, .handle = fs.cwd() });
    cache.addPrefix(comp.dirs.zig_lib);
    cache.addPrefix(comp.dirs.global_cache);
    defer cache.manifest_dir.close();

    var man = cache.obtain();
    defer man.deinit();
    man.hash.addBytes(build_options.version);
    man.hash.add(target.cpu.arch);
    man.hash.add(target.abi);
    man.hash.add(target_version);

    const full_abilists_path = try comp.dirs.zig_lib.join(arena, &.{abilists_path});
    const abilists_index = try man.addFile(full_abilists_path, abilists_max_size);

    if (try man.hit()) {
        const digest = man.final();
        return queueSharedObjects(comp, .{
            .lock = man.toOwnedLock(),
            .dir_path = .{
                .root_dir = comp.dirs.global_cache,
                .sub_path = try gpa.dupe(u8, "o" ++ fs.path.sep_str ++ digest),
            },
        });
    }

    const digest = man.final();
    const o_sub_path = try path.join(arena, &[_][]const u8{ "o", &digest });

    var o_directory: Cache.Directory = .{
        .handle = try comp.dirs.global_cache.handle.makeOpenPath(o_sub_path, .{}),
        .path = try comp.dirs.global_cache.join(arena, &.{o_sub_path}),
    };
    defer o_directory.handle.close();

    const abilists_contents = man.files.keys()[abilists_index].contents.?;
    const metadata = try loadMetaData(gpa, abilists_contents);
    defer metadata.destroy(gpa);

    const target_targ_index = for (metadata.all_targets, 0..) |targ, i| {
        if (targ.arch == target.cpu.arch and
            targ.os == target.os.tag and
            targ.abi == target.abi)
        {
            break i;
        }
    } else {
        unreachable;
    }

    const target_ver_index = metadata.all_versions.len - 1;

    var stubs_asm = std.array_list.Managed(u8).init(gpa);
    defer stubs_asm.deinit();

    for (libs, 0..) |lib, lib_i| {
        stubs_asm.shrinkRetainingCapacity(0);
        try stubs_asm.appendSlice(".text\n");

        var sym_name_buf: std.Io.Writer.Allocating = .init(arena);
        var inc_reader: std.Io.Reader = .fixed(metadata.inclusions);
        const fn_inclusions_len = try inc_reader.takeInt(u16, .little);

        var sym_i: usize = 0;
        var opt_symbol_name: ?[]const u8 = null;

        while (sym_i < fn_inclusions_len) : (sym_i += 1) {
            const sym_name = opt_symbol_name orelse n: {
                sym_name_buf.clearRetainingCapacity();
                _ = try inc_reader.streamDelimiter(&sym_name_buf.writer, 0);
                inc_reader.toss(1);
                break :n sym_name_buf.written();
            };

            const targets_mask = try inc_reader.takeLeb128(u64);
            var lib_info_byte = try inc_reader.takeByte();
            const is_terminal = (lib_info_byte & (1 << 7)) != 0;
            const current_lib_idx = @as(u5, @truncate(lib_info_byte));

            const match = (current_lib_idx == lib_i) and 
                          ((targets_mask & (@as(u64, 1) << @as(u6, @intCast(target_targ_index)))) != 0);

            while (true) {
                const b = try inc_reader.takeByte();
                if ((b & 0b1000_0000) != 0) break;
            }

            if (match) {
                try stubs_asm.print(
                    \\.balign {d}
                    \\.globl {s}
                    \\.type {s}, %function
                    \\{s}: {s} 0
                    \\
                , .{ target.ptrBitWidth() / 8, sym_name, sym_name, sym_name, wordDirective(target) });
            }

            opt_symbol_name = if (is_terminal) null else sym_name;
        }

        try stubs_asm.appendSlice(".data\n");
        const obj_inclusions_len = try inc_reader.takeInt(u16, .little);
        sym_i = 0;
        opt_symbol_name = null;

        while (sym_i < obj_inclusions_len) : (sym_i += 1) {
            const sym_name = opt_symbol_name orelse n: {
                sym_name_buf.clearRetainingCapacity();
                _ = try inc_reader.streamDelimiter(&sym_name_buf.writer, 0);
                inc_reader.toss(1);
                break :n sym_name_buf.written();
            };

            const targets_mask = try inc_reader.takeLeb128(u64);
            const size = try inc_reader.takeLeb128(u16);
            var lib_info_byte = try inc_reader.takeByte();
            const is_terminal = (lib_info_byte & (1 << 7)) != 0;
            const current_lib_idx = @as(u5, @truncate(lib_info_byte));

            const match = (current_lib_idx == lib_i) and 
                          ((targets_mask & (@as(u64, 1) << @as(u6, @intCast(target_targ_index)))) != 0);

            while (true) {
                const b = try inc_reader.takeByte();
                if ((b & 0b1000_0000) != 0) break;
            }

            if (match) {
                try stubs_asm.print(
                    \\.balign {d}
                    \\.globl {s}
                    \\.type {s}, %object
                    \\.size {s}, {d}
                    \\{s}: .fill {d}, 1, 0
                    \\
                , .{ target.ptrBitWidth() / 8, sym_name, sym_name, sym_name, size, sym_name, size });
            }

            opt_symbol_name = if (is_terminal) null else sym_name;
        }

        var lib_name_buf: [32]u8 = undefined;
        const asm_file_basename = try std.fmt.bufPrint(&lib_name_buf, "{s}.s", .{lib.name});
        try o_directory.handle.writeFile(.{ .sub_path = asm_file_basename, .data = stubs_asm.items });
        try buildSharedLib(comp, arena, o_directory, asm_file_basename, lib, prog_node);
    }

    man.writeManifest() catch {};

    return queueSharedObjects(comp, .{
        .lock = man.toOwnedLock(),
        .dir_path = .{
            .root_dir = comp.dirs.global_cache,
            .sub_path = try gpa.dupe(u8, "o" ++ fs.path.sep_str ++ digest),
        },
    });
}

fn queueSharedObjects(comp: *Compilation, so_files: BuiltSharedObjects) void {
    comp.mutex.lock();
    defer comp.mutex.unlock();

    comp.redox_so_files = so_files;

    var task_buffer: [libs.len]link.PrelinkTask = undefined;
    for (libs, 0..) |lib, i| {
        const path_str = std.fmt.allocPrint(comp.arena, "{s}{c}lib{s}.so.{d}", .{
            so_files.dir_path.sub_path, fs.path.sep, lib.name, lib.sover,
        }) catch return comp.setAllocFailure();

        task_buffer[i] = .{ .load_dso = .{
            .root_dir = so_files.dir_path.root_dir,
            .sub_path = path_str,
        } };
    }
    comp.queuePrelinkTasks(&task_buffer);
}

fn wordDirective(target: *const std.Target) []const u8 {
    return if (target.ptrBitWidth() == 64) ".quad" else ".long";
}