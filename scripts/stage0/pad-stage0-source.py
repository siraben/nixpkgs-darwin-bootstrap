#!/usr/bin/env python3
"""Append zero-byte padding to a .hex0 source so its hex0-assembled binary
reaches a target size.  Used to eliminate the post-hex0 `dd` padding step
that the old chain needed before pre-LINKEDIT vmaddr; with padding baked
into the source, hex0 itself produces a runnable Mach-O.

Usage:  pad-hex0-source.py <source.hex0> <hex0-binary> <target-bytes>
"""
import subprocess
import sys
import tempfile

src_path, hex0_path, target = sys.argv[1], sys.argv[2], int(sys.argv[3])

src_text = open(src_path).read()
## strip any existing padding marker
marker = "## ---- LINKEDIT zero padding ("
if marker in src_text:
    src_text = src_text[: src_text.index(marker)].rstrip() + "\n"

## measure current binary size
with tempfile.NamedTemporaryFile() as tmp_src, tempfile.NamedTemporaryFile() as tmp_out:
    tmp_src.write(src_text.encode())
    tmp_src.flush()
    subprocess.check_call([hex0_path, tmp_src.name, tmp_out.name])
    current = subprocess.check_output(["wc", "-c", tmp_out.name]).split()[0]
    current = int(current)

pad_bytes = target - current
if pad_bytes < 0:
    sys.exit(f"already over target: current={current} target={target}")
if pad_bytes == 0:
    print(f"already at target {target}, nothing to pad")
    sys.exit(0)

footer = (
    f"\n{marker}{pad_bytes} bytes, no whitespace for speed) ----\n"
    + "00" * pad_bytes
    + "\n"
)
open(src_path, "w").write(src_text.rstrip("\n") + "\n" + footer)
print(f"padded {src_path}: meaningful={current} pad={pad_bytes} target={target}")
