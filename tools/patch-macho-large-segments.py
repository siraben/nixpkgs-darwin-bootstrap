#!/usr/bin/env python3
import argparse
import struct


LC_SEGMENT_64 = 0x19
TEXT_SIZE = 0x1100000
DATA_SIZE = 0x2000000
TEXT_VMADDR = 0x600000
DATA_VMADDR = TEXT_VMADDR + TEXT_SIZE
LINKEDIT_VMADDR = DATA_VMADDR + DATA_SIZE


def patch_segment(macho, offset, name, command):
    if name == b"__TEXT":
        macho.seek(offset + 32)
        macho.write(struct.pack("<QQQ", TEXT_SIZE, 0, TEXT_SIZE))
        section_offset = offset + 72
        section = command[72 : 72 + 80]
        if section[:16].split(b"\0", 1)[0] == b"__text":
            macho.seek(section_offset + 40)
            macho.write(struct.pack("<Q", TEXT_SIZE - 0x400))
    elif name == b"__DATA":
        macho.seek(offset + 24)
        macho.write(struct.pack("<QQQQ", DATA_VMADDR, DATA_SIZE, TEXT_SIZE, DATA_SIZE))
    elif name == b"__LINKEDIT":
        macho.seek(offset + 24)
        macho.write(struct.pack("<QQQQ", LINKEDIT_VMADDR, 0x1000, TEXT_SIZE + DATA_SIZE, 0))


def patch(path):
    with path.open("r+b") as macho:
        header = macho.read(32)
        if len(header) != 32 or header[:4] != b"\xcf\xfa\xed\xfe":
            raise SystemExit(f"{path}: expected little-endian Mach-O 64")
        ncmds = struct.unpack_from("<I", header, 16)[0]
        offset = 32
        for _ in range(ncmds):
            macho.seek(offset)
            command_header = macho.read(8)
            if len(command_header) != 8:
                raise SystemExit(f"{path}: truncated load command")
            cmd, cmdsize = struct.unpack("<II", command_header)
            macho.seek(offset)
            command = macho.read(cmdsize)
            if len(command) != cmdsize:
                raise SystemExit(f"{path}: truncated load command")
            if cmd == LC_SEGMENT_64:
                name = command[8:24].split(b"\0", 1)[0]
                patch_segment(macho, offset, name, command)
            offset += cmdsize


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("macho")
    args = parser.parse_args()
    patch(pathlib.Path(args.macho))


if __name__ == "__main__":
    import pathlib

    main()
