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
  and [`bake/REVIEW.md`](bake/REVIEW.md) (a faithfulness audit). Every host
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
and verifies a `gnu-hello-hash-comparison` output against the pinned baseline
`0854f4ab9cf255a37ddfb6251198164e6f14f3606239c963d2530f77e257f90a` (the
`gcc-latest` and `gcc-latest/strict` GNU Hello builds are byte-identical).
The gate is enforced inside the derivation: `gnu-hello-hash-comparison`
fails the build (and `nix flake check`) if `phase46 != phase47` or if the
hash drifts from the baseline.

This repo requires **git-LFS**: the committed Mach-O seed binaries under
`hex0/sources/**/*.hex0` are LFS-tracked, so install `git lfs` before
cloning/checkout or the seeds arrive as pointer files and the bootstrap
fails opaquely.

No host compiler compiles any chain source: GCC 4.6 is built entirely by
the chain `cc1`, and the modern GCC build helpers compile with the chain
input compiler.  Host `clang`/`binutils`/`cctools` participate only at the
Mach-O assemble/link boundary, with one known exception: `cctools/ar`'s own
`libstuff.a`/`libmacho.a` support archives are still compiled with host
`$CC` and packed with host `ar` while the `ar`/`ranlib` drivers themselves
are chain-compiled (see "Known impurity boundaries").  No host `python`
runs at build time, and the chain runs on its own `gnumake` and `gnupatch`.
Host `awk` is gone from the entire amd64 build-time chain — the M1
code/data split is the chain-built `m1-split` everywhere, and the
mescc-tools helpers are seed-built from committed `.hex0` binary dumps (no
stdenv in the trust path).  The only remaining `awk` is the deferred
aarch64 `stage0-posix/hex1` path and maintainer-only `scripts/`.  The build
scripts themselves run under host `bash` + coreutils/`sed`/`grep`; this Nix
track's purity claim covers the compiler/translator/make trust path, not
the orchestration shell.

The repo follows `~/Git/nixpkgs/pkgs/os-specific/linux/minimal-bootstrap/`
layout: 13 per-package directories (`stage0-posix/`, `mescc-tools/`, `mes/`,
`mescc-libc/`, `tinycc/`, `gnumake/`, `gnupatch/`, `coreutils/`,
`bootstrap-deps/`, `cctools/`, `gcc-4.6/`, `gcc-10/`, `gcc-latest/`)
totalling ~81 .nix files.  Each derivation uses a shared `utils.nix:mkDarwin` helper that bakes
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
   handoff, and `cxx` (C/C++ packaging).  Every GCC 4.6 source compiles
   with the chain `cc1` (the all-gcc frontend driven through the gcc-4.6
   driver, parallelised across cores); host clang and binutils assemble
   and link only.
5. Modern GCC (`gcc-10/`, `gcc-latest/`): `gcc-10/default.nix` builds a
   compiler-only GCC 10.4.0 handoff; `gcc-latest/default.nix` builds the
   nixpkgs-matched `gcc_latest`; `gcc-latest/strict.nix` rebuilds that same
   GCC with external GMP/MPFR/MPC/ISL.  All three compile their build
   helpers with the chain input compiler (no host clang in any chain
   compile) and the modern GCC source is compiled against a committed,
   fully-prepared bootstrap sysroot (`bootstrap/headers/gcc-modern-sysroot`).
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
  (the gcc46-all-gcc cc1 via the gcc46 driver) and uses nixpkgs clang and
  binutils for assembling and linking only.  `gcc-10`, `gcc-latest`, and
  `gcc-latest/strict` all compile their build-helper binaries
  (genmatch, gengtype, build-libcpp) with the chain input compiler
  (GCC_MODERN_HOST_BUILD_CC=0, GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0);
  `gcc-10` and `gcc-latest` ship their own from-stage0 libgcc and
  libstdc++ (GCC_MODERN_BUILD_TARGET_LIBS=1).  No host compiler
  participates in any chain compile; nixpkgs clang/binutils remain at
  the assemble/link boundary only.
