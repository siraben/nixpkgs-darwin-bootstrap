#!/bin/sh
## 14b-boot-patch — build the chain's minimal unified-diff applier.
##
## The shell track needs committed patch files before TinyCC exists
## (step 22), so this tool is written in the M2-Planet C subset and is
## compiled immediately after the stage0 tool set is complete.  It
## supports the unified-diff subset used by this repo's committed
## patches: modify existing files, `-pN`, `-d DIR`, stdin/file input,
## and idempotent reapplication.
##
## Runs:     M2-darwin (step 08), M1 (step 12), hex2 (step 13),
##           macho-patcher (step 06); Apple dd, chmod, install, grep,
##           cmp, printf for orchestration and checks.
## Inputs:   sources/tools/boot-patch.c plus M2libc full stdio/stdlib/
##           string support.
## Outputs:  target/bin/boot-patch.
## Verifies: smoke test applies a small `-p1 -d DIR` patch and proves
##           re-running the same patch is a no-op.
## Trust:    translation and layout by chain-built tools.  From step 22
##           onward, committed source patches use this binary instead
##           of host /usr/bin/patch.
set -eu

work="$TARGET/work/boot-patch"
rm -rf "$work"
mkdir -p "$work"
cd "$work"

src="$SOURCES/stage0-posix"

M2-darwin \
  --architecture amd64 \
  -f "$src/M2libc/sys/types.h" \
  -f "$src/M2libc/stddef.h" \
  -f "$src/M2libc/sys/utsname.h" \
  -f "$src/M2libc/amd64/Darwin/unistd.c" \
  -f "$src/M2libc/amd64/Darwin/fcntl.c" \
  -f "$src/M2libc/amd64/Darwin/sys/stat.c" \
  -f "$src/M2libc/fcntl.c" \
  -f "$src/M2libc/ctype.c" \
  -f "$src/M2libc/stdlib.c" \
  -f "$src/M2libc/string.c" \
  -f "$src/M2libc/stdarg.h" \
  -f "$src/M2libc/stdio.h" \
  -f "$src/M2libc/stdio.c" \
  -f "$src/M2libc/bootstrappable.c" \
  -f "$SOURCES/tools/boot-patch.c" \
  -o boot-patch.M1

M1 \
  --architecture amd64 \
  --little-endian \
  -f "$src/M2libc/amd64/amd64_defs.M1" \
  -f "$src/M2libc/amd64/libc-full-Darwin.M1" \
  -f boot-patch.M1 \
  -o boot-patch.hex2

if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' boot-patch.hex2; then
  echo "boot-patch hex2 contains untranslated M1 tokens" >&2
  exit 1
fi

hex2 \
  --architecture amd64 \
  --little-endian \
  --base-address 0x600000 \
  -f "$src/M2libc/amd64/MACHO-amd64-lowdata.hex2" \
  -f boot-patch.hex2 \
  -o boot-patch

macho-patcher m2-segments boot-patch.hex2 boot-patch
dd if=/dev/zero of=boot-patch bs=1 count=1 seek=41943039 conv=notrunc 2>/dev/null || true
chmod +x boot-patch
install boot-patch "$TARGET/bin/boot-patch"

tmp="$work/smoke"
mkdir -p "$tmp"
printf 'one\nold\nthree\n' > "$tmp/file.txt"
cat > "$tmp/change.diff" <<'DIFF'
--- a/file.txt
+++ b/file.txt
@@ -1,3 +1,3 @@
 one
-old
+new
 three
DIFF

"$TARGET/bin/boot-patch" -p1 -d "$tmp" < "$tmp/change.diff" > "$tmp/patch.stdout"
grep -qx 'new' "$tmp/file.txt"
cp "$tmp/file.txt" "$tmp/once.txt"
"$TARGET/bin/boot-patch" -p1 -d "$tmp" < "$tmp/change.diff" > "$tmp/repatch.stdout"
cmp -s "$tmp/file.txt" "$tmp/once.txt" \
  || { echo "14b: boot-patch reapplication changed output" >&2; exit 1; }

echo "boot-patch built at $TARGET/bin/boot-patch (chain-built, no host patch)"
