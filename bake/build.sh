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
## TARGET defaults to $ROOT/target but may be overridden, so a reproducibility
## verification run can build into a scratch dir without destroying an existing
## target tree:  TARGET=/path/to/scratch sh bake/build.sh
TARGET="${TARGET:-$ROOT/target}"

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

## Optional: stop after the step whose name starts with $BAKE_STOP_AFTER, e.g.
##   BAKE_STOP_AFTER=14 TARGET=/tmp/bake-verify sh bake/build.sh
## runs phases up to and including 14-kaem.  Useful for incremental
## reproducibility verification without a full multi-hour run.
step_count=0
for step in "$STEPS"/*.sh; do
  step_name=$(basename "$step" .sh)
  printf '== %s ==\n' "$step_name"
  ## Each step runs in a subshell with the env above.
  ( cd "$ROOT" && /bin/sh "$step" )
  step_count=$((step_count + 1))
  printf '   ok\n\n'
  case "${BAKE_STOP_AFTER:-}" in
    '') ;;
    *) case "$step_name" in
         "$BAKE_STOP_AFTER"*) printf '== stopping after %s (BAKE_STOP_AFTER) ==\n' "$step_name"; break ;;
       esac ;;
  esac
done

printf '== done; %d steps ==\n' "$step_count"
printf 'built binaries:\n'
ls -la "$TARGET/bin/"
