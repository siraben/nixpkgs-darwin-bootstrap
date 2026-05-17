#!/usr/bin/env python3
import argparse
import re
import struct
from collections import defaultdict


SHN_UNDEF = 0
SHN_COMMON = 0xFFF2

SHT_SYMTAB = 2
SHT_RELA = 4
SHT_NOBITS = 8

R_X86_64_64 = 1
R_X86_64_PC32 = 2
R_X86_64_32 = 10
R_X86_64_32S = 11
R_X86_64_PLT32 = 4
R_X86_64_GOTPCREL = 9
R_X86_64_GOTPCRELX = 41
R_X86_64_REX_GOTPCRELX = 42


def cstr(data, offset):
    end = data.find(b"\0", offset)
    if end < 0:
        end = len(data)
    return data[offset:end].decode("utf-8", "replace")


def align(value, alignment):
    if alignment <= 1:
        return value
    return (value + alignment - 1) & ~(alignment - 1)


def label_name(name, prefix=""):
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
        safe = name
    else:
        safe = re.sub(r"[^A-Za-z0-9_]", "_", name)
        if not safe or safe[0].isdigit():
            safe = "L_" + safe
        safe = "ELF_" + safe
    if prefix:
        return prefix + safe
    return safe


def parse_elf(path, prefix):
    data = path.read_bytes()
    if data[:4] != b"\x7fELF":
        raise SystemExit(f"{path}: not an ELF file")
    if data[4] != 2 or data[5] != 1:
        raise SystemExit(f"{path}: expected little-endian ELF64")
    if struct.unpack_from("<H", data, 16)[0] != 1:
        raise SystemExit(f"{path}: expected a relocatable object")
    if struct.unpack_from("<H", data, 18)[0] != 62:
        raise SystemExit(f"{path}: expected x86_64 ELF")

    e_shoff = struct.unpack_from("<Q", data, 40)[0]
    e_shentsize = struct.unpack_from("<H", data, 58)[0]
    e_shnum = struct.unpack_from("<H", data, 60)[0]
    e_shstrndx = struct.unpack_from("<H", data, 62)[0]

    sections = []
    for index in range(e_shnum):
        offset = e_shoff + index * e_shentsize
        values = struct.unpack_from("<IIQQQQIIQQ", data, offset)
        sections.append(
            {
                "index": index,
                "name_offset": values[0],
                "type": values[1],
                "flags": values[2],
                "addr": values[3],
                "offset": values[4],
                "size": values[5],
                "link": values[6],
                "info": values[7],
                "addralign": values[8],
                "entsize": values[9],
            }
        )

    shstr = sections[e_shstrndx]
    shstr_data = data[shstr["offset"] : shstr["offset"] + shstr["size"]]
    for section in sections:
        section["name"] = cstr(shstr_data, section["name_offset"])
        if section["type"] == SHT_NOBITS:
            section["data"] = b"\0" * section["size"]
        else:
            section["data"] = data[section["offset"] : section["offset"] + section["size"]]

    symbols = []
    for section in sections:
        if section["type"] != SHT_SYMTAB:
            continue
        strtab = sections[section["link"]]["data"]
        count = section["size"] // section["entsize"]
        for index in range(count):
            offset = section["offset"] + index * section["entsize"]
            st_name, st_info, st_other, st_shndx, st_value, st_size = struct.unpack_from(
                "<IBBHQQ", data, offset
            )
            name = cstr(strtab, st_name) if st_name else ""
            bind = st_info >> 4
            symbol_label_prefix = prefix if bind == 0 and name else ""
            symbol_label_name = label_name(name, symbol_label_prefix) if name else ""
            if bind == 0 and symbol_label_name:
                symbol_label_name = f"{symbol_label_name}_{index}"
            symbols.append(
                {
                    "index": index,
                    "name": name,
                    "label": symbol_label_name,
                    "info": st_info,
                    "bind": bind,
                    "shndx": st_shndx,
                    "value": st_value,
                    "size": st_size,
                }
            )

    relocations = defaultdict(list)
    for section in sections:
        if section["type"] != SHT_RELA:
            continue
        target = section["info"]
        count = section["size"] // section["entsize"]
        for index in range(count):
            offset = section["offset"] + index * section["entsize"]
            r_offset, r_info, r_addend = struct.unpack_from("<QQq", data, offset)
            relocations[target].append(
                {
                    "offset": r_offset,
                    "sym": r_info >> 32,
                    "type": r_info & 0xFFFFFFFF,
                    "addend": r_addend,
                }
            )

    return sections, symbols, relocations


