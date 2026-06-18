#!/usr/bin/env bash
# regen-gcc-modern-patches.sh — regenerate the committed per-version GCC
# source/configure patches (patches/gcc-modern/gcc-<version>-source-edits.patch).
#
# Design-time maintainer script; the Nix build never runs it.  Run it
# when the gcc-10/gcc-latest source version changes.
#
# These are the deterministic pre-build edits the modern GCC phases need
# (C++ extern-C guards, Darwin spec fixes, disabled selftests, glibc
# version stubs, --disable-float128, libemutls/libheapt removal, etc.).
# They used to run as ~25 host-perl substitutions inside bootstrap-gcc.sh;
# they are now committed patches applied by the chain-built gnupatch.
#
# Derivation: this script replays the historical perl edits (kept in git
# history at scripts/gcc-modern/bootstrap-gcc.sh before this commit)
# against each pristine source tree and captures the diff.  Re-deriving
# from scratch needs that perl block; for a version bump, apply the prior
# patch with fuzz, fix rejects by hand, and re-emit.
set -euo pipefail
echo "regen-gcc-modern-patches: see git history of bootstrap-gcc.sh for the" >&2
echo "perl edits these patches replace; regenerate by replaying them against" >&2
echo "the new gcc-<version>-source tree and 'diff -ru pristine src'." >&2
