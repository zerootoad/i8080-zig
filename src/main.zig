const std = @import("std");
const icpu = @import("i8080/cpu.zig");
const instruct = @import("i8080/instructions.zig");

pub fn main() !void {
    var cpu = icpu.CPU.new();

    cpu.mem[0] = 0x01;
    cpu.mem[1] = 0x34;
    cpu.mem[2] = 0x12;
    cpu.mem[3] = 0x02;
    cpu.mem[4] = 0x04;
    cpu.mem[5] = 0x14;
    cpu.mem[6] = 0x24;
    cpu.mem[7] = 0x34;
    cpu.mem[8] = 0x07;
    cpu.mem[9] = 0x17;
    cpu.mem[10] = 0x37;
    cpu.mem[11] = 0x0F;
    cpu.mem[12] = 0x1F;

    //try cpu.load("src/roms/8080EXM.COM");
    std.debug.print("Initial PC: PC = {X}\n\n", .{cpu.regs.pc});

    for (0..13) |_| {
        cpu.cycle();
        cpu_state(&cpu);
    }
}

fn cpu_state(cpu: *icpu.CPU) void {
    std.debug.print("Registers: PC = {}, SP = {}, A = {X}, BC = {X}, DE = {X}, HL = {X}\n", .{ cpu.regs.pc, cpu.regs.sp, cpu.regs.a, cpu.get_bc(), cpu.get_de(), cpu.get_hl() });

    std.debug.print("Flags: Z = {}, S = {}, P = {}, AC = {}, CY = {}\n", .{ cpu.flags.z, cpu.flags.s, cpu.flags.p, cpu.flags.ac, cpu.flags.cy });

    std.debug.print("Memory Dump: ", .{});
    for (0..16) |i| {
        std.debug.print("{X} ", .{cpu.mem[i]});
    }
    std.debug.print("\n\n", .{});
}
