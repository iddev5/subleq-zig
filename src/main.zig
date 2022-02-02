const std = @import("std");

const Subleq = struct {
    pc: usize = 0,
    ram: []i8 = undefined,

    pub const Options = struct {
        mem_size: usize = 1024 * 1024, // 1 MB
        endian: std.builtin.Endian = .Big,
        address_size: AddrSize = .@"64", // 64-bit addresses

        pub const AddrSize = enum {
            @"16",
            @"32",
            @"64",
        };
    };

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
        return Self{
            .ram = try allocator.alloc(i8, options.mem_size),
        };
    }

    pub fn loadProgram(self: Self, prog: []const i8, loc: usize) void {
        std.mem.copy(i8, self.ram[loc..prog.len], prog);
    }

    pub fn exec(self: *Self, entry_point: usize) usize {
        self.pc = entry_point;
        while (self.pc + 3 <= self.ram.len) {
            const a = @intCast(usize, self.ram[self.pc]);
            const b = @intCast(usize, self.ram[self.pc + 1]);
            const c = self.ram[self.pc + 2];

            self.ram[b] = self.ram[b] - self.ram[a];
            if (self.ram[b] <= 0) {
                if (c < 0) return self.pc + 2;
                self.pc = @intCast(usize, c);
                continue;
            }

            self.pc += 3;
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
        3, 2, -1, // INST subleq 3, 2, 6
    };
    var sl = try Subleq.init(std.heap.page_allocator, .{});
    sl.loadProgram(prog, 0);
    const pc = sl.exec(4);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("pc: {}\n", .{pc});

    std.log.info("All your instructions are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