- `cctools/ar` chain-compiles the `ar`/`ranlib` drivers with gcc-15, but
  their `libstuff.a`/`libmacho.a` support archives are still compiled with
  host `$CC` and packed with host `${cctools}/bin/ar` (you need an archiver
  to build an archiver). `cctools-ar` is on the GNU Hello proof path (it is
  the `AR`/`RANLIB` for the gnu-hello build), so this support-library host
  compile is a real remaining boundary, tracked for a future from-chain
  rebuild.
- `checks.nix`'s `macho-template-hello-runs` is a validation-only check
  (not a chain artifact): it compiles upstream stage0 `hex2` C with host
  `$CC` to sanity-check the committed Mach-O template. It is not in the
  bootstrap trust path.
- Host `perl` performs the remaining deterministic GCC source/configure
  edits (and the gcc-4.6 libgcc-tree staging in `gcc-4.6/libgcc.pl`).
  This is build-orchestration — applying known diffs to known files,
  the role `gnupatch` plays elsewhere — not translation; converting it
  to committed patches is a remaining hardening step.
- Every phase that shells out to make runs the chain-built
  `bootstrap-gnumake` (GNU Make 4.4.1 compiled by the chain tcc).  The
  bootstrap libc implements getcwd via `fcntl(F_GETPATH)`, so
  `$(abspath)`/`$(realpath)`/`CURDIR` return real paths.
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

Outputs are exposed under plain semantic names and nixpkgs-style
per-directory aliases — pick whichever fits your scripts:

```sh
nix build .#kaem                          # = .#"stage0-posix/kaem"
nix build .#macho-patcher                 # = .#"mescc-tools/macho-patcher"
nix build .#mes-m2                        # = .#"mes/m2"
nix build .#tinycc-darwin-cc              # = .#"tinycc/darwin-cc"
nix build .#gcc46                         # = .#"gcc-4.6/bootstrap"
nix build .#gcc-latest-strict             # = .#"gcc-latest/strict"
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

No host `python` runs at build time anywhere in the chain (`python3`
appears only in design-time `scripts/stage0/regen-*.sh` maintainer
scripts).

Host `awk` has been removed from the **entire amd64 build-time chain**:
the M1 code/data split and cross-object synth-label injection are
chain-built C tools (`bootstrap/m1-split.c`, `bootstrap/synth-inject.c`,
compiled through M2-Planet → M1 → hex2) used uniformly across the
`mescc-libc/*`, `mes/*`, `tinycc/*` boot-cycle, the TinyCC-darwin-cc
wrapper, the GCC link path, and `cctools/ar`.  The `mescc-tools` helpers
(`m1-split`, `m1-to-hex2`, `hex2-data-relocs`, `cc-arch-helper`,
`synth-inject`, `elf64-to-m1`, `macho-patcher`) are seed-built: a
committed `.hex0` dump of each tool's Mach-O binary is re-emitted by
`hex0-raw`, so no stdenv and no host translator sits in their trust path.
The only remaining host `awk` is the deferred `stage0-posix/hex1` aarch64
candidate path and maintainer-only `scripts/`.

Deterministic GCC source/configure edits and the modern-GCC bootstrap
sysroot are committed `.patch` files and committed headers
(`patches/`, `bootstrap/headers/gcc-modern-sysroot`) applied/copied at
build time; the chain-built `gnupatch` applies the patches.  Host `perl`
no longer prepares the modern-GCC sysroot, but still performs the
remaining deterministic edits to *generated* configure outputs
(Makefiles, `config.h`/`config.cache`), a few staged-header tweaks in
`scripts/gcc-4.6/cxx.sh`, and the gcc-4.6 libgcc-tree staging in
`scripts/gcc-4.6/libgcc.pl` — converting those is remaining work.

These build scripts run under **host `bash` and host coreutils/`sed`/
`grep`/`find`** from nixpkgs.  The "no host tools" property of this (Nix)
track is scoped to the *compiler / translator / make / patch trust
path* — what produces the chain artifacts — not to the orchestration
shell.  The fully-from-seed, shell-and-all variant lives in `bake/`.

## aarch64 status

`aarch64-darwin` has raw syscall smoke coverage, Darwin M2libc checks, a
runnable Mach-O template hello check, and a signed phase-1 `hex1` candidate.
It is not promoted to the trusted bootstrap chain yet: the upstream
`AArch64/hex1_AArch64.hex0` path still needs its ELF-era writable-data model
reworked for high-base Mach-O/`LC_MAIN` Darwin execution.
