# nixpkgs-darwin-bootstrap

Standalone Darwin minimal-bootstrap experiments for reproducing the Linux
`minimal-bootstrap` stage0/M2-Planet/MesCC path as a Darwin Mach-O chain.

The repo has **two parallel tracks**:

- **`bake/` — the no-Nix, from-seed chain** (the primary result). A single
  `sh bake/build.sh` rebuilds the entire toolchain from a committed **4 KB
  `bake/seed/hex0-amd64-darwin` Mach-O seed** + auditable text sources +
  Apple's `/bin/sh`, with no Nix and no prebuilt clang/gcc/as/ld for code
  translation, all the way to a working **gcc-10 `cc1` + `xgcc`** that compile
  and run C. See [`bake/README.md`](bake/README.md), [`bake/STATUS.md`](bake/STATUS.md),
  and [`bake/REVIEW.md`](bake/REVIEW.md) (a codex faithfulness audit). Every host
  tool that did translation / symbol-resolution / binary-layout in the link path
  has been ported to chain-built C (`bake/sources/tools/*.c`, steps 44b–44g), so
  the gcc link path is host-awk-free.

- **The Nix track** (the flake + the per-package top-level directories). The
  Nixified chain reaches a strict self-hosted modern GCC handoff and verifies a
  `gnu-hello-hash-comparison` baseline — described below.

## Current state (Nix track)

The active, runnable bootstrap path is `x86_64-darwin`/amd64.  The Nixified
chain reaches a strict self-hosted modern GCC handoff whose GCC source version
is matched to nixpkgs `gcc_latest.version` (`15.2.0` with the current lock),
and verifies a `gnu-hello-hash-comparison` output at the baseline
`5019a64510837fae43fc7238b506ec11011542432c792b4ab7683db2e7ff2f73`.

The repo follows `~/Git/nixpkgs/pkgs/os-specific/linux/minimal-bootstrap/`
layout: 12 per-package directories (`stage0-posix/`, `mescc-tools/`, `mes/`,
`mescc-libc/`, `tinycc/`, `gnumake/`, `gnupatch/`, `coreutils/`,
`bootstrap-deps/`, `gcc-4.6/`, `gcc-10/`, `gcc-latest/`) totalling ~75 .nix
files.  Each derivation uses a shared `utils.nix:mkDarwin` helper that bakes
in `dontUnpack`/`dontStrip`/`strictDeps`/version/platforms defaults; smoke
tests live in `checkPhase`; every file declares its dependencies explicitly
in nixpkgs-callPackage style.

The implemented amd64 chain is:

1. Raw Darwin/Mach-O seeds: syscall hello probes, a hand-assembled `hex0`,
   Mach-O `hex2` templates using `LC_MAIN`, `/usr/lib/dyld`, and `libSystem`.
2. Stage0 tools (`stage0-posix/`): signed `hex1`, `hex2`, `catm`, `M0`,
   `cc_arch`, `M2`, `blood-macho`, `M1`, full `hex2`, `kaem`.  `hex1` and
   `hex2` are assembled from hand-rolled `hex0/sources/*.hex0` files — no
   perl/awk at build time for the stage0 chain.
3. Mes / mescc-libc / TinyCC: `mes/m2`, the `mescc-libc/*` probes, and the
   `tinycc/*` boot-cycle culminate in `tinycc/darwin-cc` (the working TCC
   used by every downstream GCC build).
4. GCC 4.6 (`gcc-4.6/`): source, all-gcc frontend, libgcc, the bootstrap
   handoff, and `cxx` (C/C++ packaging).  Currently uses `stdenv.cc.cc/clang`
   as bootstrap-host CC because the bootstrapped TCC takes >20h to self-host
   GCC 4.6's frontend.
5. Modern GCC (`gcc-10/`, `gcc-latest/`): `gcc-10/default.nix` builds a
   compiler-only GCC 10.4.0 handoff; `gcc-latest/default.nix` builds the
   nixpkgs-matched `gcc_latest`; `gcc-latest/strict.nix` rebuilds that same
   GCC with the wrapper host shortcuts disabled.
6. Package proof: GNU Hello 2.12.2 builds and runs with the `gcc-latest`
   bootstrap and strict handoffs, alongside a nixpkgs `gcc_latest` reference
   for comparison; the `gnu-hello-hash-comparison` output records all three
   hashes and the equality checks.

## Known impurity boundaries

