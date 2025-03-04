const interface = @import("interface.zig");
const position = @import("position.zig");
const std = @import("std");
const types = @import("types.zig");

const RootMove = struct {
    score: types.Value = -types.value_infinite,
    previous_score: types.Value = -types.value_infinite,
    average_score: types.Value = -types.value_infinite,
    pv: std.ArrayListUnmanaged(types.Move) = .empty,

    fn sort(context: void, a: RootMove, b: RootMove) bool {
        _ = context;
        if (a.score == b.score)
            return a.previous_score < b.previous_score;

        return a.score < b.score;
    }
};

const Stack = struct {
    pv: [200]types.Move = [_]types.Move{.none} ** 200,
    killers: [2]?types.Move = [_]?types.Move{ null, null },
    moveCount: u16 = 0,
    ply: u16 = 0,
};

inline fn elapsed(limits: interface.Limits) types.TimePoint {
    return (types.now() - limits.start);
}

inline fn outOfTime(limits: interface.Limits) bool {
    if (interface.g_stop)
        return true;
    if (limits.infinite or interface.remaining == 0) return false;

    const remaining_float: f128 = @floatFromInt(interface.remaining);
    const increment_float: f128 = @floatFromInt(interface.increment);
    const remaining_computed: types.TimePoint = @intFromFloat(@min(remaining_float * 0.95, remaining_float / 30.0 + increment_float));
    return elapsed(limits) > remaining_computed;
}

pub fn perft(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, depth: u8, verbose: bool) !u64 {
    var nodes: u64 = 0;
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    if (depth == 0) {
        return 1;
    }

    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

    if (depth == 1)
        return move_list.items.len;

    for (move_list.items) |move| {
        var s: position.State = position.State{};

        try pos.movePiece(move, &s);

        const nodes_number = try (perft(allocator, stdout, pos, depth - 1, false));
        nodes += nodes_number;
        if (verbose) {
            try move.printUCI(stdout);
            try stdout.print(", {} : {}\n", .{ move.getFlags(), nodes_number });
        }

        try pos.unMovePiece(move, false);
    }
    return nodes;
}

pub fn searchRandom(allocator: std.mem.Allocator, pos: *position.Position) !types.Move {
    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);
    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

    if (move_list.items.len == 0)
        return error.MoveAfterCheckmate;
    var prng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();
    const len: u8 = @intCast(move_list.items.len);
    return move_list.items[rand.intRangeAtMost(u8, 0, len - 1)];
}

pub fn iterativeDeepening(allocator: std.mem.Allocator, stdout: anytype, pos: *position.Position, limits: interface.Limits) !types.Move {
    if (limits.movetime > 0) {
        interface.remaining = limits.movetime * 30;
    } else {
        interface.remaining = if (pos.state.turn.isWhite()) limits.time[types.Color.white.index()] else limits.time[types.Color.black.index()];
        interface.increment = if (pos.state.turn.isWhite()) limits.inc[types.Color.white.index()] else limits.inc[types.Color.black.index()];
    }

    var stack: [200 + 10]Stack = [_]Stack{.{}} ** (200 + 10);
    var ss: [*]Stack = &stack;
    ss = ss + 7;

    for (0..200) |i| {
        ss[i + 7].ply = @intCast(i);
    }

    var move_list: std.ArrayListUnmanaged(types.Move) = .empty;
    defer move_list.deinit(allocator);

    pos.generateLegalMoves(allocator, pos.state.turn, &move_list);

    const len = move_list.items.len;
    if (len == 0) {
        return error.Checkmated;
    } else if (len == 1) {
        return move_list.items[0];
    }

    // Order moves

    // limits.searchmoves here

    var root_moves: std.ArrayListUnmanaged(RootMove) = .empty;
    try root_moves.ensureTotalCapacity(allocator, len);
    for (move_list.items) |move| {
        var pv_rm: std.ArrayListUnmanaged(types.Move) = .empty;
        try pv_rm.ensureTotalCapacity(allocator, 200);
        pv_rm.appendAssumeCapacity(move);
        root_moves.appendAssumeCapacity(RootMove{ .pv = pv_rm });
    }

    var current_depth: u8 = 0;
    while (limits.depth == 0 or current_depth <= limits.depth) : (current_depth += 1) {
        // Some variables have to be reset
        for (root_moves.items) |*root_move| {
            root_move.previous_score = root_move.score;
            root_move.score = -types.value_infinite;
        }

        // Reset aspiration window starting size
        const prev: types.Value = root_moves.items[0].average_score;
        var delta: types.Value = @divTrunc(prev, 2) + 10;
        var alpha: types.Value = @max(prev - delta, -types.value_infinite);
        var beta: types.Value = @min(prev + delta, types.value_infinite);
        var failed_high_cnt: types.Value = 0;

        // Aspiration window
        // Disable by alpha = -types.value_infinite; beta = types.value_infinite;
        // alpha = -types.value_infinite; beta = types.value_infinite;
        while (true) {
            // Value score = abSearch<Root>(ss, b, e, alpha, beta, currentDepth);
            const score: types.Value = 35;
            if (current_depth > 1 and outOfTime(limits))
                break;

            // In case of failing low/high increase aspiration window and
            // re-search, otherwise exit the loop.
            if (score <= alpha) {
                beta = @divTrunc(alpha + beta, 2);
                alpha = @max(score - delta, -types.value_infinite);
                failed_high_cnt = 0;
            } else if (score >= beta) {
                beta = @min(score + delta, types.value_infinite);
                failed_high_cnt += 1;
            } else {
                break;
            }

            std.sort.block(RootMove, root_moves.items, {}, RootMove.sort);

            delta += @divTrunc(delta, 3);
        }

        // Even if outofTime we keep a better move if there is one
        std.sort.block(RootMove, root_moves.items, {}, RootMove.sort);

        if (current_depth > 1 and outOfTime(limits)) {
            break;
        }

        try stdout.print("info failedHighCnt {} alpha {} beta {}\n", .{ failed_high_cnt, alpha, beta });
        // std::cout << UCI::pv(*this, currentDepth) << std::endl;
    }

    // Even if outofTime we keep a better move if there is one

    for (root_moves.items) |*root_move| {
        defer root_move.pv.deinit(allocator);
    }

    return root_moves.items[0].pv.items[0];
}