def symbol_label(symbols, sections, labels, symbol_index, addend):
    symbol = symbols[symbol_index]
    if symbol["shndx"] == SHN_UNDEF:
        if addend not in (-4, 0):
            if addend > 0:
                return f"{symbol['label']}_plus_{addend:x}"
            raise SystemExit(
                f"unsupported addend {addend} for external symbol {symbol['name']}"
            )
        return symbol["label"]
    if symbol["shndx"] == SHN_COMMON:
        raise SystemExit(f"common symbol is not yet supported: {symbol['name']}")

    target_section = sections[symbol["shndx"]]
    target_offset = symbol["value"] + addend
    if addend == 0 and symbol["label"]:
        return symbol["label"]
    synthetic = f"{symbol['label']}_plus_{target_offset:x}"
    if synthetic not in labels[target_section["index"]][target_offset]:
        labels[target_section["index"]][target_offset].append(synthetic)
    return synthetic


def mutate_got_load(section_data, relocation):
    offset = relocation["offset"]
    if offset >= 3 and section_data[offset - 2] == 0x8B:
        section_data[offset - 2] = 0x8D
        return
    if offset >= 2 and section_data[offset - 1] == 0x8B:
        section_data[offset - 1] = 0x8D
        return
    raise SystemExit(f"unsupported GOTPCREL instruction at 0x{offset:x}")


def emit_bytes(out, data, start, end):
    line = []
    for byte in data[start:end]:
        line.append(f"!0x{byte:02x}")
        if len(line) == 16:
            out.append(" ".join(line))
            line = []
    if line:
        out.append(" ".join(line))


def emit_section(out, section, symbols, sections, labels, relocations):
    section_data = bytearray(section["data"])
    relocs = {relocation["offset"]: relocation for relocation in relocations[section["index"]]}
    for relocation in relocs.values():
        if relocation["type"] in (
            R_X86_64_GOTPCREL,
            R_X86_64_GOTPCRELX,
            R_X86_64_REX_GOTPCRELX,
        ):
            mutate_got_load(section_data, relocation)

    offset = 0
    section_labels = labels[section["index"]]
    event_offsets = sorted(set(section_labels) | set(relocs) | {len(section_data)})
    event_index = 0
    while offset < len(section_data):
        for label in section_labels.get(offset, []):
            out.append(f":{label}")

        relocation = relocs.get(offset)
        if relocation is None:
            while event_index < len(event_offsets) and event_offsets[event_index] <= offset:
                event_index += 1
            next_offset = event_offsets[event_index] if event_index < len(event_offsets) else len(section_data)
            emit_bytes(out, section_data, offset, next_offset)
            offset = next_offset
            continue

        relocation_type = relocation["type"]
        if relocation_type in (R_X86_64_PC32, R_X86_64_PLT32):
            out.append(
                f"%{symbol_label(symbols, sections, labels, relocation['sym'], relocation['addend'] + 4)}"
            )
            offset += 4
        elif relocation_type in (
            R_X86_64_GOTPCREL,
            R_X86_64_GOTPCRELX,
            R_X86_64_REX_GOTPCRELX,
        ):
            out.append(
                f"%{symbol_label(symbols, sections, labels, relocation['sym'], relocation['addend'] + 4)}"
            )
            offset += 4
        elif relocation_type == R_X86_64_64:
            out.append(
                f"&{symbol_label(symbols, sections, labels, relocation['sym'], relocation['addend'])} !0x00 !0x00 !0x00 !0x00"
            )
            offset += 8
        elif relocation_type in (R_X86_64_32, R_X86_64_32S):
            out.append(
                f"&{symbol_label(symbols, sections, labels, relocation['sym'], relocation['addend'])}"
            )
            offset += 4
        else:
            raise SystemExit(f"unsupported relocation type {relocation_type}")

    for label in section_labels.get(len(section_data), []):
        out.append(f":{label}")


