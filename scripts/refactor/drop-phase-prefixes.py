#!/usr/bin/env python3
"""Rename phaseN-* attribute/binding names to semantic names.

Attribute names never enter derivation hashes, so this pass must leave
every drvPath unchanged — verify with nix eval before/after.  Lines that
set pname/name string literals are skipped: package names live in the
derivations and their compression batches with the next full rebuild.
"""
import re, subprocess, sys

MAP = {
    "phase1-hex1": "hex1",
    "phase2-catm": "catm",
    "phase2-hex2": "hex2-0",
    "phase3-m0": "m0",
    "phase4-cc-arch": "cc-arch",
    "phase5-m2": "m2",
    "phase6-blood-macho-0": "blood-macho-0",
    "phase7-m1-0": "m1-0",
    "phase8-hex2-1": "hex2-1",
    "phase9-m1": "m1",
    "phase10-hex2": "hex2",
    "phase11-kaem": "kaem",
    "phase11b-m1-to-hex2": "m1-to-hex2",
    "phase11c-hex2-data-relocs": "hex2-data-relocs",
    "phase11d-cc-arch-helper": "cc-arch-helper",
    "phase11e-macho-patcher-early": "macho-patcher-early",
    "phase12-m2-planet": "m2-planet",
    "phase13-mes-source": "mes-source",
    "phase14-mes-m2-probe": "mes-m2-probe",
    "phase15-mes-macho-link-probe": "mes-macho-link-probe",
    "phase16-mes-m2": "mes-m2",
    "phase17-mescc-macho-probe": "mescc-macho-probe",
    "phase18-mescc-libc-mini-probe": "mescc-libc-mini-probe",
    "phase19-tinycc-mescc-m1-probe": "tinycc-mescc-m1-probe",
    "phase20-mescc-libmescc-probe": "mescc-libmescc-probe",
    "phase21-mescc-libc-probe": "mescc-libc-probe",
    "phase22-mescc-libc-tcc-probe": "mescc-libc-tcc-probe",
    "phase23-tinycc-mescc-link-probe": "tinycc-mescc-link-probe",
    "phase24-tinycc-compile-probe": "tinycc-compile-probe",
    "phase25-tinycc-self-object-probe": "tinycc-self-object-probe",
    "phase26-gcc46-source": "gcc46-source",
    "phase26b-elf64-to-m1": "elf64-to-m1",
    "phase26c-bootstrap-gmp": "bootstrap-gmp",
    "phase26d-bootstrap-mpfr": "bootstrap-mpfr",
    "phase26e-bootstrap-mpc": "bootstrap-mpc",
    "phase26f-bootstrap-isl": "bootstrap-isl",
    "phase26g-macho-patcher": "macho-patcher",
    "phase27-tinycc-elf-to-macho-probe": "tinycc-elf-to-macho-probe",
    "phase28-tinycc-self-m1-probe": "tinycc-self-m1-probe",
    "phase29-tinycc-sysv-libc-probe": "tinycc-sysv-libc-probe",
    "phase30-tinycc-self-link-candidate": "tinycc-self-link-candidate",
    "phase31-tinycc-self-compile-probe": "tinycc-self-compile-probe",
    "phase32-tinycc-boot1-object-probe": "tinycc-boot1-object-probe",
    "phase33-tinycc-boot1-link-candidate": "tinycc-boot1-link-candidate",
    "phase34-tcc": "tcc",
    "phase34-tinycc-darwin-cc": "tinycc-darwin-cc",
    "phase35-gcc46-all-gcc": "gcc46-all-gcc",
    "phase35-tinycc-boot2-object-probe": "tinycc-boot2-object-probe",
    "phase36-gcc46-libgcc": "gcc46-libgcc",
    "phase36-tinycc-boot2-link-candidate": "tinycc-boot2-link-candidate",
    "phase37-gcc46-bootstrap": "gcc46",
    "phase37-tinycc-boot3-object-probe": "tinycc-boot3-object-probe",
    "phase38-tinycc-boot3-link-candidate": "tinycc-boot3-link-candidate",
    "phase39-gnumake": "bootstrap-gnumake",
    "phase39b-cctools": "cctools-ar",
    "phase40-gnupatch": "gnupatch",
    "phase41-coreutils": "coreutils-boot",
    "phase42-gcc10-source": "gcc10-source",
    "phase43-gcc-latest-source": "gcc-latest-source",
    "phase44-gcc46-cxx-bootstrap": "gcc46-cxx",
    "phase45-gcc10-bootstrap": "gcc10",
    "phase46-gcc-latest-bootstrap": "gcc-latest",
    "phase47-gcc-latest-strict-bootstrap": "gcc-latest-strict",
}

SKIP_LINE = re.compile(r'^\s*(pname|name)\s*=\s*"')
# longest first so phase34-tinycc-darwin-cc wins over phase34-tcc etc.
ordered = sorted(MAP.items(), key=lambda kv: -len(kv[0]))
pattern = re.compile(
    "(" + "|".join(re.escape(k) for k, _ in ordered) + r")(?![a-z0-9-])"
)

files = subprocess.run(
    ["git", "ls-files", "*.nix", "*.md", "scripts/impure"],
    capture_output=True, text=True,
).stdout.split()

changed = 0
for path in files:
    with open(path) as f:
        lines = f.readlines()
    out, touched = [], False
    for line in lines:
        if SKIP_LINE.match(line):
            out.append(line)
            continue
        new = pattern.sub(lambda m: MAP[m.group(1)], line)
        if new != line:
            touched = True
        out.append(new)
    if touched:
        with open(path, "w") as f:
            f.writelines(out)
        changed += 1
print(f"rewrote {changed} files")
