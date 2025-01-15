const std = @import("std");
const CPU = @import("cpu.zig").CPU;

fn set_cy(cpu: *CPU, val: u16) void {
    cpu.flags.cy = (val & 0xFF00) != 0;
}

fn set_ac(cpu: *CPU, a: u8, b: u8, carry: bool) void {
    const sum = (a & 0x0F) + (b & 0x0F) + (if (carry) 1 else 0);
    cpu.flags.ac = (sum & 0x10) != 0;
}

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
    const low_byte: u8 = @as(u8, @intCast(cpu.mem[cpu.regs.pc + 1]));
    const high_byte: u8 = @as(u8, @intCast(cpu.mem[cpu.regs.pc + 2])) << 8;

    cpu.regs.l = low_byte;
    cpu.regs.h = high_byte;
    cpu.set_hl(cpu.get_hl());

    cpu.regs.pc += 3;
}

fn MVI(cpu: *CPU) void {
    const opcode = cpu.mem[cpu.regs.pc];
    const low_byte: u8 = @as(u8, @intCast(cpu.mem[cpu.regs.pc + 1]));

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
        0x05 => {
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
        0x15 => {
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
        0x25 => {
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
        0x35 => {
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
        0x0C => {
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
        0x1C => {
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
        0x2C => {
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
        0x3C => {
            const a = cpu.regs.a - 1;
            cpu.regs.a = a;

            set_zsp(cpu, a);
        },
        else => unreachable,
    }

    cpu.regs.pc += 1;
}
