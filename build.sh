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
##   - sources/*                    (committed auditable text: stage0-posix,
##                                   the hand-written tools, patches, scripts)
##   - tarballs/*                   (upstream mes/gcc-4.6/gcc-10 release tarballs,
##                                   NOT committed — fetched by scripts/fetch-
##                                   sources.sh against pinned SHA-256 hashes)
##   - /bin/sh and POSIX utils      (Apple-signed system components: sh, make,
##                                   tar, cp, nm, system cc/ld for the final
##                                   goal-test exe link — the chain has no native
##                                   Mach-O exe linker)
##   - host source-prep tools       (NOT yet ported to the chain in the shell
##                                   track: host awk for the early M1 code/data
##                                   splits; host python3 in step 53b and host
##                                   perl in scripts/phase13-* for gcc text edits;
##                                   committed patches are applied by chain-built
##                                   boot-patch from step 14b; host /usr/bin/cc
##                                   + ar for the libgcc
##                                   EH/unwind stub archive in step 55 — see
##                                   docs/REVIEW.md / docs/STATUS.md)
##   - Darwin kernel + /usr/lib/dyld
set -eu

ROOT="$(cd -- "$(dirname -- "$0")" && pwd)"
SEED="$ROOT/seed"
SOURCES="$ROOT/sources"
STEPS="$ROOT/steps"
## TARGET defaults to $ROOT/target but may be overridden, so a reproducibility
## verification run can build into a scratch dir without destroying an existing
## target tree:  TARGET=/path/to/scratch sh build.sh
TARGET="${TARGET:-$ROOT/target}"

## Contract with steps/*.sh: every step locates its inputs and outputs
## through these five exported variables plus PATH; steps take no
## positional arguments.
export ROOT SEED SOURCES STEPS TARGET

## Reset target on each run for a clean build — UNLESS resuming via
## $BOOT_START_FROM (skip the wipe so an existing partial target is reused, e.g.
## to re-run a fixed late step without redoing the multi-hour gcc builds).
if [ -z "${BOOT_START_FROM:-}" ]; then
  rm -rf "$TARGET"
fi
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

printf '== bootstrap driver ==\n'
printf '   seed: %s\n' "$SEED"
printf '   target: %s\n' "$TARGET"
printf '   PATH: %s\n' "$PATH"
printf '\n'

## Optional: stop after the step whose name starts with $BOOT_STOP_AFTER, e.g.
##   BOOT_STOP_AFTER=14 TARGET=/tmp/boot-verify sh build.sh
## runs phases up to and including 14-kaem.  Useful for incremental
## reproducibility verification without a full multi-hour run.
## Optional: skip every step before the one whose name starts with
## $BOOT_START_FROM (combined with not wiping TARGET above, this resumes a
## partial build), e.g.  BOOT_START_FROM=54 TARGET=/tmp/boot-verify sh build.sh
step_count=0
started=1
[ -n "${BOOT_START_FROM:-}" ] && started=0
for step in "$STEPS"/*.sh; do
  step_name=$(basename "$step" .sh)
  if [ "$started" -eq 0 ]; then
    case "$step_name" in
      "$BOOT_START_FROM"*) started=1 ;;
      *) continue ;;
    esac
  fi
  printf '== %s ==\n' "$step_name"
  ## Each step runs in a subshell with the env above, with stdin from
  ## /dev/null.  Configure scripts probe `make -f -` (read a makefile from
  ## stdin); our chain make can't create the stdin temp file and errors — but
  ## only if stdin is at EOF.  If build.sh inherits an open pipe as stdin (e.g.
  ## launched under nohup from a pipe), that `make -f -` blocks forever waiting
  ## for EOF and wedges the configure (seen at gmp-6.2.1's nested-variables
  ## check in gcc-10's step 55).  /dev/null gives immediate EOF so the probe
  ## fails fast and configure proceeds; no build step needs real stdin.
  ( cd "$ROOT" && /bin/sh "$step" </dev/null )
  step_count=$((step_count + 1))
  printf '   ok\n\n'
  case "${BOOT_STOP_AFTER:-}" in
    '') ;;
    *) case "$step_name" in
         "$BOOT_STOP_AFTER"*) printf '== stopping after %s (BOOT_STOP_AFTER) ==\n' "$step_name"; break ;;
       esac ;;
  esac
done

printf '== done; %d steps ==\n' "$step_count"
printf 'built binaries:\n'
ls -la "$TARGET/bin/"
