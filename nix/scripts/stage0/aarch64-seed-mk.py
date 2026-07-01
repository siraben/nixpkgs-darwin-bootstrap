#!/usr/bin/env python3
"""Authoring tool: build the hex0-aarch64-darwin seed binary.

Takes the proven MACHO-aarch64.hex2 template, tightens __TEXT to 16 KB
(so the committed seed and its .hex0 source stay small), places the
assembled hex0 body at the LC_MAIN entry offset (0x2c8), and pads to
the __LINKEDIT file offset.  Signing happens afterwards via codesign.
"""
import re, struct, subprocess, sys

TEMPLATE = "M2libc/aarch64/MACHO-aarch64.hex2"  # run from the repo root
BODY_OBJ = sys.argv[1]
OUT = sys.argv[2]

TEXT_SIZE = 0x4000  # arm64 page size; minimum __LINKEDIT file offset

# --- template bytes ---
hexbytes = []
for line in open(TEMPLATE):
    line = line.split("#")[0].strip()
    if not line or line.startswith(":"):
        continue
    hexbytes += line.split()
hdr = bytearray(bytes.fromhex("".join(hexbytes)))
assert len(hdr) == 0x2C8, hex(len(hdr))

def patch64(off, val):
    hdr[off:off+8] = struct.pack("<Q", val)

# locate segment commands by name
def seg_off(name):
    i = hdr.find(name.encode().ljust(16, b"\0"))
    assert i > 0, name
    return i - 8  # back to cmd field

text = seg_off("__TEXT")          # first match is the segment (section names come later)
patch64(text + 8 + 16 + 8, TEXT_SIZE)        # vmsize
patch64(text + 8 + 16 + 24, TEXT_SIZE)       # filesize
# section_64 __text: starts after the 72-byte segment command
sect = text + 72
assert hdr[sect:sect+6] == b"__text", hdr[sect:sect+16]
patch64(sect + 32, 0x100000000 + 0x2C8)      # addr
patch64(sect + 40, TEXT_SIZE - 0x2C8)        # size
le = hdr.find(b"__LINKEDIT\0")
le -= 8
patch64(le + 8 + 16, 0x100000000 + TEXT_SIZE)  # vmaddr
patch64(le + 8 + 16 + 8, TEXT_SIZE)            # vmsize
patch64(le + 8 + 16 + 16, TEXT_SIZE)           # fileoff
patch64(le + 8 + 16 + 24, 0)                   # filesize (codesign fills)

# --- body bytes from the assembled object ---
txt = subprocess.run(["otool", "-t", BODY_OBJ], capture_output=True, text=True).stdout
body = bytearray()
for line in txt.splitlines():
    m = re.match(r"^[0-9a-f]{8,16}[\t ](.*)$", line)
    if m:
        for w in m.group(1).split():
            body += bytes.fromhex(w)[::-1] if len(w) == 8 else bytes.fromhex(w)
print(f"body: {len(body)} bytes")
assert len(body) % 4 == 0 and len(body) < TEXT_SIZE - 0x2C8

img = bytearray(TEXT_SIZE)
img[:0x2C8] = hdr
img[0x2C8:0x2C8+len(body)] = body
open(OUT, "wb").write(img)
print(f"wrote {OUT} ({len(img)} bytes)")