- The Darwin executable path links against the platform `libSystem`/dyld
  ABI and ad-hoc signs generated Mach-O binaries through nixpkgs
  `darwin.signingUtils`.
- GCC phases use the macOS SDK headers and Apple `as`/`ld`/`cc` tools at
  selected bootstrap boundaries.  All of these are store-pinned
  (`${apple-sdk}`, `${cctools}`, `${darwin.binutils-unwrapped}`); no .nix
  file references `/usr/bin` or the Command Line Tools install dir.
  Pinning the SDK headers to a Nix fetch is a future hardening step.
- `gcc-4.6/cxx` compiles GCC 4.6 sources with the chain compiler
  (phase35 cc1 via the phase37 driver) and uses nixpkgs clang and
  binutils for assembling and linking only.  `gcc-10`, `gcc-latest`, and
  `gcc-latest/strict` all compile their build-helper binaries
  (genmatch, gengtype, build-libcpp) with the chain input compiler
  (GCC_MODERN_HOST_BUILD_CC=0, GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0);
  `gcc-10` and `gcc-latest` ship their own from-stage0 libgcc and
  libstdc++ (GCC_MODERN_BUILD_TARGET_LIBS=1).  No host compiler
  participates in any chain compile; nixpkgs clang/binutils remain at
  the assemble/link boundary only.
- The chain runs on the chain-built `phase39-gnumake` in `gnu-hello`,
  `bootstrap-deps`, `gcc-10`, and `gcc-latest/strict`.  `gcc-latest`
  (phase46) and `gcc-4.6/cxx` (phase44) run nixpkgs `gnumake`; under
  phase39-gnumake, GCC 15's libstdc++ C++23-module rule emits
  self-referential `bits/std.cc` symlinks and the install `cp -RL`
  fails with ELOOP.
- The modern GCC packages carry a staged, patched bootstrap sysroot and
  wrapper metadata sufficient for the current proofs; a full nixpkgs
  compiler/runtime/bintools closure is future work.

## Key commands

On an `x86_64-darwin` builder:

```sh
nix build .#hex0
nix build .#default                       # = gcc-latest strict bootstrap
nix build .#gnu-hello-hash-comparison     # verify against baseline hash
nix flake check
```

Outputs are exposed under both nixpkgs-style per-directory names and
legacy `phaseN-` aliases — pick whichever fits your scripts:

```sh
nix build .#"stage0-posix/kaem"           # = .#phase11-kaem
nix build .#"mescc-tools/macho-patcher"   # = .#phase26g-macho-patcher
nix build .#"mes/m2"                      # = .#phase16-mes-m2
nix build .#"tinycc/darwin-cc"            # = .#phase34-tinycc-darwin-cc
nix build .#"gcc-4.6/bootstrap"           # = .#phase37-gcc46-bootstrap
nix build .#"gcc-latest/strict"           # = .#phase47-gcc-latest-strict-bootstrap
```

From another Darwin host, select the amd64 package set explicitly when needed:

```sh
nix build .#packages.x86_64-darwin."gcc-latest/strict"
nix build .#packages.x86_64-darwin.gnu-hello-hash-comparison
```

## Maintainer scripts

The bootstrap consumes only committed source files; helper scripts under
`scripts/` regenerate the derived inputs when their upstream sources change:

- `scripts/stage0/regen-hex0-sources.sh` — regenerates
  `hex0/sources/hex{1,2}_AMD64_darwin.hex0` from the legacy perl helpers
  kept at `scripts/stage0/legacy/`.
- `scripts/stage0/regen-preported.sh` — regenerates the committed
  `M2libc/amd64/{catm,M0,cc_arch-0}_AMD64_darwin*.hex2` and
  `tools/macho-patcher-m0.M1` from the awk port scripts in `scripts/stage0/`.
- `scripts/refactor/*.py` — the one-shot tools used to do the
  nixpkgs-style layout refactor (drop dead aarch64 branches, hoist smoke
  tests into checkPhase, convert headers to explicit-args).  Kept for
  future similar passes.

Build-time has zero perl/awk/python for `stage0-posix/` (phases 1-11).

## aarch64 status

`aarch64-darwin` has raw syscall smoke coverage, Darwin M2libc checks, a
runnable Mach-O template hello check, and a signed phase-1 `hex1` candidate.
It is not promoted to the trusted bootstrap chain yet: the upstream
`AArch64/hex1_AArch64.hex0` path still needs its ELF-era writable-data model
reworked for high-base Mach-O/`LC_MAIN` Darwin execution.
