#!/usr/bin/env python3
import os
import pathlib
import struct
import subprocess
import sys


def p32(value):
    return struct.pack("<I", value)


def p64(value):
    return struct.pack("<Q", value)


def name16(value):
    return value.encode() + b"\0" * (16 - len(value))


def macho_header():
    base = 0x600000
    entry = 0x400
    text_size = 0x800000
    data_size = 0x1000000
    linkedit_offset = text_size + data_size
    data_vm = base + text_size

    commands = []
    commands.append(
        p32(0x19)
        + p32(72)
        + name16("__PAGEZERO")
        + p64(0)
        + p64(0x1000)
        + p64(0)
        + p64(0)
        + p32(0)
        + p32(0)
        + p32(0)
        + p32(0)
    )

    text = (
        p32(0x19)
        + p32(152)
        + name16("__TEXT")
        + p64(base)
        + p64(text_size)
        + p64(0)
        + p64(text_size)
        + p32(5)
        + p32(5)
        + p32(1)
        + p32(0)
    )
    text += (
        name16("__text")
        + name16("__TEXT")
        + p64(base + entry)
        + p64(text_size - entry)
        + p32(entry)
        + p32(0)
        + p32(0)
        + p32(0)
        + p32(0x80000400)
        + p32(0)
        + p32(0)
        + p32(0)
    )
    commands.append(text)

    commands.append(
        p32(0x19)
        + p32(72)
        + name16("__DATA")
        + p64(data_vm)
        + p64(data_size)
        + p64(text_size)
        + p64(data_size)
        + p32(3)
        + p32(3)
        + p32(0)
        + p32(0)
    )

    commands.append(
        p32(0x19)
        + p32(72)
        + name16("__LINKEDIT")
        + p64(base + linkedit_offset)
        + p64(0x100000)
        + p64(linkedit_offset)
        + p64(0)
        + p32(1)
        + p32(1)
        + p32(0)
        + p32(0)
    )

    commands.append(p32(0x80000022) + p32(48) + bytes(40))
    commands.append(p32(0x2) + p32(24) + bytes(16))
    commands.append(p32(0xB) + p32(80) + bytes(72))

    dylinker = b"/usr/lib/dyld\0"
    commands.append(
        p32(0xE)
        + p32(32)
        + p32(12)
        + dylinker
        + b"\0" * (32 - 12 - len(dylinker))
    )
    commands.append(p32(0x1B) + p32(24) + bytes.fromhex("2132435465768798a9bacbdcedfe0f10"))
    commands.append(
        p32(0x32)
        + p32(32)
        + p32(1)
        + p32(0xE0000)
        + p32(0)
        + p32(1)
        + p32(3)
        + p32(0)
    )
    commands.append(p32(0x80000028) + p32(24) + p64(entry) + p64(0))

    libsystem = b"/usr/lib/libSystem.B.dylib\0"
    commands.append(
        p32(0xC)
        + p32(56)
        + p32(24)
        + p32(2)
        + p32(0x054C0000)
        + p32(0x10000)
        + libsystem
        + b"\0" * (56 - 24 - len(libsystem))
    )
    commands.append(p32(0x26) + p32(16) + bytes(8))
    commands.append(p32(0x29) + p32(16) + bytes(8))

    header = (
        p32(0xFEEDFACF)
        + p32(0x01000007)
        + p32(3)
        + p32(2)
        + p32(len(commands))
        + p32(sum(map(len, commands)))
        + p32(0x85)
        + p32(0)
        + b"".join(commands)
    )
    if len(header) > entry:
        raise ValueError(f"Mach-O header exceeds entry offset: {len(header)} > {entry}")
    return header + bytes(entry - len(header)), base, data_vm, data_size, linkedit_offset


def port_hex2_source(stage0_sources, output):
    source = (stage0_sources / "AMD64/hex2_AMD64.hex1").read_text().split(":ELF_text", 1)[1]
    source = source.replace(
        "\t58                          ; pop_rax                     # Get the number of arguments\n"
        "\t5F                          ; pop_rdi                     # Get the program name\n"
        "\t5F                          ; pop_rdi                     # Get the actual input name",
        "\t4989F7                      ; mov_r15,rsi                 # Save Darwin argv\n"
        "\t498B7F08                    ; mov_rdi,[r15+8]             # argv[1]",
        1,
    )
    source = source.replace(
        "\t5F                          ; pop_rdi                     # Get the actual output name",
        "\t498B7F10                    ; mov_rdi,[r15+16]            # argv[2]",
        1,
    )
    replacements = [
        ("48C7C0 02000000", "48C7C0 05000002"),
        ("48C7C6 41020000", "48C7C6 01060000"),
        ("48C7C0 08000000", "48C7C0 C7000002"),
        ("48C7C0 3C000000", "48C7C0 01000002"),
        ("48C7C0 00000000             ; mov_rax, %0                 # the syscall number for read", "48C7C0 03000002             ; mov_rax, %0x2000003           # Darwin read"),
        ("48C7C0 01000000             ; mov_rax, %1                 # the syscall number for write", "48C7C0 04000002             ; mov_rax, %0x2000004           # Darwin write"),
    ]
    for old, new in replacements:
        source = source.replace(old, new)
    output.write_text(source)


def patch_rel32(binary, opcode, target):
    start = 0
    while True:
        position = binary.find(opcode, start)
        if position < 0:
            break
        displacement_position = position + len(opcode)
        next_instruction = 0x600000 + displacement_position + 4
        binary[displacement_position : displacement_position + 4] = struct.pack(
            "<i", target - next_instruction
        )
        start = displacement_position + 4


def patch_malloc(binary, heap):
    pattern = bytes.fromhex("48c7c00c00000041530f05415bc3")
    position = binary.find(pattern)
    if position < 0:
        raise ValueError("malloc syscall pattern not found")
    replacement = b"\x48\xB8" + p64(heap) + b"\xC3"
    binary[position : position + len(replacement)] = replacement
    binary[position + len(replacement) : position + len(pattern)] = bytes(
        len(pattern) - len(replacement)
    )


def patch_binary(binary, data_vm):
    write_buffer = data_vm
    scratch_slot = data_vm + 8
    heap = data_vm + 0x1000

    for opcode in [b"\x48\x8d\x35", b"\x8a\x05"]:
        patch_rel32(binary, opcode, write_buffer)
    for opcode in [b"\x4c\x89\x25", b"\x48\x8b\x1d", b"\x48\x8b\x3d", b"\x48\x8b\x05"]:
        patch_rel32(binary, opcode, scratch_slot)
    patch_malloc(binary, heap)


def main():
    stage0_sources = pathlib.Path(sys.argv[1])
    hex1 = pathlib.Path(sys.argv[2])
    output_dir = pathlib.Path(sys.argv[3])
    output_dir.mkdir(parents=True, exist_ok=True)

    body_source = output_dir / "hex2_AMD64_darwin_body.hex1"
    port_hex2_source(stage0_sources, body_source)
    body_binary = output_dir / "hex2-body.bin"
    subprocess.check_call([str(hex1), str(body_source), str(body_binary)])

    header, base, data_vm, data_size, linkedit_offset = macho_header()
    binary = bytearray(header + body_binary.read_bytes())
    patch_binary(binary, data_vm)
    data_end = data_vm - base + data_size
    if len(binary) < data_end:
        binary.extend(bytes(data_end - len(binary)))
    if len(binary) < linkedit_offset:
        binary.extend(bytes(linkedit_offset - len(binary)))

    output = output_dir / "hex2-darwin"
    output.write_bytes(binary)
    os.chmod(output, 0o755)


if __name__ == "__main__":
    main()
