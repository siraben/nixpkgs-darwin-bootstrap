#!/usr/bin/env python3
from pathlib import Path


path = Path("hex1-body.hex0")
source = path.read_text()
replacements = [
    (
        "E10B40F9",
        "ef0301aa\n"
        "000080d2\n"
        "0102a0d2\n"
        "620080d2\n"
        "430082d2\n"
        "04008092\n"
        "050080d2\n"
        "b01880d2\n"
        "011000d4\n"
        "ec0300aa\n"
        "e10540f9",
        1,
    ),
    ("E10F40F9", "e10940f9", 1),
    ("600C8092", "e00301aa", -1),
    ("020080D2", "010080d2\n020080d2", 1),
    ("224880D2", "21c080d2", -1),
    ("033880D2", "023880d2", -1),
    ("080780D2", "b00080d2", -1),
    ("A80B80D2", "300080d2", -1),
    ("C80780D2", "f01880d2", -1),
    ("E80780D2", "700080d2", -1),
    ("080880D2", "900080d2", -1),
    ("010000D4", "011000d4", -1),
    ("0D0CA0D2", "ed030caa", -1),
]

for old, new, count in replacements:
    if count < 0:
        source = source.replace(old, new)
    else:
        source = source.replace(old, new, count)

path.write_text(source)
