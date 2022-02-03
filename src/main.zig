const std = @import("std");

const Subleq = struct {
    pc: usize = 0,
    ram: []u8 = undefined,
    options: Options,

    pub const Options = struct {
        mem_size: usize = 1024 * 1024, // 1 MB
        endian: std.builtin.Endian = .Big, // Big endian by default
        address_size: AddrSize = .@"64", // 64-bit addresses

        pub const AddrSize = enum(u4) {
            @"8" = 1,
            @"16" = 2,
            @"32" = 4,
            @"64" = 8,

            pub fn getBytes(addr: AddrSize) u4 {
                return @enumToInt(addr);
            }
        };
    };

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
        if (@enumToInt(options.address_size) > @sizeOf(usize))
            return error.UnsupportedCpu;

        return Self{
            .ram = try allocator.alloc(u8, options.mem_size),
            .options = options,
        };
    }

    pub fn loadProgram(self: Self, prog: []const u8, loc: usize) void {
        std.mem.copy(u8, self.ram[loc..prog.len], prog);
    }

    fn readInt(self: *Self, comptime T: type, mem: []const u8) T {
        return std.mem.readIntSlice(T, mem, self.options.endian);
    }

    fn getMem(self: *Self, pc: usize) usize {
        const mem = self.ram[pc .. pc + self.options.address_size.getBytes()];
        return switch (self.options.address_size) {
            .@"8" => self.readInt(u8, mem),
            .@"16" => self.readInt(u16, mem),
            .@"32" => self.readInt(u32, mem),
            .@"64" => self.readInt(u64, mem),
        };
    }

    fn operandAccess(self: *Self, accum: *u32) usize {
        const num = self.getMem(self.pc + accum.*);
        accum.* += self.options.address_size.getBytes();
        return @intCast(usize, num);
    }

    pub fn exec(self: *Self, entry_point: usize) usize {
        const address_bytes = self.options.address_size.getBytes();

        self.pc = entry_point;
        while (self.pc + (3 * address_bytes) <= self.ram.len) {
            var accum: u32 = 0;
            const a = self.operandAccess(&accum);
            const b = self.operandAccess(&accum);
            const c = self.operandAccess(&accum);

            const a_mem = @intCast(isize, self.ram[a]);
            const b_mem = @intCast(isize, self.ram[b]);

            const result = b_mem - a_mem;
            if (result <= 0) {
                if (@bitCast(i8, @intCast(u8, c)) < 0)
                    return self.pc + (2 * address_bytes);

                self.pc = @intCast(usize, c);
            } else {
                self.pc += 3 * address_bytes;
            }

            self.ram[b] = @truncate(u8, @bitCast(usize, result));
        }
        return self.pc;
    }
};

pub fn main() anyerror!void {
    const prog = &.{
        // subleq2 a, b (a=2, b=3)
        // 1, 2, 3,

        // jmp a (a=2)
        // 0, 0, 2

        0, 0, // ZERO and ACCUM
        10, 20, // DATA 2 and 3
        3, 2, 255, // INST subleq 3, 2, 255_u8 == -1_i8
    };
    var sl = try Subleq.init(std.heap.page_allocator, .{ .address_size = .@"8" });
    sl.loadProgram(prog, 0);
    const pc = sl.exec(4);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("pc: {}\n", .{pc});

    std.log.info("All your instructions are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
