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
        std.debug.print("fen: {s}\n", .{""});
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

    pub fn setFen(self: *Position, fen: []const u8) void {
        var sq: i32 = @intCast(@intFromEnum(types.Square.a8));
        var tokens = std.mem.tokenize(u8, fen, " ");
        const bd = tokens.next().?;
        for (bd) |ch| {
            if (std.ascii.isDigit(ch)) {
                sq += @as(i32, ch - '0') * @intFromEnum(types.Direction.east);
            } else if (ch == '/') {
                sq += @intFromEnum(types.Direction.south) * 2;
            } else {
                self.add(@enumFromInt(first_index(types.PieceNotation, ch).?), @enumFromInt(sq));
                sq += 1;
            }
        }

        const turn = tokens.next().?;
        if (std.mem.eql(u8, turn, "w")) {
            self.state.turn = types.Color.white;
        } else {
            self.state.turn = types.Color.black;
            // self.hash ^= zobrist.TurnHash;
        }

        // self.history[self.game_ply].entry = types.AllCastlingMask;
        const castle = tokens.next().?;
        for (castle) |ch| {
            switch (ch) {
                'K' => {
                    self.state.castle_info = @enumFromInt(@intFromEnum(self.state.castle_info) | @intFromEnum(CastleInfo.K));
                },
                'Q' => {
                    self.state.castle_info = @enumFromInt(@intFromEnum(self.state.castle_info) | @intFromEnum(CastleInfo.Q));
                },
                'k' => {
                    self.state.castle_info = @enumFromInt(@intFromEnum(self.state.castle_info) | @intFromEnum(CastleInfo.k));
                },
                'q' => {
                    self.state.castle_info = @enumFromInt(@intFromEnum(self.state.castle_info) | @intFromEnum(CastleInfo.q));
                },
                else => {},
            }
        }

        const ep = tokens.next().?;
        if (ep.len == 2) {
            for (types.square_to_string, 0..) |sq_str, i| {
                if (std.mem.eql(u8, ep, sq_str)) {
                    self.state.en_passant = @enumFromInt(i);
                    // self.hash ^= zobrist.EnPassantHash[types.file_plain(i)];
                    break;
                }
            }
        }
    }
};
