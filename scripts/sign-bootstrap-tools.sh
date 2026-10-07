#!/bin/sh
# Opt-in host execution metadata for already chain-built Mach-O executables.
# Never sign source, ELF objects, scripts, symlinks, or immutable store inputs.
# Sign a replacement inode: changing a previously executed inode in place can
# leave Darwin's code-signature cache stale. No compiler/linker is invoked.
set -eu
[ "${BOOT_SIGN_EXECUTABLES:-0}" = 1 ] || exit 0
for tool in "$@"; do
  [ -f "$tool" ] && [ -x "$tool" ] && [ ! -L "$tool" ] || continue
  case "$tool" in /nix/store/*) echo "refusing to modify store input: $tool" >&2; exit 1 ;; esac
  magic=$(/usr/bin/od -An -tx1 -N4 "$tool" | /usr/bin/tr -d ' \n')
  [ "$magic" = cffaedfe ] || continue
  if /usr/bin/codesign --verify --strict "$tool" >/dev/null 2>&1; then
    continue
  fi
  temporary=$(/usr/bin/mktemp "$tool.signed.XXXXXX")
  trap '/bin/rm -f "$temporary"' EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  /bin/cp -p "$tool" "$temporary"
  /bin/chmod u+w,go-w "$temporary"
  /usr/bin/codesign --force --sign - --timestamp=none \
    --identifier "${tool##*/}" "$temporary"
  /usr/bin/codesign --verify --strict "$temporary"
  /bin/mv -f "$temporary" "$tool"
  trap - EXIT HUP INT TERM
  /usr/bin/codesign --verify --strict "$tool"
done