def convert(input_path, output_path, prefix):
    sections, symbols, relocations = parse_elf(input_path, prefix)
    section_by_name = {section["name"]: section for section in sections}

    text = section_by_name.get(".text")
    data = section_by_name.get(".data")
    bss = section_by_name.get(".bss")
    if text is None:
        raise SystemExit("missing .text section")

    labels = defaultdict(lambda: defaultdict(list))
    for symbol in symbols:
        if not symbol["name"] or symbol["shndx"] in (SHN_UNDEF, SHN_COMMON):
            continue
        labels[symbol["shndx"]][symbol["value"]].append(symbol["label"])
        if symbol["bind"] != 0:
            addends = {1, 2}
            addends.update(range(8, min(symbol["size"], 0x300), 8))
            addends.update((0x40C, 0x4D0))
            for addend in sorted(addends):
                if addend < symbol["size"]:
                    labels[symbol["shndx"]][symbol["value"] + addend].append(
                        f"{symbol['label']}_plus_{addend:x}"
                    )

    for section_relocations in relocations.values():
        for relocation in section_relocations:
            relocation_type = relocation["type"]
            if relocation_type in (
                R_X86_64_PC32,
                R_X86_64_PLT32,
                R_X86_64_GOTPCREL,
                R_X86_64_GOTPCRELX,
                R_X86_64_REX_GOTPCRELX,
            ):
                symbol_label(
                    symbols,
                    sections,
                    labels,
                    relocation["sym"],
                    relocation["addend"] + 4,
                )
            elif relocation_type in (R_X86_64_64, R_X86_64_32, R_X86_64_32S):
                symbol_label(
                    symbols,
                    sections,
                    labels,
                    relocation["sym"],
                    relocation["addend"],
                )

    out = []
    emit_section(out, text, symbols, sections, labels, relocations)
    out.append("")
    out.append(":ELF_data")
    out.append(":HEX2_data")
    out.append("")

    if data is not None:
        emit_section(out, data, symbols, sections, labels, relocations)
    if bss is not None and bss["size"]:
        data_size = data["size"] if data is not None else 0
        padding = align(data_size, bss["addralign"]) - data_size
        if padding:
            emit_bytes(out, b"\0" * padding, 0, padding)
        emit_section(out, bss, symbols, sections, labels, relocations)

    output_path.write_text("\n".join(out) + "\n")


def write_symbols(input_path):
    sections, symbols, _ = parse_elf(input_path, "")
    defined = []
    undefined = []
    for symbol in symbols:
        name = symbol["name"]
        if not name or symbol["bind"] == 0:
            continue
        if symbol["shndx"] == SHN_UNDEF:
            undefined.append(name)
        else:
            defined.append(name)

    for name in sorted(set(defined)):
        print(f"D\t{name}")
    for name in sorted(set(undefined)):
        print(f"U\t{name}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prefix", default="")
    parser.add_argument("--symbols", action="store_true")
    parser.add_argument("input")
    parser.add_argument("output", nargs="?")
    args = parser.parse_args()
    if args.symbols:
        write_symbols(pathlib.Path(args.input))
        return
    if args.output is None:
        raise SystemExit("missing output")
    convert(pathlib.Path(args.input), pathlib.Path(args.output), args.prefix)


if __name__ == "__main__":
    import pathlib

    main()
