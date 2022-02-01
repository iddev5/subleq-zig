const std = @import("std");

const Subleq = struct {
    pc: usize = 0,
    ram: []i8 = undefined,

    const Self = @This();
    pub fn init(allocator: std.mem.Allocator, prog: []const i8) !Self {
        var sl = Self{ .ram = try allocator.alloc(i8, prog.len) };
        std.mem.copy(i8, sl.ram, prog);
        return sl;
    }

    pub fn exec(self: *Self, entry_point: usize) void {
        self.pc = entry_point;
        while (self.pc + 2 <= self.ram.len) {
            const a = @intCast(usize, self.ram[self.pc]);
            const b = @intCast(usize, self.ram[self.pc + 1]);
            const c = @intCast(usize, self.ram[self.pc + 2]);

            self.ram[b] = self.ram[b] - self.ram[a];
            if (self.ram[b] <= 0) {
                self.pc = c;
                continue;
            }

            self.pc += 3;
        }
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
        3, 2, 6, // INST subleq 3, 2, 6
    };
    var sl = try Subleq.init(std.heap.page_allocator, prog);
    sl.exec(3);

    const stdout = std.io.getStdOut().writer();
    try stdout.print("pc: {}\n", .{sl.pc});

    std.log.info("All your instructions are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
