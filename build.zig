const std = @import("std");

const Unsupported = error{Tls};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const nng = b.dependency("nng", .{});
    const nng_root = nng.path("");
    const nng_src_path = nng_root.path(b, "src");
    const nng_include_path = nng_root.path(b, "include");

    // options as per NNGOptions.cmake (not quite all yet)
    const nng_elide_deprecated = b.option(bool, "NNG_ELIDE_DEPRECATED", "Elide deprecated functionality.") orelse false;
    const nng_enable_compat = b.option(bool, "NNG_ENABLE_COMPAT", "Enable legacy nanomsg API.") orelse true;
    const nng_enable_stats = b.option(bool, "NNG_ENABLE_STATS", "Enable statistics.") orelse true;

    const nng_proto_bus0 = b.option(bool, "NNG_PROTO_BUS0", "Enable BUSv0 protocol.") orelse true;
    const nng_proto_pair0 = b.option(bool, "NNG_PROTO_PAIR0", "Enable PAIRv0 protocol.") orelse true;
    const nng_proto_pair1 = b.option(bool, "NNG_PROTO_PAIR1", "Enable PAIRv1 protocol.") orelse true;
    const nng_proto_push0 = b.option(bool, "NNG_PROTO_PUSH0", "Enable PUSHv0 protocol.") orelse true;
    const nng_proto_pull0 = b.option(bool, "NNG_PROTO_PULL0", "Enable PULLv0 protocol.") orelse true;
    const nng_proto_pub0 = b.option(bool, "NNG_PROTO_PUB0", "Enable PUBv0 protocol.") orelse true;
    const nng_proto_sub0 = b.option(bool, "NNG_PROTO_SUB0", "Enable SUBv0 protocol.") orelse true;
    const nng_proto_req0 = b.option(bool, "NNG_PROTO_REQ0", "Enable REQv0 protocol.") orelse true;
    const nng_proto_rep0 = b.option(bool, "NNG_PROTO_REP0", "Enable REPv0 protocol.") orelse true;
    const nng_proto_respondent0 = b.option(bool, "NNG_PROTO_RESPONDENT0", "Enable RESPONDENTv0 protocol.") orelse true;
    const nng_proto_surveyor0 = b.option(bool, "NNG_PROTO_SURVEYOR0", "Enable SURVEYORv0 protocol.") orelse true;

    const nng_enable_tls = b.option(bool, "NNG_ENABLE_TLS", "Enable TLS support.") orelse false;
    const nng_supp_tls = nng_enable_tls;
    const TlsEngine = enum { mbed, wolf, none };
    const nng_tls_engine = if (nng_enable_tls) tls: {
        break :tls b.option(TlsEngine, "NNG_TLS_ENGINE", "TLS engine to use.") orelse .mbed;
    } else tls: {
        break :tls .none;
    };

    const nng_enable_http = b.option(bool, "NNG_ENABLE_HTTP", "Enable HTTP API.") orelse true;
    var nng_supp_http = nng_enable_http;
    const nng_enable_ipv6 = b.option(bool, "NNG_ENABLE_IPV6", "Enable IPv6.") orelse true;

    const nng_transport_inproc = b.option(bool, "NNG_TRANSPORT_INPROC", "Enable inproc transport.") orelse true;
    const nng_transport_ipc = b.option(bool, "NNG_TRANSPORT_IPC", "Enable IPC transport.") orelse true;
    const nng_transport_tcp = b.option(bool, "NNG_TRANSPORT_TCP", "Enable TCP transport.") orelse true;
    const nng_transport_tls = b.option(bool, "NNG_TRANSPORT_TLS", "Enable TLS transport.") orelse true;
    const nng_transport_ws = b.option(bool, "NNG_TRANSPORT_WS", "Enable WebSocket transport.") orelse true;
    const nng_transport_wss = b.option(bool, "NNG_TRANSPORT_WSS", "Enable WSS transport.") orelse nng_enable_tls;
    const nng_transport_fdc = b.option(bool, "NNG_TRANSPORT_FDC", "Enable File Descriptor transport (EXPERIMENTAL)") orelse true;

    // const nng_transport_zerotier = b.option(bool, "NNG_TRANSPORT_ZEROTIER", "Enable ZeroTier transport (requires libzerotiercore).") orelse false;

    // Ensure necessary options are set if WebSocket transport is enabled
    const nng_supp_websocket = if (nng_transport_ws or nng_transport_wss) true else false;
    nng_supp_http = if (nng_transport_ws or nng_transport_wss) true else false;
    const nng_supp_base64 = if (nng_transport_ws or nng_transport_wss) true else false;
    const nng_supp_sha1 = if (nng_transport_ws or nng_transport_wss) true else false;

    const znng_lib = b.addStaticLibrary(.{
        .name = "znng",
        .root_source_file = b.path("src/znng.zig"),
        .target = target,
        .optimize = optimize,
    });

    // core macros from main cmake
    znng_lib.defineCMacro("NNG_PRIVATE", null);
    defineCMacroIf(znng_lib, nng_elide_deprecated, "NNG_ELIDE_DEPRECATED");
    defineCMacroIf(znng_lib, nng_enable_compat, "NNG_ENABLE_COMPAT");

    defineCMacroIf(znng_lib, nng_enable_stats, "NNG_ENABLE_STATS");
    defineCMacroIf(znng_lib, nng_enable_ipv6, "NNG_ENABLE_IPV6");

    const nng_resolv_concurrency = b.option([]const u8, "NNG_RESOLV_CONCURRENCY", "Resolver (DNS) concurrency.") orelse "4";
    znng_lib.defineCMacro("NNG_RESOLV_CONCURRENCY", nng_resolv_concurrency);
    const nng_num_taskq_threads = b.option([]const u8, "NNG_NUM_TASKQ_THREADS", "Fixed number of task threads, 0 for automatic") orelse "0";
    znng_lib.defineCMacro("NNG_NUM_TASKQ_THREADS", nng_num_taskq_threads);
    const nng_max_taskq_threads = b.option([]const u8, "NNG_MAX_TASKQ_THREADS", "Upper bound on task threads, 0 for no limit") orelse "16";
    znng_lib.defineCMacro("NNG_MAX_TASKQ_THREADS", nng_max_taskq_threads);
    const nng_num_expire_threads = b.option([]const u8, "NNG_NUM_EXPIRE_THREADS", "Fixed number of expire threads, 0 for automatic") orelse "0";
    znng_lib.defineCMacro("NNG_NUM_EXPIRE_THREADS", nng_num_expire_threads);
    const nng_max_expire_threads = b.option([]const u8, "NNG_MAX_EXPIRE_THREADS", "Upper bound on expire threads, 0 for no limit") orelse "8";
    znng_lib.defineCMacro("NNG_MAX_EXPIRE_THREADS", nng_max_expire_threads);
    const nng_num_poller_threads = b.option([]const u8, "NNG_NUM_POLLER_THREADS", "Fixed number of I/O poller threads, 0 for automatic") orelse "0";
    znng_lib.defineCMacro("NNG_NUM_POLLER_THREADS", nng_num_poller_threads);
    const nng_max_poller_threads = b.option([]const u8, "NNG_MAX_POLLER_THREADS", "Upper bound on I/O poller threads, 0 for no limit") orelse "8";
    znng_lib.defineCMacro("NNG_MAX_POLLER_THREADS", nng_max_poller_threads);

    znng_lib.addIncludePath(nng_src_path);
    znng_lib.addIncludePath(nng_include_path);

    // core nng source files
    znng_lib.addCSourceFiles(.{
        .root = nng_src_path,
        .files = &.{
            "sp/transport.c",
            "sp/protocol.c",
            // "tools/nngcat/nngcat.c",
            // "tools/perf/perf.c",
            // "tools/perf/pubdrop.c",
            "compat/nanomsg/nn.c",
            "core/idhash.c",
            "core/url.c",
            "core/log.c",
            "core/sockaddr.c",
            "core/thread.c",
            "core/list.c",
            "core/pollable.c",
            "core/pipe.c",
            "core/sockfd.c",
            "core/init.c",
            "core/taskq.c",
            "core/panic.c",
            "core/stats.c",
            "core/socket.c",
            "core/msgqueue.c",
            "core/dialer.c",
            "core/tcp.c",
            "core/aio.c",
            "core/device.c",
            "core/listener.c",
            "core/reap.c",
            "core/file.c",
            "core/lmq.c",
            "core/options.c",
            "core/strs.c",
            "core/stream.c",
            "core/message.c",
            "nng.c",
            "nng_legacy.c",
            "supplemental/util/idhash.c",
            "supplemental/util/options.c",
            "supplemental/tls/tls_common.c",
        },
    });

    // supplemental
    addCSourcesIf(znng_lib, nng_supp_base64, nng_src_path, &.{"supplemental/base64/base64.c"});

    defineCMacroIf(znng_lib, nng_supp_http, "NNG_SUPP_HTTP");
    addCSourcesIf(znng_lib, nng_supp_http, nng_src_path, &.{
        "supplemental/http/http_client.c",
        "supplemental/http/http_chunk.c",
        "supplemental/http/http_conn.c",
        "supplemental/http/http_msg.c",
        "supplemental/http/http_public.c",
        "supplemental/http/http_schemes.c",
        "supplemental/http/http_server.c",
    });

    addCSourcesIf(znng_lib, nng_supp_sha1, nng_src_path, &.{"supplemental/sha1/sha1.c"});

    if (nng_tls_engine != .none or nng_supp_tls) {
        std.debug.print("tls not yet supported.\n", .{});
        return Unsupported.Tls;
    }

    addCSourcesIf(znng_lib, nng_supp_websocket, nng_src_path, &.{
        "supplemental/websocket/websocket.c",
    });
    addCSourcesIf(znng_lib, !nng_supp_websocket, nng_src_path, &.{
        "supplemental/websocket/stub.c",
    });

    // protocols
    defineCMacroIf(znng_lib, nng_proto_bus0, "NNG_HAVE_BUS0");
    addCSourcesIf(znng_lib, nng_proto_bus0, nng_src_path, &.{"sp/protocol/bus0/bus.c"});

    defineCMacroIf(znng_lib, nng_proto_pair0, "NNG_HAVE_PAIR0");
    addCSourcesIf(znng_lib, nng_proto_pair0, nng_src_path, &.{
        "sp/protocol/pair0/pair.c",
    });

    defineCMacroIf(znng_lib, nng_proto_pair1, "NNG_HAVE_PAIR1");
    addCSourcesIf(znng_lib, nng_proto_pair1, nng_src_path, &.{
        "sp/protocol/pair1/pair.c",
        "sp/protocol/pair1/pair1_poly.c",
    });

    defineCMacroIf(znng_lib, nng_proto_push0, "NNG_HAVE_PUSH0");
    addCSourcesIf(znng_lib, nng_proto_push0, nng_src_path, &.{
        "sp/protocol/pipeline0/push.c",
    });

    defineCMacroIf(znng_lib, nng_proto_pull0, "NNG_HAVE_PULL0");
    addCSourcesIf(znng_lib, nng_proto_pull0, nng_src_path, &.{
        "sp/protocol/pipeline0/pull.c",
    });

    defineCMacroIf(znng_lib, nng_proto_pub0, "NNG_HAVE_PUB0");
    addCSourcesIf(znng_lib, nng_proto_pub0, nng_src_path, &.{
        "sp/protocol/pubsub0/pub.c",
    });

    defineCMacroIf(znng_lib, nng_proto_sub0, "NNG_HAVE_SUB0");
    addCSourcesIf(znng_lib, nng_proto_sub0, nng_src_path, &.{
        "sp/protocol/pubsub0/sub.c",
        "sp/protocol/pubsub0/xsub.c",
    });

    defineCMacroIf(znng_lib, nng_proto_req0, "NNG_HAVE_REQ0");
    addCSourcesIf(znng_lib, nng_proto_req0, nng_src_path, &.{
        "sp/protocol/reqrep0/xreq.c",
        "sp/protocol/reqrep0/req.c",
    });

    defineCMacroIf(znng_lib, nng_proto_rep0, "NNG_HAVE_REP0");
    addCSourcesIf(znng_lib, nng_proto_rep0, nng_src_path, &.{
        "sp/protocol/reqrep0/rep.c",
        "sp/protocol/reqrep0/xrep.c",
    });

    defineCMacroIf(znng_lib, nng_proto_respondent0, "NNG_HAVE_RESPONDENT0");
    addCSourcesIf(znng_lib, nng_proto_respondent0, nng_src_path, &.{
        "sp/protocol/survey0/respond.c",
        "sp/protocol/survey0/xrespond.c",
    });

    defineCMacroIf(znng_lib, nng_proto_surveyor0, "NNG_HAVE_SURVEYOR0");
    addCSourcesIf(znng_lib, nng_proto_surveyor0, nng_src_path, &.{
        "sp/protocol/survey0/survey.c",
        "sp/protocol/survey0/xsurvey.c",
    });

    // transports
    defineCMacroIf(znng_lib, nng_transport_inproc, "NNG_TRANSPORT_INPROC");
    addCSourcesIf(znng_lib, nng_transport_inproc, nng_src_path, &.{"sp/transport/inproc/inproc.c"});

    defineCMacroIf(znng_lib, nng_transport_ipc, "NNG_TRANSPORT_IPC");
    addCSourcesIf(znng_lib, nng_transport_ipc, nng_src_path, &.{"sp/transport/ipc/ipc.c"});

    defineCMacroIf(znng_lib, nng_transport_tcp, "NNG_TRANSPORT_TCP");
    addCSourcesIf(znng_lib, nng_transport_tcp, nng_src_path, &.{"sp/transport/tcp/tcp.c"});

    defineCMacroIf(znng_lib, nng_transport_tls, "NNG_TRANSPORT_TLS");
    addCSourcesIf(znng_lib, nng_transport_tls, nng_src_path, &.{"sp/transport/tls/tls.c"});

    const nng_ws_on = nng_transport_ws or nng_transport_ws;
    defineCMacroIf(znng_lib, nng_ws_on, "NNG_TRANSPORT_WS");
    defineCMacroIf(znng_lib, nng_ws_on, "NNG_TRANSPORT_WSS");
    addCSourcesIf(znng_lib, nng_ws_on, nng_src_path, &.{"sp/transport/ws/websocket.c"});

    defineCMacroIf(znng_lib, nng_transport_fdc, "NNG_TRANSPORT_FDC");
    addCSourcesIf(znng_lib, nng_transport_fdc, nng_src_path, &.{"sp/transport/socket/sockfd.c"});
    // const nng_transport_zerotier = b.option(bool, "NNG_TRANSPORT_ZEROTIER", "Enable ZeroTier transport (requires libzerotiercore).") orelse false;

    const tag = target.result.os.tag;
    if (tag == .windows) {
        znng_lib.defineCMacro("NNG_PLATFORM_WINDOWS", null);

        znng_lib.addCSourceFiles(.{ .root = nng_src_path, .files = &.{
            "platform/windows/win_tcpdial.c",
            "platform/windows/win_udp.c",
            "platform/windows/win_ipcdial.c",
            "platform/windows/win_debug.c",
            "platform/windows/win_pipe.c",
            "platform/windows/win_rand.c",
            "platform/windows/win_thread.c",
            "platform/windows/win_ipcconn.c",
            "platform/windows/win_sockaddr.c",
            "platform/windows/win_ipclisten.c",
            "platform/windows/win_tcpconn.c",
            "platform/windows/win_socketpair.c",
            "platform/windows/win_tcplisten.c",
            "platform/windows/win_file.c",
            "platform/windows/win_io.c",
            "platform/windows/win_clock.c",
            "platform/windows/win_resolv.c",
            "platform/windows/win_tcp.c",
        } });
    } else {
        // we can set stack size
        const nng_stack_size = b.option(bool, "NNG_SETSTACKSIZE", "Use rlimit for thread stack size.") orelse false;
        defineCMacroIf(znng_lib, nng_stack_size, "NNG_SETSTACKSIZE");
        znng_lib.defineCMacro("NNG_PLATFORM_POSIX", null);

        // TODO: other defines from nng cmake

        if (tag == .macos) {
            znng_lib.defineCMacro("NNG_PLATFORM_DARWIN", null);
        }
        if (tag == .linux) {
            znng_lib.defineCMacro("NNG_PLATFORM_LINUX", null);
            znng_lib.defineCMacro("NNG_USE_EVENTFD", null);
            znng_lib.defineCMacro("NNG_HAVE_ABSTRACT_SOCKETS", null);
        }
        // TODO: support other systems

        znng_lib.addCSourceFiles(.{ .root = nng_src_path, .files = &.{
            "platform/posix/posix_peerid.c",
            "platform/posix/posix_rand_urandom.c",
            "platform/posix/posix_clock.c",
            "platform/posix/posix_pollq_kqueue.c",
            "platform/posix/posix_alloc.c",
            "platform/posix/posix_resolv_gai.c",
            "platform/posix/posix_pollq_epoll.c",
            "platform/posix/posix_pollq_port.c",
            "platform/posix/posix_file.c",
            "platform/posix/posix_ipcdial.c",
            "platform/posix/posix_ipclisten.c",
            "platform/posix/posix_udp.c",
            "platform/posix/posix_tcpdial.c",
            "platform/posix/posix_tcplisten.c",
            "platform/posix/posix_rand_getrandom.c",
            "platform/posix/posix_rand_arc4random.c",
            "platform/posix/posix_thread.c",
            "platform/posix/posix_sockaddr.c",
            "platform/posix/posix_pollq_poll.c",
            "platform/posix/posix_pipe.c",
            "platform/posix/posix_sockfd.c",
            "platform/posix/posix_tcpconn.c",
            "platform/posix/posix_debug.c",
            "platform/posix/posix_ipcconn.c",
            "platform/posix/posix_socketpair.c",
            "platform/posix/posix_atomic.c",
        } });
    }
    znng_lib.linkLibC();

    b.installArtifact(znng_lib);

    const exe = b.addExecutable(.{
        .name = "reqrep",
        .root_source_file = b.path("demo/reqrep/reqrep.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(znng_lib);
    // If I add wrappers around the nng stuff in zig then this shouldn't be needed?
    exe.addIncludePath(nng_include_path);
    b.installArtifact(exe);

    // TODO: figure out how to build demos separately, for now this will do

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const lib_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    //
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    //
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);
}

fn defineCMacroIf(c: *std.Build.Step.Compile, condition: bool, option: []const u8) void {
    if (condition) {
        c.defineCMacro(option, null);
    }
}

fn addCSourcesIf(c: *std.Build.Step.Compile, condition: bool, root: std.Build.LazyPath, files: []const []const u8) void {
    if (condition) {
        c.addCSourceFiles(.{
            .root = root,
            .files = files,
        });
    }
}

fn buildDemos(b: *std.Build, znng: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const reqrep = b.addExecutable(.{
        .name = "reqrep",
        .root_source_file = b.path("demo/reqrep/reqrep.zig"),
        .target = target,
        .optimize = optimize,
    });
    reqrep.linkLibrary(znng);
    reqrep.addIncludePath(b.path("nng/include"));
    b.installArtifact(reqrep);
}
