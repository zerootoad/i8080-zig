const std = @import("std");
const icpu = @import("i8080/cpu.zig");
const instruct = @import("i8080/instructions.zig");

pub fn main() !void {
    var cpu = icpu.CPU.new();

    cpu.mem[0] = 0x01;
    cpu.mem[1] = 0x34;
    cpu.mem[2] = 0x12; // LXI B, 0x1234
    cpu.mem[3] = 0x02; // STAX B
    cpu.mem[4] = 0x04; // INR B
    cpu.mem[5] = 0x14; // INR D
    cpu.mem[6] = 0x24; // INR H
    cpu.mem[7] = 0x34; // INR (HL)

    //try cpu.load("src/roms/8080EXM.COM");
    std.debug.print("Initial program counter: PC = {x}\n", .{cpu.regs.pc});

    for (0..6) |_| {
        cpu.cycle();
        std.debug.print("After execution: PC = {x}\n", .{cpu.regs.pc});
        std.debug.print("BC register pair: {x}\n", .{cpu.get_bc()});
    }
}
