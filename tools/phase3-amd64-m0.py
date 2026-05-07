#!/usr/bin/env python3
import pathlib
import struct
import sys


def p32(value):
    return struct.pack("<I", value)


def p64(value):
    return struct.pack("<Q", value)


def name16(value):
    return value.encode() + b"\0" * (16 - len(value))


def macho_header_bytes():
    base = 0x600000
    entry = 0x400
    text_size = 0x800000
    data_size = 0x2000000
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
    commands.append(p32(0x1B) + p32(24) + bytes.fromhex("435465768798a9bacbdcedfe0f102132"))
    commands.append(p32(0x32) + p32(32) + p32(1) + p32(0xE0000) + p32(0) + p32(1) + p32(3) + p32(0))
    commands.append(p32(0x80000028) + p32(24) + p64(entry) + p64(0))
    libsystem = b"/usr/lib/libSystem.B.dylib\0"
    commands.append(p32(0xC) + p32(56) + p32(24) + p32(2) + p32(0x054C0000) + p32(0x10000) + libsystem + b"\0" * (56 - 24 - len(libsystem)))
    commands.append(p32(0x26) + p32(16) + bytes(8))
    commands.append(p32(0x29) + p32(16) + bytes(8))
    header = p32(0xFEEDFACF) + p32(0x01000007) + p32(3) + p32(2) + p32(len(commands)) + p32(sum(map(len, commands))) + p32(0x85) + p32(0) + b"".join(commands)
    return header + bytes(entry - len(header)), linkedit_offset


def write_hex2(path, data):
    lines = [":MACHO_base"]
    for index in range(0, len(data), 16):
        lines.append(" ".join(f"{byte:02x}" for byte in data[index : index + 16]))
    lines.append(":MACHO_text")
    path.write_text("\n".join(lines) + "\n")


def port_m0_source(stage0_sources, output):
    source = (stage0_sources / "AMD64/M0_AMD64.hex2").read_text()
    source = source.replace(
        "    58                      ; pop_rax                     # Get the number of arguments\n"
        "    5F                      ; pop_rdi                     # Get the program name\n"
        "    5F                      ; pop_rdi                     # Get the actual input name",
        "    4889F3                  ; mov_rbx,rsi                 # Save Darwin argv\n"
        "    488B7B08                ; mov_rdi,[rbx+8]             # argv[1]",
        1,
    )
    source = source.replace(
        "    5F                      ; pop_rdi                     # Get the actual output name",
        "    488B7B10                ; mov_rdi,[rbx+16]            # argv[2]",
        1,
    )
    source = source.replace(
        "    48C7C0 0C000000         ; mov_rax, %12                # the Syscall # for SYS_BRK\n"
        "    48C7C7 00000000         ; mov_rdi, %0                 # Get current brk\n"
        "    0F05                    ; syscall                     # Let the kernel do the work\n"
        "    4989C4                  ; mov_r12,rax                 # Set our malloc pointer",
        "    49BC 0000E00000000000   ; mov_r12, %0xe00000          # Darwin static heap",
        1,
    )
    source = source.replace(
        "    48C7C0 0C000000         ; mov_rax, %12                # the Syscall # for SYS_BRK\n"
        "    51                      ; push_rcx                    # Protect rcx\n"
        "    4153                    ; push_r11                    # Protect r11\n"
        "    0F05                    ; syscall                     # call the Kernel\n"
        "    415B                    ; pop_r11                     # Restore r11\n"
        "    59                      ; pop_rcx                     # Restore rcx\n",
        "",
        1,
    )
    replacements = [
        (
            "48C7C0 02000000         ; mov_rax, %2                 # the syscall number for open()",
            "48C7C0 05000002         ; mov_rax, %0x2000005       # Darwin open",
        ),
        ("48C7C6 41020000", "48C7C6 01060000"),
        ("48C7C0 00000000         ; mov_rax, %0                 # the syscall number for read", "48C7C0 03000002         ; mov_rax, %0x2000003       # Darwin read"),
        ("48C7C0 01000000         ; mov_rax, %1                 # the syscall number for write", "48C7C0 04000002         ; mov_rax, %0x2000004       # Darwin write"),
        ("48C7C0 3C000000", "48C7C0 01000002"),
    ]
    for old, new in replacements:
        source = source.replace(old, new)
    output.write_text(source)


def main():
    stage0_sources = pathlib.Path(sys.argv[1])
    output_dir = pathlib.Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)
    header, linkedit_offset = macho_header_bytes()
    write_hex2(output_dir / "MACHO-amd64-lowdata.hex2", header)
    port_m0_source(stage0_sources, output_dir / "M0_AMD64_darwin_body.hex2")
    (output_dir / "linkedit-offset").write_text(str(linkedit_offset))


if __name__ == "__main__":
    main()
