const std = @import("std");

const InstructionDecodeResult = struct {
    read: usize,
    missing_from: usize,
};

const ParseError = error{
    InvalidData,
};

const Instruction = enum {
    mov,
    add,
    sub,
    cmp,
    je,
    jnz,
    jl,
    jle,
    jb,
    jbe,
    jp,
    jo,
    js,
    jne,
    jnl,
    jg,
    jnb,
    ja,
    jpo,
    jno,
    jns,
    loop,
    loopz,
    loopnz,
    jcxz,

    // Method to convert enum to string
    pub fn to_string(self: Instruction) []const u8 {
        return switch (self) {
            .mov => "mov",
            .add => "add",
            .sub => "sub",
            .cmp => "cmp",
            .je => "je",
            .jl => "jl",
            .jle => "jle",
            .jnz => "jnz",
            .jb => "jb",
            .jbe => "jbe",
            .jp => "jp",
            .jo => "jo",
            .js => "js",
            .jne => "jne",
            .jnl => "jnl",
            .jg => "jg",
            .jnb => "jnb",
            .ja => "ja",
            .jpo => "jpo",
            .jno => "jno",
            .jns => "jns",
            .loop => "loop",
            .loopz => "loopz",
            .loopnz => "loopnz",
            .jcxz => "jcxz",
        };
    }
};

