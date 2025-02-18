const std = @import("std");
const types = @import("types.zig");

const Square = types.Square;
const Piece = types.Piece;
const PieceType = types.PieceType;
const Color = types.Color;
const Bitboard = types.Bitboard;

const CastleInfo = enum(u4) {
    None,
    q,
    k,
    kq,
    Q,
    Qq,
    Qk,
    Qkq,
    K,
    Kq,
    Kk,
    Kkq,
    KQ,
    KQq,
    KQk,
    KQkq,
};

pub const State = packed struct {
    turn: Color = Color.white,
    castle_info: CastleInfo = CastleInfo.KQkq,
    rule50: u6 = 0,
    repetition: i7 = 0, // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
    en_passant: Square = Square.none,
    last_captured_piece: PieceType = types.PieceType.none,
    material_key: u64 = 0,
    previous: *State = undefined,
};

pub const Position = struct {
    // Board
    board: [types.board_size2]types.Piece = undefined,

    // Bitboards
    bb_pieces: [PieceType.nb.index()]Bitboard = undefined,
    bb_colors: [2]Bitboard = undefined,

    // Current player
    // turn: Color = Color.white,

    // Ply since game started
    game_ply: u32 = 0,

    // Zobrist Hash
    zobrist: u64 = 0,

    state: *State = undefined,

    pub fn new(state: *State) Position {
        var pos = Position{};

        @memset(pos.board[0..types.board_size2], types.Piece.none);
        pos.state = state;

        return pos;
    }

    fn remove(self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = p;
        const removeFilter: Bitboard = ~sq.sqToBB();
        self.bb_pieces[p.indexType()] &= removeFilter;
        self.bb_colors[@intFromBool(p.index() > 6)] &= removeFilter;
    }

    fn add(self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = p;
        const addFilter: Bitboard = sq.sqToBB();
        self.bb_pieces[p.indexType()] |= addFilter;
        self.bb_colors[@intFromBool(p.index() > 6)] |= addFilter;
    }

    fn removeAdd(self: *Position, p: Piece, removeSq: Square, addSq: Square) void {
        self.board[removeSq.index()] = Piece.none;
        self.board[addSq.index()] = p;
        const removeFilter: Bitboard = removeSq.sqToBB() | addSq.sqToBB();
        self.bb_pieces[p.indexType()] ^= removeFilter;
        self.bb_colors[@intFromBool(p.index() > 6)] ^= removeFilter;
    }

    pub fn debugPrint(self: Position) void {
        const line = " +---+---+---+---+---+---+---+---+\n";
        const letters = "   A   B   C   D   E   F   G   H\n";
        var i: i32 = 56;
        while (i >= 0) : (i -= 8) {
            std.debug.print("{s} ", .{line});
            var j: i32 = 0;
            while (j < 8) : (j += 1) {
                std.debug.print("| {c} ", .{types.PieceNotation[self.board[@intCast(i + j)].index()]});
            }
            std.debug.print("| {}\n", .{@divTrunc(i, 8) + 1});
        }
        std.debug.print("{s}", .{line});
        std.debug.print("{s}\n", .{letters});

        std.debug.print("{s} to move\n", .{if (self.state.turn == types.Color.white) "White" else "Black"});

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        if (self.getFen(allocator)) |fen| {
            std.debug.print("fen: {s}\n", .{fen});
        } else |_| {
            std.debug.print("err reading fen\n", .{});
        }
        std.debug.print("zobrist: {}\n", .{self.zobrist});
    }

    /// Find char c in arr
    fn first_index(arr: []const u8, c: u8) ?usize {
        for (0..arr.len) |i| {
            if (arr[i] == c) {
                return i;
            }
        }
        return null;
    }

    pub fn getFen(self: *const Position, allocator: std.mem.Allocator) ![]const u8 {
        var fen = std.ArrayList(u8).init(allocator);
        var i: i32 = 56;
        while (i >= 0) : (i -= 8) {
            var blank_counter: u8 = 0;
            var j: i32 = 0;
            while (j < 8) : (j += 1) {
                const idx = self.board[@intCast(i + j)].index();
                if (idx == 0) {
                    blank_counter += 1;
                } else {
                    try fen.append(types.PieceNotation[idx]);
                }
            }
            if (blank_counter != 0) {
                try fen.append('0' + blank_counter);
            }
            if (i - 8 >= 0) {
                try fen.append('/');
            }
        }
        return fen.items;
    }

    pub fn setFen(state: *State, fen: []const u8) Position {
        var pos: Position = Position.new(state);
        var sq: i32 = @intCast(@intFromEnum(types.Square.a8));
        var tokens = std.mem.tokenize(u8, fen, " ");
        const bd = tokens.next().?;
        for (bd) |ch| {
            if (std.ascii.isDigit(ch)) {
                sq += @as(i32, ch - '0') * @intFromEnum(types.Direction.east);
            } else if (ch == '/') {
                sq += @intFromEnum(types.Direction.south) * 2;
            } else {
                pos.add(@enumFromInt(first_index(types.PieceNotation, ch).?), @enumFromInt(sq));
                sq += 1;
            }
        }

        const turn = tokens.next().?;
        if (std.mem.eql(u8, turn, "w")) {
            pos.state.turn = types.Color.white;
        } else {
            pos.state.turn = types.Color.black;
            // pos.hash ^= zobrist.TurnHash;
        }

        // pos.history[pos.game_ply].entry = types.AllCastlingMask;
        const castle = tokens.next().?;
        for (castle) |ch| {
            switch (ch) {
                'K' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.K));
                },
                'Q' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.Q));
                },
                'k' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.k));
                },
                'q' => {
                    pos.state.castle_info = @enumFromInt(@intFromEnum(pos.state.castle_info) | @intFromEnum(CastleInfo.q));
                },
                else => {},
            }
        }

        const ep = tokens.next().?;
        if (ep.len == 2) {
            for (types.square_to_string, 0..) |sq_str, i| {
                if (std.mem.eql(u8, ep, sq_str)) {
                    pos.state.en_passant = @enumFromInt(i);
                    // self.hash ^= zobrist.EnPassantHash[types.file_plain(i)];
                    break;
                }
            }
        }
        return pos;
    }
};
