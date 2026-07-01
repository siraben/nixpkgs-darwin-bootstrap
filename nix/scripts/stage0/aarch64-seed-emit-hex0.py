#!/usr/bin/env python3
"""Authoring tool: emit hex0/hex0-aarch64-darwin.hex0 from the signed seed.

The .hex0 source describes every byte of the signed seed binary:
Mach-O header, instruction body (one line per instruction, commented from
the disassembly), zero padding to __LINKEDIT, and the ad-hoc code
signature blob.  hex0(source) reproduces the seed byte-for-byte."""
import re, subprocess, sys

SEED = sys.argv[1]
OBJ = sys.argv[2]
OUT = sys.argv[3]

data = open(SEED, "rb").read()
BODY_OFF = 0x2C8
PAD_OFF = None  # first zero byte after body
SIG_OFF = 0x4000

# disassembly for body comments
dis = subprocess.run(["otool", "-tv", OBJ], capture_output=True, text=True).stdout
insns = []   # (label_or_None, text)
label = None
for line in dis.splitlines():
    if re.match(r"^\w+:$", line):
        label = line[:-1]
        continue
    m = re.match(r"^([0-9a-f]{16})\t(.*)$", line)
    if m:
        insns.append((label, m.group(2).replace("\t", " ")))
        label = None

body_len = len(insns) * 4
pad_start = BODY_OFF + body_len
assert all(b == 0 for b in data[pad_start:SIG_OFF])

w = open(OUT, "w")
w.write("""# hex0-aarch64-darwin.hex0 — Darwin arm64 bootstrap seed assembler.
# Assembling this file with hex0 reproduces hex0/seed/hex0-aarch64-darwin
# byte-for-byte, including the embedded ad-hoc code signature (the
# signature covers the pages before it, so the output remains validly
# signed).  See hex0-aarch64-darwin.S for the audited assembly.

# --- Mach-O header and load commands (MACHO-aarch64 template, 16 KB __TEXT,
# --- __LINKEDIT at 0x4000 carrying the LC_CODE_SIGNATURE blob) ---
""")
for off in range(0, BODY_OFF, 16):
    w.write(" ".join(f"{b:02x}" for b in data[off:min(off+16, BODY_OFF)]) + "\n")

w.write("\n# --- program text (entry 0x2c8): see hex0-aarch64-darwin.S ---\n")
for i, (lbl, txt) in enumerate(insns):
    off = BODY_OFF + i * 4
    if lbl:
        w.write(f"# {lbl}:\n")
    word = data[off:off+4]
    w.write(" ".join(f"{b:02x}" for b in word) + f"  # {txt}\n")

w.write("\n# --- zero padding to the __LINKEDIT file offset (0x4000) ---\n")
n = SIG_OFF - pad_start
full, rem = divmod(n, 32)
for _ in range(full):
    w.write("00 " * 31 + "00\n")
if rem:
    w.write("00 " * (rem - 1) + "00\n")

w.write("\n# --- ad-hoc code signature (SuperBlob: CodeDirectory + wrapper) ---\n")
for off in range(SIG_OFF, len(data), 16):
    w.write(" ".join(f"{b:02x}" for b in data[off:off+16]) + "\n")
w.close()
print(f"emitted {OUT}: source for {len(data)} bytes")
