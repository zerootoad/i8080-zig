const std = @import("std");
const CPU = @import("cpu.zig").CPU;

fn set_p(cpu: *CPU, val: u8) void {
    var x: u8 = 0;
    for (0..8) |i| {
        x += (val >> @as(u3, @intCast(i))) & 1;
    }

    cpu.flags.p = (x & 1) == 0;
}

fn set_zsp(cpu: *CPU, val: u8) void {
    cpu.flags.z = val == 0;
    cpu.flags.s = (val >> 7) == 1;
    set_p(cpu, val);
}

const Instruction = struct {
    execute: *const fn (*CPU) void,
    size: u8,
    mnemonic: []const u8,
};

pub fn decode(cpu: *CPU) Instruction {
    const opcode = cpu.mem[cpu.regs.pc];

    std.debug.print("Decoding opcode: {x}\n", .{opcode});

    switch (opcode) {
        0x00, 0x10, 0x20, 0x30, 0x08, 0x18, 0x28, 0x38 => return Instruction{ .execute = NOP, .size = 1, .mnemonic = "NOP" },
        0x01, 0x11, 0x21, 0x31 => return Instruction{ .execute = LXI, .size = 3, .mnemonic = "LXI RP, d16" },
        0x02, 0x12 => return Instruction{ .execute = STAX, .size = 1, .mnemonic = "STAX (RP)" },
        0x22 => return Instruction{ .execute = SHLD, .size = 3, .mnemonic = "SHLD a16" },
        0x32 => return Instruction{ .execute = STA, .size = 1, .mnemonic = "STA a16" },
        0x03, 0x13, 0x23, 0x33 => return Instruction{ .execute = INX, .size = 3, .mnemonic = "INX RP" },
        0x04, 0x14, 0x24, 0x34 => return Instruction{ .execute = INR, .size = 1, .mnemonic = "INR RM" },
        0x05, 0x15, 0x25, 0x35 => return Instruction{ .execute = DCR, .size = 1, .mnemonic = "DCR RM" },
        0x06, 0x16, 0x26, 0x36, 0x0E, 0x1E, 0x2E, 0x3E => return Instruction{ .execute = MVI, .size = 2, .mnemonic = "MVI RM, d8" },
        0x07 => return Instruction{ .execute = RLC, .size = 1, .mnemonic = "RLC" },
        0x17 => return Instruction{ .execute = RAL, .size = 1, .mnemonic = "RAL" },
        0x37 => return Instruction{ .execute = STC, .size = 1, .mnemonic = "STC" },
        0x0F => return Instruction{ .execute = RRC, .size = 1, .mnemonic = "RRC" },
        0x1F => return Instruction{ .execute = RAR, .size = 1, .mnemonic = "RAR" },
        else => unreachable,
    }
}

fn NOP(cpu: *CPU) void {
    cpu.regs.pc += 1;
}

fn LXI(cpu: *CPU) void {
    const opcode = cpu.mem[cpu.regs.pc];
    //                                           |       low byte       |                       |      high byte       |
    const data: u16 = @intCast(@as(u16, @intCast(cpu.mem[cpu.regs.pc + 1])) | @as(u16, @intCast(cpu.mem[cpu.regs.pc + 2])) << 8);

    // Explanation on the data fetch:
    // Since our LXI instructions is an 3 bytes instructions which takes |opcode|operand|operand|,
    // if we wanted to fetch the following data being loaded into the register pairs, we would have to fetch the 2 operands which hold our 16bits data.

    switch (opcode) {
        0x01 => cpu.set_bc(data),
        0x11 => cpu.set_de(data),
        0x21 => cpu.set_hl(data),
        0x31 => cpu.regs.sp = data,
        else => unreachable,
    }

    cpu.regs.pc += 3;
}

fn STAX(cpu: *CPU) void {
    const opcode = cpu.mem[cpu.regs.pc];

    switch (opcode) {
        0x02 => {
            const bc = cpu.get_bc();
            cpu.mem[bc] = cpu.regs.a;
        },
        0x12 => {
            const de = cpu.get_de();
            cpu.mem[de] = cpu.regs.a;
        },
        else => unreachable,
    }

    cpu.regs.pc += 1;
}

fn SHLD(cpu: *CPU) void {
    const low_byte: u8 = cpu.mem[cpu.regs.pc + 1];
    const high_byte: u8 = cpu.mem[cpu.regs.pc + 2];

    cpu.regs.l = low_byte;
    cpu.regs.h = high_byte;
    cpu.set_hl(cpu.get_hl());

    cpu.regs.pc += 3;
}

fn MVI(cpu: *CPU) void {
    const opcode = cpu.mem[cpu.regs.pc];
    const low_byte: u8 = cpu.mem[cpu.regs.pc + 1];

    switch (opcode) {
        0x06 => {
            cpu.regs.b = low_byte;
            cpu.set_bc(cpu.get_bc());
        },
        0x0E => {
            cpu.regs.c = low_byte;
            cpu.set_bc(cpu.get_bc());
        },
        0x16 => {
            cpu.regs.d = low_byte;
            cpu.set_de(cpu.get_de());
        },
        0x1E => {
            cpu.regs.e = low_byte;
            cpu.set_de(cpu.get_de());
        },
        0x26 => {
            cpu.regs.h = low_byte;
            cpu.set_hl(cpu.get_hl());
        },
        0x2E => {
            cpu.regs.l = low_byte;
            cpu.set_hl(cpu.get_hl());
        },
        0x36 => cpu.mem[cpu.get_hl()] = low_byte,
        0x3E => cpu.regs.a = low_byte,
        else => unreachable,
    }

    cpu.regs.pc += 2;
}

