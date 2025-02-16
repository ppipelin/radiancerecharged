const std = @import("std");
const types = @import("types.zig");

const Square = types.Square;
const Piece = types.Piece;
const PieceType = types.PieceType;
const Color = types.Color;
const Bitboard = types.Bitboard;

const castle_info = enum(u4) {
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

pub const StateInfo = packed struct {
    turn: Color = Color.white,
    castle_info: castle_info = 0b1111,
    rule50: u6 = 0,
    repetition: i7 = 0, // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
    en_passant: u8 = -1,
    last_captured_piece: PieceType = types.PieceType.none,
    material_key: u64 = 0,
    previous: *StateInfo = undefined,
};

pub const Position = struct {
    // Board
    board: [types.board_size2]types.Piece = undefined,

    // Bitboards
    bb_pieces: [PieceType.nb.index()]Bitboard = undefined,
    bb_colors: [Color.nb.index()]Bitboard = undefined,

    // Current player
    turn: Color = Color.white,

    // Ply since game started
    game_ply: u32 = 0,

    // Zobrist Hash
    zobrist: u64 = 0,

    state: StateInfo = undefined,

    pub fn new() Position {
        var pos = Position{};

        std.mem.set(types.Piece, pos.board[0..types.board_size2], types.Piece.no_piece);
        pos.history[0] = StateInfo{};

        return pos;
    }

    fn remove(p: Piece, tile: Square) void {
        const removeFilter: Bitboard = ~Bitboard.tile_to_bb(tile);
        Position.bb_pieces[p.index()] &= removeFilter;
        Position.bb_colors[@intFromBool(p.index() > 6)] &= removeFilter;
    }

    fn add(p: Piece, tile: Square) void {
        const addFilter: Bitboard = Bitboard.tile_to_bb(tile);
        Position.bb_pieces[p.index()] |= addFilter;
        Position.bb_colors[@intFromBool(p.index() > 6)] |= addFilter;
    }

    fn removeAdd(p: Piece, removeTile: Square, addTile: Square) void {
        const removeFilter: Bitboard = Bitboard.tile_to_bb(removeTile) | Bitboard.tile_to_bb(addTile);
        Position.bb_pieces[p.index()] ^= removeFilter;
        Position.bb_colors[@intFromBool(p.index() > 6)] ^= removeFilter;
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

        std.debug.print("{s} to move\n", .{if (self.turn == types.Color.white) "White" else "Black"});
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
        self.* = Position.new();
        var sq: i32 = @intCast(@intFromEnum(types.Square.a8));
        var tokens = std.mem.tokenize(u8, fen, " ");
        var bd = tokens.next().?;
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

        var turn = tokens.next().?;
        if (std.mem.eql(u8, turn, "w")) {
            self.turn = types.Color.White;
        } else {
            self.turn = types.Color.Black;
            // self.hash ^= zobrist.TurnHash;
        }

        // self.history[self.game_ply].entry = types.AllCastlingMask;
        var castle = tokens.next().?;
        for (castle) |ch| {
            switch (ch) {
                'K' => {
                    self.history[self.game_ply].entry &= ~types.WhiteOOMask;
                },
                'Q' => {
                    self.history[self.game_ply].entry &= ~types.WhiteOOOMask;
                },
                'k' => {
                    self.history[self.game_ply].entry &= ~types.BlackOOMask;
                },
                'q' => {
                    self.history[self.game_ply].entry &= ~types.BlackOOOMask;
                },
                else => {},
            }
        }

        var ep = tokens.next().?;
        if (ep.len == 2) {
            for (types.square_to_string, 0..) |sq_str, i| {
                if (std.mem.eql(u8, ep, sq_str)) {
                    self.history[self.game_ply].ep_sq = @enumFromInt(types.Square, i);
                    // self.hash ^= zobrist.EnPassantHash[types.file_plain(i)];
                    break;
                }
            }
        }

        self.evaluator.full_refresh(self);
    }
};
