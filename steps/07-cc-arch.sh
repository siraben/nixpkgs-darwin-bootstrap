#!/bin/sh
## 07-cc-arch — build cc_arch, the first C compiler in the chain.
##
## cc_arch is the Darwin port of stage0-posix's cc_amd64: a C-subset
## compiler that reads one C file and emits M1 assembly
## (cc_arch-darwin INPUT.c OUTPUT.M1).  Step 08 uses it to compile
## M2-Planet.  The body is committed hex2 text
## (sources/cc_arch-0-darwin.hex2); catm prepends the lowdata Mach-O
## header template and hex2-darwin assembles.  First use of
## macho-patcher: the m2-segments fixup (see step 06) moves the static
## data to the __DATA file offset and repoints RIP-rel32
## displacements.  Mirrors cc-arch.nix.
##
## Runs:     catm-darwin (step 04), hex2-darwin (step 03),
##           macho-patcher (step 06); Apple cp, dd, chmod, grep; the
##           fresh cc_arch-darwin for its own smoke test.
## Inputs:   sources/MACHO-amd64-lowdata.hex2,
##           sources/cc_arch-0-darwin.hex2.
## Outputs:  target/bin/cc_arch-darwin.
## Verifies: smoke test — run cc_arch with no arguments and grep the
##           captured output for the M1 section banners it emits.
##           The banners are string constants in the relocated data
##           segment, so their presence shows the binary loads, runs,
##           and addresses __DATA after the m2-segments fixup.
## Trust:    translation and layout by chain-built catm + hex2-darwin
##           + macho-patcher.  Apple dd appends content-free zero
##           padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/cc-arch"; mkdir -p "$work"; cd "$work"
## macho-patcher reads the body source (without the header template)
## to locate the first data label, so keep a local copy of the body.
cp "$SOURCES/cc_arch-0-darwin.hex2" cc_arch-0.hex2
catm-darwin cc_arch.hex2 "$SOURCES/MACHO-amd64-lowdata.hex2" cc_arch-0.hex2
hex2-darwin cc_arch.hex2 "$TARGET/bin/cc_arch-darwin"
macho-patcher m2-segments cc_arch-0.hex2 "$TARGET/bin/cc_arch-darwin"
## Pad to the 0x2800000 __LINKEDIT file offset (see step 05).
dd if=/dev/zero of="$TARGET/bin/cc_arch-darwin" bs=1 count=1 seek=41943039 conv=notrunc
chmod +x "$TARGET/bin/cc_arch-darwin"

## Smoke test: run with no arguments (exit status ignored via
## || true); the banner strings must appear in the captured output.
cc_arch-darwin > out 2>&1 || true
grep -q '^# Core program$' out
grep -q '^# Program global variables$' out