fn RAL(cpu: *CPU) void {
    const msb = cpu.regs.a & 0x80;
    const carry: u8 = if (cpu.flags.cy) 1 else 0;

    cpu.regs.a = cpu.regs.a << 1 | carry;

    if (msb != 0) cpu.flags.cy = true else cpu.flags.cy = false;
    cpu.regs.pc += 1;
}

fn RAR(cpu: *CPU) void {
    const lsb = cpu.regs.a & 0x01;
    const carry: u8 = if (cpu.flags.cy) 0x80 else 0;

    cpu.regs.a = cpu.regs.a >> 1 | carry;

    if (lsb != 0) cpu.flags.cy = true else cpu.flags.cy = false;

    cpu.regs.pc += 1;
}

fn RLC(cpu: *CPU) void {
    const msb = cpu.regs.a & 0x80; // most significant byte

    cpu.regs.a = cpu.regs.a << 1 | msb >> 7;

    if (msb != 0) cpu.flags.cy = true else cpu.flags.cy = false;
    cpu.regs.pc += 1;
}

fn RRC(cpu: *CPU) void {
    const lsb = cpu.regs.a & 0x01; // least significant byte

    cpu.regs.a = cpu.regs.a >> 1 | lsb << 7;

    if (lsb != 0) cpu.flags.cy = true else cpu.flags.cy = false;
    cpu.regs.pc += 1;
}

fn STC(cpu: *CPU) void {
    cpu.flags.cy = true;
    cpu.regs.pc += 1;
}

fn STA(cpu: *CPU) void {
    const addr: u16 = @intCast(@as(u16, @intCast(cpu.mem[cpu.regs.pc + 1])) | @as(u16, @intCast(cpu.mem[cpu.regs.pc + 2])) << 8);

    cpu.mem[addr] = cpu.regs.a;
    cpu.regs.pc += 3;
}

fn INX(cpu: *CPU) void {
    const opcode = cpu.mem[cpu.regs.pc];

    switch (opcode) {
        0x03 => cpu.set_bc(cpu.get_bc() + 1),
        0x13 => cpu.set_de(cpu.get_de() + 1),
        0x23 => cpu.set_hl(cpu.get_hl() + 1),
        0x33 => cpu.regs.sp += 1,
        else => unreachable,
    }

    cpu.regs.pc += 3;
}

fn INR(cpu: *CPU) void {
    const opcode = cpu.mem[cpu.regs.pc];

    switch (opcode) {
        0x04 => {
            const b = cpu.regs.b + 1;
            cpu.regs.b = b;
            cpu.set_bc(cpu.get_bc());

            set_zsp(cpu, b);
        },
        0x0C => {
            const c = cpu.regs.c + 1;
            cpu.regs.c = c;
            cpu.set_bc(cpu.get_bc());

            set_zsp(cpu, c);
        },
        0x14 => {
            const d = cpu.regs.d + 1;
            cpu.regs.d = d;
            cpu.set_de(cpu.get_de());

            set_zsp(cpu, d);
        },
        0x1C => {
            const e = cpu.regs.e + 1;
            cpu.regs.e = e;
            cpu.set_de(cpu.get_de());

            set_zsp(cpu, e);
        },
        0x24 => {
            const h = cpu.regs.h + 1;
            cpu.regs.h = h;
            cpu.set_hl(cpu.get_hl());

            set_zsp(cpu, h);
        },
        0x2C => {
            const l = cpu.regs.l + 1;
            cpu.regs.l = l;
            cpu.set_hl(cpu.get_hl());

            set_zsp(cpu, l);
        },
        0x34 => {
            const hl = cpu.get_hl();
            const valhl = cpu.mem[hl] + 1;
            cpu.mem[hl] = valhl;

            set_zsp(cpu, valhl);
        },
        0x3C => {
            const a = cpu.regs.a + 1;
            cpu.regs.a = a;

            set_zsp(cpu, a);
        },
        else => unreachable,
    }

    cpu.regs.pc += 1;
}

fn DCR(cpu: *CPU) void {
    const opcode = cpu.mem[cpu.regs.pc];

    switch (opcode) {
        0x05 => {
            const b = cpu.regs.b - 1;
            cpu.regs.b = b;
            cpu.set_bc(cpu.get_bc());

            set_zsp(cpu, b);
        },
        0x0D => {
            const c = cpu.regs.c - 1;
            cpu.regs.c = c;
            cpu.set_bc(cpu.get_bc());

            set_zsp(cpu, c);
        },
        0x15 => {
            const d = cpu.regs.d - 1;
            cpu.regs.d = d;
            cpu.set_de(cpu.get_de());

            set_zsp(cpu, d);
        },
        0x1D => {
            const e = cpu.regs.e - 1;
            cpu.regs.e = e;
            cpu.set_de(cpu.get_de());

            set_zsp(cpu, e);
        },
        0x25 => {
            const h = cpu.regs.h - 1;
            cpu.regs.h = h;
            cpu.set_hl(cpu.get_hl());

            set_zsp(cpu, h);
        },
        0x2D => {
            const l = cpu.regs.l - 1;
            cpu.regs.l = l;
            cpu.set_hl(cpu.get_hl());

            set_zsp(cpu, l);
        },
        0x35 => {
            const hl = cpu.get_hl();
            const valhl = cpu.mem[hl] - 1;
            cpu.mem[hl] = valhl;

            set_zsp(cpu, valhl);
        },
        0x3D => {
            const a = cpu.regs.a - 1;
            cpu.regs.a = a;

            set_zsp(cpu, a);
        },
        else => unreachable,
    }

    cpu.regs.pc += 1;
}
