#!/bin/sh
## 04-catm — build catm, the syscall-only file concatenator.
##
## Usage: catm-darwin OUTPUT INPUT...  (opens OUTPUT with
## O_WRONLY|O_CREAT|O_TRUNC, then appends each INPUT).  Later steps use
## it to join Mach-O header templates, libc .M1 files, and program
## bodies before assembling, so file combination happens inside the
## chain.  hex2-darwin accepts a single input file, so the header
## template and the catm body are assembled separately and their raw
## outputs joined with Apple cat — the one step that needs cat for
## this; every later step uses catm itself.  Mirrors catm.nix.
##
## Runs:     hex2-darwin (step 03); Apple cat, wc, dd, chmod, echo,
##           printf, cmp; the fresh catm-darwin for its own smoke test.
## Inputs:   sources/MACHO-amd64-catm-header.hex2,
##           sources/catm_AMD64_darwin_body.hex2.
## Outputs:  target/bin/catm-darwin.
## Verifies: smoke test — concatenate two files and cmp against the
##           expected bytes, proving argv handling and the
##           open/read/write loop work.
## Trust:    translation by chain-built hex2-darwin.  Apple cat joins
##           the two assembled parts byte-wise; Apple dd appends
##           content-free zero padding; /bin/sh orchestrates.
set -eu

work="$TARGET/work/catm"; mkdir -p "$work"; cd "$work"
hex2-darwin "$SOURCES/MACHO-amd64-catm-header.hex2" header.bin
hex2-darwin "$SOURCES/catm_AMD64_darwin_body.hex2" body.bin
cat header.bin body.bin > "$TARGET/bin/catm-darwin"

## Pad to 0x900000 bytes, the __LINKEDIT file offset in the catm header
## template (its __DATA is 1 MiB, smaller than the 32 MiB layout used
## from step 05 on, hence the smaller pad target).  dd fills the gap
## with zeros only when the file is shorter.
dataEnd=9437184  ## 0x900000
cur=$(wc -c < "$TARGET/bin/catm-darwin")
if [ "$cur" -lt "$dataEnd" ]; then
  dd if=/dev/zero of="$TARGET/bin/catm-darwin" bs=1 count=$((dataEnd - cur)) seek="$cur" conv=notrunc 2>/dev/null
fi
chmod +x "$TARGET/bin/catm-darwin"

## Smoke test
echo foo > a; echo bar > b
catm-darwin out a b
printf 'foo\nbar\n' > expected
cmp expected out
