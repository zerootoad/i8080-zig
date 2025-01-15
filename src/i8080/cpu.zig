// Some bullshit i gotta know while writing this bs code
//
// 65,536 bytes of memory -> 0 to FFFFH
//
// 6x8-bits registers
// 8-bit accumulator
// 16-bits stack pointer (sp)
// 16-bits program counter (pc)
//
// 5 flags
// |- zero: set if an operation results 0
// |- sign: set if a result is negative
// |- parity: set if the number of 1s in the result is even
// |- carry: set if there's carry or borrow in arithmetic operations
// |- auxiliary carry (long ahh word): used in binary coded decimal (bcd) operations
//
// instructions: https://archive.org/details/8080Datasheet/page/n7/mode/2up
// - 1 byte: |opcode|
// - 2 bytes: |opcode|operand|
// - 3 bytes: |opcode|low addr or operand1|high addr or operand2|
//
// Simulation 101:
// 1. read opcode at the pc
// 2. decode the instruction, examples:
//    - perform any additional memory acesses
//    - update registers
//    - update flags
// 3. advance the pc by the number of the opcode bytes
//
// Opcodes sh:
// - http://textfiles.com/programming/8080.op (mirror: https://gist.githubusercontent.com/joefg/634fa4a1046516d785c9/raw/0a503ae43a95ca31602ee9b8664dcabfb4d5a7b3/8080.op)
// - https://pastraiser.com/cpu/i8080/i8080_opcodes.html

const std = @import("std");
const instruct = @import("instructions.zig");

pub const CPU = struct {
    opcode: u8,
    mem: [65536]u8, // memory
    regs: struct {
        sp: u16, // stack pointer
        pc: u16, // program counter
        a: u8, // accumulator
        b: u8,
        c: u8,
        d: u8,
        e: u8,
        h: u8,
        l: u8,
    },
    flags: struct {
        z: bool, // zero flag
        s: bool, // sign flag
        p: bool, // parity flag
        cy: bool, // carry flag
        ac: bool, // auxiliary flag
    },

    pub fn new() CPU {
        return CPU{
            .opcode = 0,
            .mem = [_]u8{0} ** 65536,
            .regs = .{
                .sp = 0,
                .pc = 0,
                .a = 0,
                .b = 0,
                .c = 0,
                .d = 0,
                .e = 0,
                .h = 0,
                .l = 0,
            },
            .flags = .{
                .z = false,
                .s = false,
                .p = false,
                .cy = false,
                .ac = false,
            },
        };
    }

    // Getters and Setters
    pub fn get_bc(self: *CPU) u16 {
        return @as(u16, @intCast(self.regs.b)) << 8 | @as(u16, @intCast(self.regs.c));
    }

    pub fn set_bc(self: *CPU, value: u16) void {
        self.regs.b = @intCast(value >> 8);
        self.regs.c = @intCast(value & 0xFF);
    }

    pub fn get_de(self: *CPU) u16 {
        return @as(u16, @intCast(self.regs.d)) << 8 | @as(u16, @intCast(self.regs.e));
    }

    pub fn set_de(self: *CPU, value: u16) void {
        self.regs.d = @intCast(value >> 8);
        self.regs.e = @intCast(value & 0xFF);
    }

    pub fn get_hl(self: *CPU) u16 {
        return @as(u16, @intCast(self.regs.h)) << 8 | @as(u16, @intCast(self.regs.l));
    }

    pub fn set_hl(self: *CPU, value: u16) void {
        self.regs.h = @intCast(value >> 8);
        self.regs.l = @intCast(value & 0xFF);
    }

    // Cpu utils
    pub fn load(cpu: *CPU, path: []const u8) !void {
        var file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [1024]u8 = undefined;
        var mem_index: usize = 0;

        while (try in_stream.readUntilDelimiterOrEof(&buf, undefined)) |chunk| {
            for (chunk) |byte| {
                if (mem_index >= cpu.mem.len) {
                    return error.OutOfMemory;
                }
                cpu.mem[mem_index] = byte;
                mem_index += 1;
            }
        }

        cpu.regs.pc = 0;
        std.debug.print("ROM loaded successfully. Bytes: {}\n", .{mem_index});
    }

    pub fn cycle(cpu: *CPU) void {
        var instruction = instruct.decode(cpu);

        std.debug.print("Executing: {s}\n", .{instruction.mnemonic});
        instruction.execute(cpu);
    }
};
