#!/usr/bin/env python3
import pathlib
import re
import sys


BASE = 0x600000
ENTRY_OFFSET = 0x400
DATA_FILE_OFFSET = 0x800000
DATA_VM = 0xE00000


def replace_once(source, old, new):
    if old not in source:
        raise ValueError(f"pattern not found: {old!r}")
    return source.replace(old, new, 1)


def port_source(input_path, output_path):
    source = input_path.read_text()

    source = replace_once(source, "58\n5F\n5F\n", "4889F3\n488B7B08\n")
    source = replace_once(source, "5F\n48C7C6\n41020000\n", "488B7B10\n48C7C6\n01060000\n")
    source = replace_once(
        source,
        "48C7C0\n0C000000\n48C7C7\n00000000\n0F05\n4989C5\n",
        "49BD\n0000E00000000000\n",
    )
    source = source.replace("48C7C0\n02000000\n0F05", "48C7C0\n05000002\n0F05")
    source = source.replace("48C7C0\n00000000\n52\n48C7C2\n01000000\n51\n4153\n0F05", "48C7C0\n03000002\n52\n48C7C2\n01000000\n51\n4153\n0F05")
    source = source.replace("48C7C0\n01000000\n52\n48C7C2\n01000000\n51\n4153\n0F05", "48C7C0\n04000002\n52\n48C7C2\n01000000\n51\n4153\n0F05")
    source = source.replace(
        "48C7C0\n0C000000\n51\n4153\n0F05\n415B\n59\n",
        "",
        1,
    )
    source = source.replace("48C7C0\n3C000000\n0F05", "48C7C0\n01000002\n0F05")
    source = replace_once(
        source,
        ":match\n53\n51\n52\n4889C1\n4889DA\n:match_Loop\n",
        ":match\n53\n51\n52\n4889C1\n4889DA\n4881F9\n00100000\n0F8C\n%match_False\n4881FA\n00100000\n0F8C\n%match_False\n:match_Loop\n",
    )
    output_path.write_text(source)


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


def offset_of_label(source, label):
    offset = 0
    found = False
    for line in source.splitlines():
        token = line.split("#", 1)[0].strip()
        if not token:
            continue
        if token == f":{label}":
            found = True
            break
        if token.startswith(":"):
            continue
        offset += hex2_width(token)
    if not found:
        raise ValueError(f"label not found: {label}")
    return offset


def byte_length_after_label(source, label):
    offset = 0
    counting = False
    for line in source.splitlines():
        token = line.split("#", 1)[0].strip()
        if not token:
            continue
        if token == f":{label}":
            counting = True
            continue
        if token.startswith(":"):
            continue
        if counting:
            offset += hex2_width(token)
    return offset


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
    marker = binary.find(b"\x53\x48\x8d\x05")
    if marker < 0:
        raise ValueError("fix_types marker not found")
    lea_position = marker + 1
    next_instruction = BASE + lea_position + 7
    displacement = int.from_bytes(binary[lea_position + 3 : lea_position + 7], "little", signed=True)
    static_vm = next_instruction + displacement
    static_file_offset = static_vm - BASE
    static_length = DATA_FILE_OFFSET - static_file_offset

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
        b"\x48\x8b\x05",
        b"\x48\x8b\x1d",
        b"\x48\x8b\x0d",
        b"\x48\x8b\x15",
        b"\x48\x8b\x35",
        b"\x48\x89\x05",
        b"\x48\x89\x1d",
        b"\x48\x89\x0d",
        b"\x48\x89\x15",
        b"\x88\x05",
        b"\x8a\x05",
    ]:
        patch_rel32(binary, opcode, static_vm, DATA_VM, static_length)

    binary_path.write_bytes(binary)


def main():
    command = sys.argv[1]
    if command == "port":
        port_source(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
    elif command == "patch":
        patch_binary(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
    else:
        raise SystemExit(f"unknown command: {command}")


if __name__ == "__main__":
    main()