pub fn main() !void {
    // Get an args iterator
    var args = std.process.args();
    defer args.deinit();

    // Skip the program name (first argument)
    _ = args.skip();

    // Get the first actual argument
    const first_arg = args.next() orelse {
        std.debug.print("No file provided\n", .{});
        return;
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile(first_arg, .{});
    defer file.close();

    // apple m2 L1 efficiency core cache size
    const stdout = std.io.getStdOut().writer();
    try stdout.print("bits 16\n\n", .{});
    try read_all_instructions(allocator, file, stdout);
}

inline fn read_all_instructions(allocator: std.mem.Allocator, file: std.fs.File, writer: anytype) !void {
    const chunk_size = 1024 * 64;
    const instructions_buffer = try allocator.alloc(u8, chunk_size);
    defer allocator.free(instructions_buffer);
    // bytes_kept are the bytes that were kept from the last round of operations.
    var bytes_kept: usize = 0;
    while (true) {
        const bytes_read = try file.read(instructions_buffer[bytes_kept..]);
        if (bytes_read == 0) {
            // EOF
            break;
        }
        // keep_from
        const decode_result = try decode_instructions(instructions_buffer[bytes_kept..bytes_read], writer);
        if (decode_result.missing_from > 0) {
            // TODO: this could be more performant with a ring-buffer
            // copy these bytes to the begining of the buffer
            for (decode_result.missing_from..instructions_buffer.len) |i| {
                instructions_buffer[0 + i] = instructions_buffer[decode_result.missing_from + i];
            }
            bytes_kept = decode_result.missing_from - instructions_buffer.len;
        }
        if (bytes_read + bytes_kept < chunk_size) {
            // read the file entirely
            break;
        }
    }
}

inline fn decode_instructions(instructions: []u8, writer: anytype) !InstructionDecodeResult {
    var position: usize = 0;
    while (position < instructions.len) {
        const opcode = instructions[position];
        if (opcode == 0b01110100) {
            // je jump on equal zero
        } else if (opcode == 0b01111100) {
            // jl Jump on tess/not greater or equal = 0b01111100
            const read = try decode_jump(instructions[position..], Instruction.jl, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01111110) {
            // jle = Jump on less or equal/not greater = 0b01111110
            const read = try decode_jump(instructions[position..], Instruction.jle, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01110010) {
            // jb = Jump on below/not above or equal = 0b01110010
            const read = try decode_jump(instructions[position..], Instruction.jb, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01110110) {
            // jbe = Jump on below or equal/ not above = 0b01110110
            const read = try decode_jump(instructions[position..], Instruction.jbe, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01111010) {
            // jp = Jump on parity /parity even = 0b01111010
            const read = try decode_jump(instructions[position..], Instruction.jp, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01110000) {
            // jo = Jump on overflow = 0b01110000
            const read = try decode_jump(instructions[position..], Instruction.jo, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01111000) {
            // js = Jump on sign = 0b01111000
            const read = try decode_jump(instructions[position..], Instruction.js, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01110101) {
            // jne = Jump on not equal/not zero = 0b01110101
            const read = try decode_jump(instructions[position..], Instruction.jne, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01111101) {
            // jnl = Jump on not less/greater or equal = 0b01111101
            const read = try decode_jump(instructions[position..], Instruction.jnl, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01111111) {
            // jg = Jump on not less or equal/greater = 0b01111111
            const read = try decode_jump(instructions[position..], Instruction.jg, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01110011) {
            // jnb = Jump on not below/above or equal = 0b01110011
            const read = try decode_jump(instructions[position..], Instruction.jnb, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01110111) {
            // ja = Jump on not below or equal/above = 0b01110111
            const read = try decode_jump(instructions[position..], Instruction.ja, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01111011) {
            // jpo = Jump on not par/par odd = 0b01111011
            const read = try decode_jump(instructions[position..], Instruction.jpo, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01110001) {
            // jno = Jump on not overfiow = 0b01110001
            const read = try decode_jump(instructions[position..], Instruction.jno, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b01111001) {
            // jns = Jump on not sign
            const read = try decode_jump(instructions[position..], Instruction.jns, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b11100010) {
            // loop = Loop CX times
            const read = try decode_jump(instructions[position..], Instruction.loop, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b11100001) {
            // loopz = Loop while zero/equal
            const read = try decode_jump(instructions[position..], Instruction.loopz, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b11100000) {
            // loopnz = Loop while not zero/ equal
            const read = try decode_jump(instructions[position..], Instruction.loopnz, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if (opcode == 0b11100011) {
            // jcxz = Jump on CX zero
            const read = try decode_jump(instructions[position..], Instruction.jcxz, writer);
            if (read == 0) {
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            position += read + 1;
        } else if ((opcode >> 1) == 0b01100011) {
            // mov => immediate to register/memory
            if (instructions.len < position + 1) {
                // more data is needed
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            const w = opcode & 0b00000001;
            const read = try decode_imm_to_reg_mem(instructions[position + 1 ..], w, Instruction.mov, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 1) == 0b1010000) {
            // mov => memory to accumulator
            const w = opcode & 0b00000001;
            const read = try decode_acc_to_mem(instructions[position + 1 ..], w, true, Instruction.mov, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 1) == 0b1010001) {
            // mov => accumulator to memory
            const w = opcode & 0b00000001;
            const read = try decode_acc_to_mem(instructions[position + 1 ..], w, false, Instruction.mov, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 1) == 0b0000010) {
            // mov => accumulator to memory
            const w = opcode & 0b00000001;
            const read = try decode_acc_to_mem(instructions[position + 1 ..], w, true, Instruction.add, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 1) == 0b0010110) {
            // mov => accumulator to memory
            const w = opcode & 0b00000001;
            const read = try decode_acc_to_mem(instructions[position + 1 ..], w, true, Instruction.sub, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 1) == 0b0011110) {
            // mov => accumulator to memory
            const w = opcode & 0b00000001;
            const read = try decode_acc_to_mem(instructions[position + 1 ..], w, true, Instruction.cmp, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 2) == 0b100000) {
            // add/sub/cmp => immediate to register/memory
            if (instructions.len < position + 1) {
                // more data is needed
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            const w = opcode & 0b00000001;
            const read = try decode_imm_to_reg_mem(instructions[position + 1 ..], w, null, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 2) == 0b00100010) {
            //  mov => Register/memory to/from register
            const d: u8 = (opcode & 0b00000010) >> 1;
            const w: u8 = opcode & 0b00000001;
            if (position + 1 >= instructions.len) {
                // succesfully parsed mov but need more data. return current position
                // so that we can read more data without missing data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            const read = try decode_reg_mem_reg(instructions[position + 1 ..], d, w, Instruction.mov, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 2) == 0) {
            //  add => Register/memory to/from register
            const d: u8 = (opcode & 0b00000010) >> 1;
            const w: u8 = opcode & 0b00000001;
            if (position + 1 >= instructions.len) {
                // succesfully parsed mov but need more data. return current position
                // so that we can read more data without missing data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            const read = try decode_reg_mem_reg(instructions[position + 1 ..], d, w, Instruction.add, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 2) == 0b001010) {
            //  mov => Register/memory to/from register
            const d: u8 = (opcode & 0b00000010) >> 1;
            const w: u8 = opcode & 0b00000001;
            if (position + 1 >= instructions.len) {
                // succesfully parsed mov but need more data. return current position
                // so that we can read more data without missing data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            const read = try decode_reg_mem_reg(instructions[position + 1 ..], d, w, Instruction.sub, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 2) == 0b001110) {
            //  mov => Register/memory to/from register
            const d: u8 = (opcode & 0b00000010) >> 1;
            const w: u8 = opcode & 0b00000001;
            if (position + 1 >= instructions.len) {
                // succesfully parsed mov but need more data. return current position
                // so that we can read more data without missing data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            const read = try decode_reg_mem_reg(instructions[position + 1 ..], d, w, Instruction.cmp, writer);
            if (read == 0) {
                // if the return was zero then it means it needs more data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else if ((opcode >> 4) == 0b1011) {
            // mov => Immediate to register
            const w: u8 = opcode >> 3 & 0b00000001;
            const reg: u8 = opcode & 0b00000111;
            if (position + 1 >= instructions.len) {
                // succesfully parsed mov but need more data. return current position
                // so that we can read more data without missing data
                return InstructionDecodeResult{ .read = 0, .missing_from = position };
            }
            const read = try decode_imm_to_reg(instructions[position + 1 ..], w, reg, Instruction.mov, writer);
            // take into account the byte we read to decode the opcode
            position += read + 1;
        } else {
            return ParseError.InvalidData;
        }
    }
    return InstructionDecodeResult{ .read = position, .missing_from = 0 };
}

inline fn decode_imm_to_reg(instructions: []u8, w: u8, reg: u8, ins: Instruction, writer: anytype) !usize {
    var mem_buf: [7]u8 = undefined;
    var mem: u16 = 0;
    var read: usize = 1;
    if (w == 1) {
        if (instructions.len < 2) {
            // more data is needed
            return 0;
        }
        mem = (@as(u16, instructions[1]) << 8) + @as(u16, instructions[0]);
        read = 2;
    } else {
        if (instructions.len < 1) {
            // more data is needed
            return 0;
        }
        mem = @as(u16, instructions[0]);
    }
    const dest = decode_reg(reg, w);
    const src = try std.fmt.bufPrint(&mem_buf, "{}", .{mem});
    try writer.print("{s} {s},{s}\n", .{ ins.to_string(), dest, src });
    return read;
}

inline fn decode_acc_to_mem(instructions: []u8, w: u8, is_ax_dest: bool, ins: Instruction, writer: anytype) !usize {
    var dest: []const u8 = undefined;
    var src: []const u8 = undefined;
    var mem_buf: [7]u8 = undefined;
    var mem: u16 = 0;
    var read: usize = 1;
    if (w == 1) {
        if (instructions.len < 2) {
            // more data is needed
            return 0;
        }
        mem = (@as(u16, instructions[1]) << 8) + @as(u16, instructions[0]);
        read = 2;
    } else {
        if (instructions.len < 1) {
            // more data is needed
            return 0;
        }
        mem = @as(u16, instructions[0]);
    }
    if (is_ax_dest) {
        dest = "ax";
        src = try std.fmt.bufPrint(&mem_buf, "[{}]", .{mem});
    } else {
        dest = try std.fmt.bufPrint(&mem_buf, "[{}]", .{mem});
        src = "ax";
    }
    try writer.print("{s} {s},{s}\n", .{ ins.to_string(), dest, src });
    return read;
}

fn decode_jump(instructions: []u8, instruction: Instruction, writer: anytype) !usize {
    if (instructions.len < 2) {
        // need more data
        return 0;
    }
    const ipc_displacement: i8 = @bitCast(instructions[1]);
    try writer.print("{s} {}\n", .{ instruction.to_string(), ipc_displacement });
    return 1;
}

inline fn decode_imm_to_reg_mem(instructions: []u8, w: u8, known_ins: ?Instruction, writer: anytype) !usize {
    const mod_reg_rm = instructions[0];
    const mod = mod_reg_rm >> 6;
    const rm = mod_reg_rm & 0b00000111;
    const reg = (mod_reg_rm >> 3) & 0b111;
    const ins = known_ins orelse blk: {
        switch (reg) {
            0b000 => break :blk Instruction.add,
            0b101 => break :blk Instruction.sub,
            0b111 => break :blk Instruction.cmp,
            else => {
                // I'm not going to parse other examples
                unreachable;
            },
        }
    };
    var dest: []const u8 = undefined;
    var src: []const u8 = undefined;
    var immediate_buf: [10]u8 = undefined;
    var immediate: u16 = 0;
    var read: usize = 1;
    switch (mod) {
        0b00 => {
            if (rm == 0b110) {
                // memory mode 16-bit displacement
                if ((w == 1 and instructions.len < 5) or (w == 0 and instructions.len < 4)) {
                    // more data is needed
                    return 0;
                }
                const direct_address = (@as(u16, instructions[2]) << 8) + @as(u16, instructions[1]);
                var buf: [7]u8 = undefined;
                dest = try std.fmt.bufPrint(&buf, "[{}]", .{direct_address});
                if (w == 1) {
                    immediate = (@as(u16, instructions[4]) << 8) + @as(u16, instructions[3]);
                    read = 5;
                } else {
                    immediate = @as(u16, instructions[3]);
                    read = 4;
                }
                src = try std.fmt.bufPrint(&immediate_buf, "{}", .{immediate});
            } else {
                if ((w == 1 and instructions.len < 3) or (w == 0 and instructions.len < 2)) {
                    // more data is needed
                    return 0;
                }
                // memory mode no displacement
                dest = decode_memory_mode(rm);
                var oper_size = "byte ";
                if (w == 1) {
                    immediate = (@as(u16, instructions[2]) << 8) + @as(u16, instructions[1]);
                    oper_size = "word ";
                    read = 3;
                } else {
                    immediate = @as(u16, instructions[1]);
                    read = 2;
                }
                src = try std.fmt.bufPrint(&immediate_buf, "{s}{}", .{ oper_size, immediate });
            }
        },
        0b01 => {
            // memory mode 8-bit displacement
            if ((w == 1 and instructions.len < 3) or (w == 0 and instructions.len < 4)) {
                // more data is needed
                return 0;
            }
            read = 2;
            var buf: [17]u8 = undefined;
            const displacement: i8 = @bitCast(instructions[1]);
            var instruction_str: []const u8 = undefined;
            if (displacement == 0) {
                instruction_str = decode_memory_mode(rm);
            } else {
                var buf_displacement: [4]u8 = undefined;
                const displacement_str = try std.fmt.bufPrint(&buf_displacement, "{}", .{displacement});
                instruction_str = try decode_memory_mode_with_displacement(&buf, rm, displacement_str);
            }
            dest = instruction_str;
            var oper_size = "byte ";
            if (w == 1) {
                immediate = (@as(u16, instructions[3]) << 8) + @as(u16, instructions[2]);
                oper_size = "word ";
                read = 4;
            } else {
                immediate = @as(u16, instructions[2]);
                read = 3;
            }
            src = try std.fmt.bufPrint(&immediate_buf, "{s}{}", .{ oper_size, immediate });
        },
        0b10 => {
            // memory mode 16-bit displacement
            if ((w == 1 and instructions.len < 5) or (w == 0 and instructions.len < 4)) {
                // more data is needed
                return 0;
            }
            read = 3;
            var buf: [14]u8 = undefined;
            const displacement = i16_from_bytes(instructions[2], instructions[1]);
            var instruction_str: []const u8 = undefined;
            if (displacement == 0) {
                instruction_str = decode_memory_mode(rm);
            } else {
                var buf_displacement: [6]u8 = undefined;
                const displacement_str = try std.fmt.bufPrint(&buf_displacement, "{}", .{displacement});
                instruction_str = try decode_memory_mode_with_displacement(&buf, rm, displacement_str);
            }
            dest = instruction_str;
            var oper_size = "byte ";
            if (w == 1) {
                immediate = (@as(u16, instructions[4]) << 8) + @as(u16, instructions[3]);
                oper_size = "word ";
                read = 5;
            } else {
                immediate = @as(u16, instructions[3]);
                read = 4;
            }
            src = try std.fmt.bufPrint(&immediate_buf, "{s}{}", .{ oper_size, immediate });
        },
        0b11 => {
            // register mode (no displacement)
            if ((w == 1 and instructions.len < 3) or (w == 0 and instructions.len < 2)) {
                // more data is needed
                return 0;
            }
            dest = decode_reg(rm, w);
            var oper_size = "byte ";
            if (w == 1) {
                immediate = (@as(u16, instructions[2]) << 8) + @as(u16, instructions[1]);
                oper_size = "word ";
                read = 3;
            } else {
                immediate = @as(u16, instructions[1]);
                read = 2;
            }
            src = try std.fmt.bufPrint(&immediate_buf, "{s}{}", .{ oper_size, immediate });
        },
        else => {},
    }
    try writer.print("{s} {s},{s}\n", .{ ins.to_string(), dest, src });
    return read;
}

inline fn decode_reg_mem_reg(instructions: []u8, d: u8, w: u8, ins: Instruction, writer: anytype) !usize {
    const mod_reg_rm = instructions[0];
    const mod = mod_reg_rm >> 6;
    const reg = (mod_reg_rm >> 3) & 0b111;
    const rm = mod_reg_rm & 0b00000111;
    var dest: []const u8 = undefined;
    var src: []const u8 = undefined;
    var read: usize = 1;
    switch (mod) {
        0b00 => {
            if (rm == 0b110) {
                // memory mode 16-bit displacement
                if (instructions.len < 3) {
                    // more data is needed
                    return 0;
                }
                read = 3;
                const direct_address = (@as(u16, instructions[2]) << 8) + @as(u16, instructions[1]);
                var buf: [7]u8 = undefined;
                const direct_address_str = try std.fmt.bufPrint(&buf, "[{}]", .{direct_address});
                if (d == 1) {
                    dest = decode_reg(reg, w);
                    src = direct_address_str;
                } else {
                    dest = direct_address_str;
                    src = decode_reg(reg, w);
                }
            } else {
                // memory mode no displacement
                if (d == 1) {
                    dest = decode_reg(reg, w);
                    src = decode_memory_mode(rm);
                } else {
                    dest = decode_memory_mode(rm);
                    src = decode_reg(reg, w);
                }
            }
        },
        0b01 => {
            // memory mode 8-bit displacement
            if (instructions.len < 2) {
                // more data is needed
                return 0;
            }
            read = 2;
            var buf: [12]u8 = undefined;
            const displacement: i8 = @bitCast(instructions[1]);
            var instruction_str: []const u8 = undefined;
            if (displacement == 0) {
                instruction_str = decode_memory_mode(rm);
            } else {
                var buf_displacement: [4]u8 = undefined;
                const displacement_str = try std.fmt.bufPrint(&buf_displacement, "{}", .{displacement});
                instruction_str = try decode_memory_mode_with_displacement(&buf, rm, displacement_str);
            }
            if (d == 1) {
                dest = decode_reg(reg, w);
                src = instruction_str;
            } else {
                dest = instruction_str;
                src = decode_reg(reg, w);
            }
        },
        0b10 => {
            // memory mode 16-bit displacement
            if (instructions.len < 3) {
                // more data is needed
                return 0;
            }
            read = 3;
            var buf: [14]u8 = undefined;
            const displacement = i16_from_bytes(instructions[2], instructions[1]);
            var instruction_str: []const u8 = undefined;
            if (displacement == 0) {
                instruction_str = decode_memory_mode(rm);
            } else {
                var buf_displacement: [6]u8 = undefined;
                const displacement_str = try std.fmt.bufPrint(&buf_displacement, "{}", .{displacement});
                instruction_str = try decode_memory_mode_with_displacement(&buf, rm, displacement_str);
            }
            if (d == 1) {
                dest = decode_reg(reg, w);
                src = instruction_str;
            } else {
                dest = instruction_str;
                src = decode_reg(reg, w);
            }
        },
        0b11 => {
            // register mode (no displacement)
            if (d == 1) {
                dest = decode_reg(reg, w);
                src = decode_reg(rm, w);
            } else {
                dest = decode_reg(rm, w);
                src = decode_reg(reg, w);
            }
        },
        else => {},
    }
    try writer.print("{s} {s},{s}\n", .{ ins.to_string(), dest, src });
    return read;
}

fn decode_reg(reg: u8, w: u8) []const u8 {
    return if (w == 1) switch (reg) {
        0b000 => "ax",
        0b001 => "cx",
        0b010 => "dx",
        0b011 => "bx",
        0b100 => "sp",
        0b101 => "bp",
        0b110 => "si",
        0b111 => "di",
        else => "invalid",
    } else switch (reg) {
        0b000 => "al",
        0b001 => "cl",
        0b010 => "dl",
        0b011 => "bl",
        0b100 => "ah",
        0b101 => "ch",
        0b110 => "dh",
        0b111 => "bh",
        else => "invalid",
    };
}

fn decode_memory_mode(rm: u8) []const u8 {
    return switch (rm) {
        0b000 => "[bx+si]",
        0b001 => "[bx+di]",
        0b010 => "[bp+si]",
        0b011 => "[bp+di]",
        0b100 => "[si]",
        0b101 => "[di]",
        0b110 => "[bp]",
        0b111 => "[bx]",
        else => "invalid",
    };
}

fn decode_memory_mode_with_displacement(instruction_str: []u8, rm: u8, displacement: []const u8) ![]const u8 {
    if (displacement[0] == '-') {
        return switch (rm) {
            0b000 => try std.fmt.bufPrint(instruction_str, "[bx+si{s}]", .{displacement}),
            0b001 => try std.fmt.bufPrint(instruction_str, "[bx+di{s}]", .{displacement}),
            0b010 => try std.fmt.bufPrint(instruction_str, "[bp+si{s}]", .{displacement}),
            0b011 => try std.fmt.bufPrint(instruction_str, "[bp+di{s}]", .{displacement}),
            0b100 => try std.fmt.bufPrint(instruction_str, "[si{s}]", .{displacement}),
            0b101 => try std.fmt.bufPrint(instruction_str, "[di{s}]", .{displacement}),
            0b110 => try std.fmt.bufPrint(instruction_str, "[bp{s}]", .{displacement}),
            0b111 => try std.fmt.bufPrint(instruction_str, "[bx{s}]", .{displacement}),
            else => "invalid",
        };
    }
    return switch (rm) {
        0b000 => try std.fmt.bufPrint(instruction_str, "[bx+si+{s}]", .{displacement}),
        0b001 => try std.fmt.bufPrint(instruction_str, "[bx+di+{s}]", .{displacement}),
        0b010 => try std.fmt.bufPrint(instruction_str, "[bp+si+{s}]", .{displacement}),
        0b011 => try std.fmt.bufPrint(instruction_str, "[bp+di+{s}]", .{displacement}),
        0b100 => try std.fmt.bufPrint(instruction_str, "[si+{s}]", .{displacement}),
        0b101 => try std.fmt.bufPrint(instruction_str, "[di+{s}]", .{displacement}),
        0b110 => try std.fmt.bufPrint(instruction_str, "[bp+{s}]", .{displacement}),
        0b111 => try std.fmt.bufPrint(instruction_str, "[bx+{s}]", .{displacement}),
        else => "invalid",
    };
}

inline fn i16_from_bytes(high: u8, low: u8) i16 {
    return @bitCast((@as(u16, high) << 8) | low);
}
