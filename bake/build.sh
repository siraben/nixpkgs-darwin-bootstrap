#!/bin/sh
## Darwin bootstrap driver — no Nix, no bootstrap-tools, no clang.
##
## Iterates steps/*.sh alphabetically.  Each step expects PATH to
## include both /usr/bin (for the system shell utilities at startup)
## and target/bin (for prior-phase binaries).  Steps write into
## target/bin and target/share.
##
## Trust anchors:
##   - seed/hex0-amd64-darwin       (4 KB Mach-O committed bytes)
##   - sources/*                    (auditable text)
##   - /usr/bin/sh and POSIX utils  (Apple-signed system components)
##   - Darwin kernel + /usr/lib/dyld
set -eu

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
SEED="$ROOT/seed"
SOURCES="$ROOT/sources"
STEPS="$ROOT/steps"
TARGET="$ROOT/target"

export ROOT SEED SOURCES STEPS TARGET

## Reset target on each run for a clean build.
rm -rf "$TARGET"
mkdir -p "$TARGET/bin" "$TARGET/share"

## Restricted PATH: only system /usr/bin and the chain's own outputs.
## NOTE: no nixpkgs paths here.
export PATH="$TARGET/bin:/usr/bin:/bin"

## Byte (C) collation for the whole chain.  gcc-4.6's option machinery
## sorts its .opt records with awk and dedups adjacent identical option
## names; under a UTF-8 locale the attribute strings collate apart, so
## e.g. the two '-C' records are separated by '-CC'/'-c' and dedup fails,
## yielding "redefinition of enumerator 'OPT_C'" in the generated
## options.h.  C collation keeps identical names adjacent.
export LC_ALL=C LANG=C

printf '== bake driver ==\n'
printf '   seed: %s\n' "$SEED"
printf '   target: %s\n' "$TARGET"
printf '   PATH: %s\n' "$PATH"
printf '\n'

step_count=0
for step in "$STEPS"/*.sh; do
  step_name=$(basename "$step" .sh)
  printf '== %s ==\n' "$step_name"
  ## Each step runs in a subshell with the env above.
  ( cd "$ROOT" && /bin/sh "$step" )
  step_count=$((step_count + 1))
  printf '   ok\n\n'
done

printf '== done; %d steps ==\n' "$step_count"
printf 'built binaries:\n'
ls -la "$TARGET/bin/"
