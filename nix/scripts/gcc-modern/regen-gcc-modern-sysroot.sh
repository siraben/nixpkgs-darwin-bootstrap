#!/usr/bin/env bash
# regen-gcc-modern-sysroot.sh — regenerate the committed prepared sysroot
# headers (nix/bootstrap/headers/gcc-modern-sysroot) from the chain TinyCC
# bootstrap headers.
#
# Design-time maintainer script; the Nix build never runs it.  Run it
# whenever nix/bootstrap/headers/tcc-darwin-bootstrap changes.
#
# The modern GCC phases (gcc-10, gcc-latest, gcc-latest/strict) compile
# their C/C++ sources against this sysroot.  Relative to the chain tcc
# headers it adds: nine created headers (crt_externs.h, sys/times.h,
# ftw.h, getopt.h, wchar.h, wctype.h, AvailabilityMacros.h, xlocale.h,
# locale.h) and C++ `extern "C"` guards plus missing declarations on ~17
# existing headers.  The additions are committed source files copied
# verbatim at build time (no host perl).
#
# This script extracts the prepared set straight out of a built
# gcc-latest-strict (whose $out/$target/include IS the prepared sysroot,
# a fixed point: the modern GCC phases re-apply the idempotent edits and
# converge).  Build the chain first, then run this to refresh the
# committed copy if the inputs changed.
set -euo pipefail

cd "$(dirname "$0")/../.."   # the nix/ tree

P=$(nix path-info .#packages.x86_64-darwin.gcc-latest-strict 2>/dev/null) || {
  echo "regen-gcc-modern-sysroot: build .#gcc-latest-strict first" >&2
  exit 1
}
src="$P/x86_64-apple-darwin/include"
[ -d "$src" ] || { echo "no prepared sysroot at $src" >&2; exit 1; }

dst=bootstrap/headers/gcc-modern-sysroot
rm -rf "$dst"
mkdir -p "$dst"
cp -R "$src/." "$dst/"
chmod -R u+w "$dst"
echo "regenerated $dst ($(find "$dst" -type f | wc -l | tr -d ' ') files)"
