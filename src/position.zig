const std = @import("std");
const types = @import("types.zig");

const Bitboard = types.Bitboard;
const Color = types.Color;
const Direction = types.Direction;
const File = types.File;
const Move = types.Move;
const Piece = types.Piece;
const PieceType = types.PieceType;
const Rank = types.Rank;
const Square = types.Square;

const CastleInfo = enum(u4) {
    none,
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

    pub inline fn index(self: CastleInfo) u4 {
        return @intFromEnum(self);
    }

    pub inline fn indexLsb(self: CastleInfo) u4 {
        return types.lsb(@intFromEnum(self));
    }
};

pub const State = packed struct {
    turn: Color = Color.white,
    castle_info: CastleInfo = CastleInfo.KQkq,
    rule_fifty: u6 = 0,
    repetition: i7 = 0, // Zero if no repetition, x positive if happened once x half moves ago, negative indicates repetition
    en_passant: Square = Square.none,
    last_captured_piece: PieceType = PieceType.none,
    material_key: u64 = 0,
    previous: *State = undefined,
};

pub const Position = struct {
    // Board
    board: [types.board_size2]Piece = undefined,

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

        @memset(pos.board[0..types.board_size2], Piece.none);
        pos.state = state;

        return pos;
    }

    inline fn remove(self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = p;
        const removeFilter: Bitboard = ~sq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] &= removeFilter;
        self.bb_colors[@intFromEnum(p.pieceToColor())] &= removeFilter;
        // update zobrist
    }

    inline fn add(self: *Position, p: Piece, sq: Square) void {
        self.board[sq.index()] = p;
        const addFilter: Bitboard = sq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] |= addFilter;
        self.bb_colors[@intFromEnum(p.pieceToColor())] |= addFilter;
        // update zobrist
    }

    inline fn removeAdd(self: *Position, p: Piece, removeSq: Square, addSq: Square) void {
        self.board[removeSq.index()] = Piece.none;
        self.board[addSq.index()] = p;
        const removeFilter: Bitboard = removeSq.sqToBB() | addSq.sqToBB();
        self.bb_pieces[p.pieceToPieceType().index()] ^= removeFilter;
        self.bb_colors[@intFromEnum(p.pieceToColor())] ^= removeFilter;
        // update zobrist
    }

    pub inline fn movePiece(self: *Position, move: Move, state: *State) !void {
        // Reset data and set as previous
        state.castle_info = self.state.castle_info;
        // Increment ply counters. In particular, rule_fifty will be reset to zero later on in case of a capture or a pawn move.
        state.rule_fifty = self.state.rule_fifty + 1;
        state.en_passant = Square.none;
        state.material_key = self.state.material_key;
        state.last_captured_piece = PieceType.none;
        state.previous = self.state;
        self.state = state;

        const from: Square = move.getFrom();
        const to: Square = move.getTo();
        const from_piece: Piece = self.board[from.index()];
        const to_piece: Piece = self.board[to.index()];

        if (from_piece == Piece.none) {
            return error.MoveNone;
        }

        // Remove last enPassant
        if (state.previous.en_passant != Square.none) {
            // self.state.material_key ^= Zobrist::enPassant[Board::column(m_board->enPassant())];
            self.state.en_passant = Square.none;
        }

        switch (from_piece.pieceToPieceType()) {
            // Disable castle if king/rook is moved
            PieceType.king => {
                if (from_piece.pieceToColor() == Color.white) {
                    if (self.state.previous.castle_info.index() & CastleInfo.K.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[0];
                    }
                    if (self.state.previous.castle_info.index() & CastleInfo.Q.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[1];
                    }
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.KQ.index());
                } else {
                    if (self.state.previous.castle_info.index() & CastleInfo.k.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[2];
                    }
                    if (self.state.previous.castle_info.index() & CastleInfo.q.index() > 0) {
                        // self.state.material_key ^= ~Zobrist.caslting[3];
                    }
                    self.state.castle_info = @enumFromInt(self.state.castle_info.index() & ~CastleInfo.kq.index());
                }
            },
            PieceType.rook => {
                const is_white = from_piece.pieceToColor() == Color.white;
                if (move.getFrom().file() == File.fh) {
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.K else CastleInfo.k) > 0) {
                        self.state.castle_info &= ~(if (is_white) CastleInfo.K.index() else CastleInfo.k.index());
                        // self.state.material_key ^= ~Zobrist.caslting[if (is_white) CastleInfo.K else CastleInfo.k) > 0];
                    }
                } else if (move.getFrom().file() == File.fa) {
                    if (self.state.castle_info.index() & (if (is_white) CastleInfo.Q else CastleInfo.q) > 0) {
                        self.state.castle_info &= ~(if (is_white) CastleInfo.Q.index() else CastleInfo.q.index());
                        // self.state.material_key ^= ~Zobrist.caslting[if (is_white) CastleInfo.Q else CastleInfo.q) > 0];
                    }
                }
            },
            PieceType.pawn => {},
            else => {},
        }

        if (move.isCapture()) {
            if (to_piece == PieceType.none) {
                return error.CaptureNone;
            } else {
                // This should be the quickest to disable castle when rook is taken
                const castleRemove: CastleInfo = switch (to) {
                    0 => CastleInfo.K,
                    types.board_size - 1 => CastleInfo.Q,
                    types.board_size2 - types.board_size => CastleInfo.k,
                    types.board_size2 - 1 => CastleInfo.q,
                    else => CastleInfo.none,
                };

                if (CastleInfo.none != CastleInfo.none and (self.state.castle_info.index() | castleRemove.index())) {
                    self.state.castle_info &= ~castleRemove;
                    // self.state.material_key ^= ~Zobrist.caslting[castleRemove.indexLsb()];
                }

                self.state.last_captured_piece = to_piece;

                // Remove captured
                self.remove(to_piece, move.to);

                // Reset rule 50 counter
                self.state.rule_fifty = 0;
            }
        }

        // Add
        self.removeAdd(from_piece, from, to);

        self.state.turn = self.state.turn.invert();
        // self.state.material_key ^= Zobrist.side;

        // If castling we move the rook as well
        switch (move.getFlags()) {
            types.MoveFlags.OO => {
                var tmp: State = State{};
                state = self.state;
                self.movePiece(Move{ .flags = 0, .from = from + 3, .to = from + 3 - 2 }, &tmp); // CHESS 960 BUG
                // We have moved, we need to set the turn back
                self.state = &state;
            },
            types.MoveFlags.OOO => {
                var tmp: State = State{};
                state = self.state;
                self.movePiece(Move{ .flags = 0, .from = from - 4, .to = from - 4 + 3 }, &tmp); // CHESS 960 BUG
                // We have moved, we need to set the turn back
                self.state = &state;
            },
            else => {},
        }

        self.state.repetition = 0;
        if (self.state.rule_fifty >= 0) {
            var s2: *State = self.state.previous.previous; // BUG when loading from fen with rule_fifty
            var i: i7 = 4;
            while (i <= self.state.rule_fifty) : (i += 2) {
                s2 = s2.previous.previous;
                if (s2.material_key == self.state.material_key) {
                    self.state.repetition = if (s2.repetition != 0) -i else i;
                    break;
                }
            }
        }
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

        std.debug.print("{s} to move\n", .{if (self.state.turn == Color.white) "White" else "Black"});

        var buffer: [90]u8 = undefined;
        var alloc = std.heap.FixedBufferAllocator.init(&buffer);
        var arena = std.heap.ArenaAllocator.init(alloc.allocator());
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
        try fen.append(' ');
        try fen.append(if (self.state.turn == Color.white) 'w' else 'b');
        try fen.append(' ');
        if ((self.state.castle_info.index() | CastleInfo.K.index()) > 0)
            try fen.append('K');
        if ((self.state.castle_info.index() | CastleInfo.Q.index()) > 0)
            try fen.append('Q');
        if ((self.state.castle_info.index() | CastleInfo.k.index()) > 0)
            try fen.append('k');
        if ((self.state.castle_info.index() | CastleInfo.q.index()) > 0)
            try fen.append('q');

        try fen.append(' ');
        if (self.state.en_passant == Square.none) {
            try fen.append('-');
        } else {
            try fen.appendSlice(types.square_to_string[self.state.en_passant.index()]);
        }

        try fen.append(' ');
        try fen.appendSlice(try std.fmt.allocPrint(allocator, "{d}", .{self.state.rule_fifty}));

        return fen.items;
    }

    pub fn setFen(state: *State, fen: []const u8) Position {
        var pos: Position = Position.new(state);
        var sq: i32 = @intCast(@intFromEnum(Square.a8));
        var tokens = std.mem.tokenizeScalar(u8, fen, ' ');
        const bd = tokens.next().?;
        for (bd) |ch| {
            if (std.ascii.isDigit(ch)) {
                sq += @as(i32, ch - '0') * @intFromEnum(Direction.east);
            } else if (ch == '/') {
                sq += @intFromEnum(Direction.south) * 2;
            } else {
                pos.add(@enumFromInt(first_index(types.PieceNotation, ch).?), @enumFromInt(sq));
                sq += 1;
            }
        }

        const turn = tokens.next().?;
        if (std.mem.eql(u8, turn, "w")) {
            pos.state.turn = Color.white;
        } else {
            pos.state.turn = Color.black;
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
