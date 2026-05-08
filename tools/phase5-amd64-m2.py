#!/usr/bin/env python3
import pathlib
import re
import sys


BASE = 0x600000
ENTRY_OFFSET = 0x400
DATA_FILE_OFFSET = 0x800000
DATA_VM = 0xE00000


def hex2_width(token):
    if token.startswith("!"):
        return 1
    if token.startswith("@") or token.startswith("$"):
        return 2
    if token.startswith("%") or token.startswith("&"):
        return 4
    if re.fullmatch(r"[0-9A-Fa-f]+", token) and len(token) % 2 == 0:
        return len(token) // 2
    return 0


def hex2_line_width(line):
    width = 0
    for token in line.split():
        token_width = hex2_width(token)
        if token_width == 0:
            raise ValueError(f"untranslated token in hex2: {line!r}")
        width += token_width
    return width


def first_static_offset(source):
    offset = 0
    for line in source.splitlines():
        token = line.split("#", 1)[0].strip()
        if not token:
            continue
        if (
            token == ":ELF_data"
            or token == ":HEX2_data"
            or token.startswith(":GLOBAL_")
            or token.startswith(":STRING_")
            or token.startswith(":_string_")
        ):
            return offset
        if token.startswith(":"):
            continue
        offset += hex2_line_width(token)
    raise ValueError("static data label not found")


def patch_rel32(binary, opcode, static_vm, data_vm, data_length):
    start = 0
    while True:
        position = binary.find(opcode, start)
        if position < 0:
            break
        displacement_position = position + len(opcode)
        next_instruction = BASE + displacement_position + 4
        displacement = int.from_bytes(
            binary[displacement_position : displacement_position + 4],
            "little",
            signed=True,
        )
        target = next_instruction + displacement
        if static_vm <= target < static_vm + data_length:
            new_target = data_vm + (target - static_vm)
            binary[displacement_position : displacement_position + 4] = (
                new_target - next_instruction
            ).to_bytes(4, "little", signed=True)
        start = displacement_position + 4


def patch_binary(source_path, binary_path):
    source = source_path.read_text()
    binary = bytearray(binary_path.read_bytes())

    static_file_offset = ENTRY_OFFSET + first_static_offset(source)
    static_vm = BASE + static_file_offset
    static_length = len(binary) - static_file_offset

    if len(binary) < DATA_FILE_OFFSET + static_length:
        binary.extend(bytes(DATA_FILE_OFFSET + static_length - len(binary)))
    binary[DATA_FILE_OFFSET : DATA_FILE_OFFSET + static_length] = binary[
        static_file_offset : static_file_offset + static_length
    ]

    for opcode in [
        b"\x48\x8d\x05",
        b"\x48\x8d\x1d",
        b"\x48\x8d\x0d",
        b"\x48\x8d\x15",
        b"\x48\x8d\x35",
        b"\x48\x8d\x3d",
        b"\x4c\x8d\x05",
        b"\x4c\x8d\x0d",
        b"\x4c\x8d\x15",
        b"\x4c\x8d\x1d",
        b"\x48\x8b\x05",
        b"\x48\x8b\x1d",
        b"\x48\x8b\x0d",
        b"\x48\x8b\x15",
        b"\x48\x8b\x35",
        b"\x48\x8b\x3d",
        b"\x4c\x8b\x05",
        b"\x4c\x8b\x0d",
        b"\x4c\x8b\x15",
        b"\x4c\x8b\x1d",
        b"\x48\x89\x05",
        b"\x48\x89\x1d",
        b"\x48\x89\x0d",
        b"\x48\x89\x15",
        b"\x48\x89\x35",
        b"\x48\x89\x3d",
        b"\x4c\x89\x05",
        b"\x4c\x89\x0d",
        b"\x4c\x89\x15",
        b"\x4c\x89\x1d",
        b"\x88\x05",
        b"\x8a\x05",
    ]:
        patch_rel32(binary, opcode, static_vm, DATA_VM, static_length)

    binary_path.write_bytes(binary)


def main():
    if sys.argv[1] != "patch":
        raise SystemExit(f"unknown command: {sys.argv[1]}")
    patch_binary(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))


if __name__ == "__main__":
    main()
