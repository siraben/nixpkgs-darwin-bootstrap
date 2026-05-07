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
    data_size = 0x100000
    linkedit_offset = text_size + data_size

    commands = []
    commands.append(p32(0x19) + p32(72) + name16("__PAGEZERO") + p64(0) + p64(0x1000) + p64(0) + p64(0) + p32(0) + p32(0) + p32(0) + p32(0))

    text = p32(0x19) + p32(152) + name16("__TEXT") + p64(base) + p64(text_size) + p64(0) + p64(text_size) + p32(5) + p32(5) + p32(1) + p32(0)
    text += name16("__text") + name16("__TEXT") + p64(base + entry) + p64(text_size - entry) + p32(entry) + p32(0) + p32(0) + p32(0) + p32(0x80000400) + p32(0) + p32(0) + p32(0)
    commands.append(text)

    commands.append(p32(0x19) + p32(72) + name16("__DATA") + p64(base + text_size) + p64(data_size) + p64(text_size) + p64(data_size) + p32(3) + p32(3) + p32(0) + p32(0))
    commands.append(p32(0x19) + p32(72) + name16("__LINKEDIT") + p64(base + linkedit_offset) + p64(0x100000) + p64(linkedit_offset) + p64(0) + p32(1) + p32(1) + p32(0) + p32(0))

    commands.append(p32(0x80000022) + p32(48) + bytes(40))
    commands.append(p32(0x2) + p32(24) + bytes(16))
    commands.append(p32(0xB) + p32(80) + bytes(72))
    dylinker = b"/usr/lib/dyld\0"
    commands.append(p32(0xE) + p32(32) + p32(12) + dylinker + b"\0" * (32 - 12 - len(dylinker)))
    commands.append(p32(0x1B) + p32(24) + bytes.fromhex("32435465768798a9bacbdcedfe0f1021"))
    commands.append(p32(0x32) + p32(32) + p32(1) + p32(0xE0000) + p32(0) + p32(1) + p32(3) + p32(0))
    commands.append(p32(0x80000028) + p32(24) + p64(entry) + p64(0))
    libsystem = b"/usr/lib/libSystem.B.dylib\0"
    commands.append(p32(0xC) + p32(56) + p32(24) + p32(2) + p32(0x054C0000) + p32(0x10000) + libsystem + b"\0" * (56 - 24 - len(libsystem)))
    commands.append(p32(0x26) + p32(16) + bytes(8))
    commands.append(p32(0x29) + p32(16) + bytes(8))

    header = p32(0xFEEDFACF) + p32(0x01000007) + p32(3) + p32(2) + p32(len(commands)) + p32(sum(map(len, commands))) + p32(0x85) + p32(0) + b"".join(commands)
    return header + bytes(entry - len(header)), base, text_size, data_size, linkedit_offset


def port_catm_source(stage0_sources, output):
    source = (stage0_sources / "AMD64/catm_AMD64.hex2").read_text().split(":ELF_text", 1)[1]
    source = source.replace(
        "\t58                          ; pop_rax                     # Get the number of arguments\n"
        "\t5F                          ; pop_rdi                     # Get the program name\n"
        "\t5F                          ; pop_rdi                     # Get the actual output name",
        "\t4889F3                      ; mov_rbx,rsi                 # Save Darwin argv\n"
        "\t488B7B08                    ; mov_rdi,[rbx+8]             # argv[1]\n"
        "\t4883C3 10                   ; add_rbx, !16                # argv[2]",
        1,
    )
    source = source.replace(
        "\t48C7C0 0C000000             ; mov_rax, %12                # the Syscall # for SYS_BRK\n"
        "\t48C7C7 00000000             ; mov_rdi, %0                 # Get current brk\n"
        "\t0F05                        ; syscall                     # Let the kernel do the work\n"
        "\t4989C6                      ; mov_r14,rax                 # Set our malloc pointer\n\n"
        "\t48C7C0 0C000000             ; mov_rax, %12                # the Syscall # for SYS_BRK\n"
        "\t4C89F7                      ; mov_r14,rax                 # Using current pointer\n"
        "\t4881C7 00001000             ; add_rdi, %0x100000          # Allocate 1MB\n"
        "\t0F05                        ; syscall                     # Let the kernel do the work",
        "\t49BE 0000E00000000000       ; mov_r14, %0xe00000          # Darwin static buffer",
        1,
    )
    source = source.replace(
        "\t5F                          ; pop_rdi                     # Get the actual input name",
        "\t488B3B                      ; mov_rdi,[rbx]               # next argv\n"
        "\t4883C3 08                   ; add_rbx, !8                 # advance argv",
        1,
    )
    replacements = [
        ("48C7C0 02000000", "48C7C0 05000002"),
        ("48C7C6 41020000", "48C7C6 01060000"),
        ("48C7C0 00000000             ; mov_rax, %0                 # the syscall number for read", "48C7C0 03000002             ; mov_rax, %0x2000003           # Darwin read"),
        ("48C7C0 01000000             ; mov_rax, %1                 # the syscall number for write", "48C7C0 04000002             ; mov_rax, %0x2000004           # Darwin write"),
        ("48C7C0 3C000000", "48C7C0 01000002"),
    ]
    for old, new in replacements:
        source = source.replace(old, new)
    output.write_text(source)


def main():
    stage0_sources = pathlib.Path(sys.argv[1])
    hex2 = pathlib.Path(sys.argv[2])
    output_dir = pathlib.Path(sys.argv[3])
    output_dir.mkdir(parents=True, exist_ok=True)

    body_source = output_dir / "catm_AMD64_darwin_body.hex2"
    port_catm_source(stage0_sources, body_source)
    body_binary = output_dir / "catm-body.bin"
    subprocess.check_call([str(hex2), body_source, body_binary])

    header, _base, text_size, data_size, linkedit_offset = macho_header()
    binary = bytearray(header + body_binary.read_bytes())
    data_end = text_size + data_size
    if len(binary) < data_end:
        binary.extend(bytes(data_end - len(binary)))
    if len(binary) < linkedit_offset:
        binary.extend(bytes(linkedit_offset - len(binary)))

    output = output_dir / "catm-darwin"
    output.write_bytes(binary)
    os.chmod(output, 0o755)


if __name__ == "__main__":
    main()
