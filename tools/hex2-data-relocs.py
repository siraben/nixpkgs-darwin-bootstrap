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
    raise ValueError(f"untranslated token in hex2: {token!r}")


def numeric_reference(reference):
    return re.fullmatch(r"[-+]?0x[0-9A-Fa-f]+|[-+]?[0-9]+", reference) is not None


def parse_hex2(source):
    offset = 0
    labels = {}
    relative_references = []
    absolute_references = []
    static_offset = None

    for raw_line in source.splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        for token in line.split():
            if token.startswith(":"):
                label = token[1:]
                labels[label] = offset
                if label in ("ELF_data", "HEX2_data") and static_offset is None:
                    static_offset = offset
                continue
            if token.startswith("%"):
                reference = token[1:]
                if not numeric_reference(reference):
                    relative_references.append((offset, reference))
            elif token.startswith("&"):
                reference = token[1:]
                if not numeric_reference(reference):
                    absolute_references.append((offset, reference))
            offset += hex2_width(token)

    if static_offset is None:
        raise ValueError("static data label not found")
    return static_offset, labels, relative_references, absolute_references


def patch_binary(source_path, binary_path):
    source = source_path.read_text()
    static_offset, labels, relative_references, absolute_references = parse_hex2(source)
    binary = bytearray(binary_path.read_bytes())

    static_file_offset = ENTRY_OFFSET + static_offset
    static_length = len(binary) - static_file_offset
    if len(binary) < DATA_FILE_OFFSET + static_length:
        binary.extend(bytes(DATA_FILE_OFFSET + static_length - len(binary)))
    binary[DATA_FILE_OFFSET : DATA_FILE_OFFSET + static_length] = binary[
        static_file_offset : static_file_offset + static_length
    ]

    for token_offset, reference in relative_references:
        target_offset = labels.get(reference)
        if target_offset is None:
            continue
        if target_offset < static_offset:
            continue
        displacement_position = ENTRY_OFFSET + token_offset
        next_instruction = BASE + displacement_position + 4
        target = DATA_VM + (target_offset - static_offset)
        binary[displacement_position : displacement_position + 4] = (
            target - next_instruction
        ).to_bytes(4, "little", signed=True)

    for token_offset, reference in absolute_references:
        target_offset = labels.get(reference)
        if target_offset is None:
            continue
        if target_offset < static_offset:
            continue
        target = DATA_VM + (target_offset - static_offset)
        position = ENTRY_OFFSET + token_offset
        binary[position : position + 4] = target.to_bytes(4, "little", signed=False)

    binary_path.write_bytes(binary)


def main():
    if sys.argv[1] != "patch":
        raise SystemExit(f"unknown command: {sys.argv[1]}")
    patch_binary(pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))


if __name__ == "__main__":
    main()
