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

This repo uses **git-LFS** for the `hex0/sources/**/*.hex0` files (now just
the genuine, tiny `hex1`/`hex2` machine-code sources), so install `git lfs`
before cloning/checkout or they arrive as pointer files and the bootstrap
fails opaquely.  The one committed binary, the 4 KB `hex0/seed/hex0-amd64-darwin`
seed, is tracked directly (not LFS).

On Apple Silicon the whole chain is `x86_64`/amd64 and runs under **Rosetta
2**: the flake maps `aarch64-darwin` to the `x86_64-darwin` package set, so
`nix build .#default` builds the real chain under Rosetta — add
`extra-platforms = x86_64-darwin` to `nix.conf` first.

No host compiler compiles any chain source: GCC 4.6 is built entirely by
the chain `cc1`, and the modern GCC build helpers compile with the chain
input compiler.  Host `clang`/`binutils`/`cctools` participate only at the
Mach-O assemble/link/archive boundary.  `cctools/ar`'s `ar`/`ranlib`
drivers **and** their `libstuff.a`/`libmacho.a` support archives are
chain-compiled by gcc-15, but those archives are still *packed* with host
`ar`, and host `ar` is also used to extract/pack archives in the tcc-darwin-cc
link path and the bootstrap-deps/coreutils builds (see "Known impurity
boundaries").  No host `python` runs in the **Nix-track** build at run time,
and the chain runs on its own chain-built `gnumake`/`gnupatch` — with the
exception that gcc-4.6's `all-gcc` step still invokes the stdenv (nixpkgs)
`make` (gcc-4.6/cxx, gcc-10/15 and gnu-hello use `bootstrap-gnumake`).

Host `awk` is gone from the entire amd64 build-time chain (Nix track) — the
M1 code/data split is the chain-built `m1-split` everywhere.  **The trust
root is a single 4 KB `hex0` seed** (`hex0/seed/hex0-amd64-darwin`); a
second committed seed, the 34 KB `hex0/seed/hex0-aarch64-darwin`, exists only
for the deferred *native* aarch64 path and is not on the Rosetta default
chain.  Every stage0 tool (`hex1`, `hex2`, `catm`, `M0`, `cc_arch`,
`macho-patcher-early`) and every mescc-tools helper (`m1-split`, `m1-to-hex2`,
`elf64-to-m1`, `synth-inject`, `hex2-data-relocs`, `cc-arch-helper`,
`macho-patcher`) is now built live from committed source (C / hand-written
`.M1` / `.hex2`) through the chain, byte-identical to the old frozen binary
dumps.  `hex1`/`hex2` carry genuine hand-documented `hex0` machine-code source
(no padding blob — the LINKEDIT padding is reapplied by `dd` at build time).
The only remaining `awk` is the deferred aarch64 `stage0-posix/hex1` path and
maintainer-only `scripts/`.  The build scripts themselves run under host
`bash` + coreutils/`sed`/`grep`; this Nix track's purity claim covers the
compiler/translator trust path, not the orchestration shell.  (The `bake/`
track makes the same chain claim but additionally uses host `python3`/`perl`/
`awk`/`patch` and a host-`cc` EH-stub compile in source-prep — see
`bake/README.md` / `bake/REVIEW.md`.)

The repo follows `~/Git/nixpkgs/pkgs/os-specific/linux/minimal-bootstrap/`
layout: 13 per-package directories (`stage0-posix/`, `mescc-tools/`, `mes/`,
`mescc-libc/`, `tinycc/`, `gnumake/`, `gnupatch/`, `coreutils/`,
`bootstrap-deps/`, `cctools/`, `gcc-4.6/`, `gcc-10/`, `gcc-latest/`)
totalling ~81 .nix files.  The stage0/mescc-tools/tinycc derivations use a
shared `utils.nix:mkDarwin` helper that bakes in `dontUnpack`/`dontStrip`/
`strictDeps`/version/platforms defaults; the later phases (gcc-*, gnu-hello,
bootstrap-deps, cctools) use `runCommand` directly.  Smoke tests live in
`checkPhase`; every file declares its dependencies explicitly in
nixpkgs-callPackage style.

The implemented amd64 chain is:

1. Raw Darwin/Mach-O seeds: syscall hello probes, a hand-assembled `hex0`,
   Mach-O `hex2` templates using `LC_MAIN`, `/usr/lib/dyld`, and `libSystem`.
   The `hex0` seed carries an empty `LC_DYLD_INFO_ONLY` load command so it
   loads under the Darwin 25 dyld (older dyld tolerated its absence; Darwin
   25 dyld took the classic-relocations path and dereferenced a null
   dysymtab → SIGSEGV).
2. Stage0 tools (`stage0-posix/`): `hex1`, `hex2`, `catm`, `M0`, `cc_arch`,
   `M2`, `blood-macho`, `M1`, full `hex2` (linker), `kaem` — all built live
   from committed source through the chain.  The earliest ones
   (`hex1`/`hex2`/`catm`/`M0`/`cc_arch`/`macho-patcher-early`) run **unsigned**
   in the Nix sandbox; the later ones (`M2`, `blood-macho`, `M1`, the full
   `hex2` linker, `kaem`) are ad-hoc **signed** via `darwin.signingUtils`.
   `hex1` and `hex2` are assembled from hand-rolled `hex0/sources/*.hex0`
   files and `dd`-padded — no perl/awk at build time for the stage0 chain.
3. Mes / mescc-libc / TinyCC: `mes/m2`, the `mescc-libc/*` probes, and the
   `tinycc/*` boot-cycle culminate in `tinycc/darwin-cc` (the working TCC
   used by every downstream GCC build).  Its link path picks the smallest
   of three Mach-O layout templates (`tiny`/`small`/`large`): the `tiny`
   tier puts `__DATA` at `base+0x100000` so a small binary's `__TEXT`→`__DATA`
   gap — which is materialized as zero tokens that the M2-Planet-built `hex2`
   re-parses every link — is ~1 MB instead of ~18 MB, making `configure`
   conftest compile+links ~7× faster (the bulk of GCC build time).
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
  selected bootstrap boundaries.  The compiler/assembler/linker/SDK paths are
  store-pinned (`${apple-sdk}`, `${cctools}`, `${darwin.binutils-unwrapped}`)
  and no .nix file references the Command Line Tools install dir; some
  derivations (gnu-hello, bootstrap-deps, cctools/ar) do append
  `/usr/bin:/bin:/usr/sbin:/sbin` to `PATH` as a fallback for plain shell
  utilities, but no chain compiler/translator is resolved from there.
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
- `cctools/ar` chain-compiles the `ar`/`ranlib` drivers **and** their
  `libstuff.a`/`libmacho.a` support archives with chain gcc-15
  (`gcc-latest-strict`); the only host step is *packing* those support
  archives with host `${cctools}/bin/ar` (you need an archiver to build an
  archiver).  More broadly, host `cctools` archive tools (`ar`/`ranlib`/
  `libtool`) are used to extract and pack `.a` archives in the
  `tcc-darwin-cc` link path and in the bootstrap-deps (GMP/MPFR/MPC/ISL) and
  coreutils builds.  `cctools-ar` is on the GNU Hello proof path (it is the
  `AR`/`RANLIB` for the gnu-hello build), so the host archive-packing remains
  a real boundary, tracked for a future from-chain `ar`.
- `checks.nix`'s `macho-template-hello-runs` is a validation-only check
  (not a chain artifact): it compiles upstream stage0 `hex2` C with host
  `$CC` to sanity-check the committed Mach-O template. It is not in the
  bootstrap trust path.
- Host `perl` performs the remaining deterministic GCC source/configure
  edits (and the gcc-4.6 libgcc-tree staging in `gcc-4.6/libgcc.pl`).
  This is build-orchestration — applying known diffs to known files,
  the role `gnupatch` plays elsewhere — not translation; converting it
  to committed patches is a remaining hardening step.
- The GCC packaging phases that shell out to make — `gcc-4.6/cxx`,
  `gcc-10`, `gcc-latest`, `gcc-latest/strict`, and gnu-hello — run the
  chain-built `bootstrap-gnumake` (GNU Make 4.4.1 compiled by the chain
  tcc); its libc implements getcwd via `fcntl(F_GETPATH)` so
  `$(abspath)`/`$(realpath)`/`CURDIR` return real paths.  The one exception
  is gcc-4.6's intermediate `all-gcc` step, which still invokes the stdenv
  (nixpkgs) `make` — a remaining orchestration boundary.
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

The bootstrap's stage0/glue inputs are committed source files (it also
fetches a fixed set of pinned upstream release tarballs — Mes, GCC 4.6/10/
latest, GNU Hello, make, patch, coreutils, nyacc — as fixed-output
derivations in `sources.nix`).  Helper scripts under `scripts/` regenerate
the derived committed inputs when their upstream sources change:

- `scripts/stage0/regen-hex0-sources.sh` — regenerates
  `hex0/sources/hex{1,2}_AMD64_darwin.hex0` from the legacy perl helpers
  kept at `scripts/stage0/legacy/`.
- `scripts/stage0/regen-preported.sh` — regenerates the committed
  `M2libc/amd64/{catm,M0,cc_arch-0}_AMD64_darwin*.hex2` and
  `tools/macho-patcher-m0.M1` from the awk port scripts in `scripts/stage0/`.
- `scripts/refactor/{drop-isx86-wrapper,extract-smoke}.py` — one-shot tools
  from the nixpkgs-style layout refactor (drop dead aarch64 branches, hoist
  smoke tests into checkPhase), kept for future similar passes.

No host `python` runs at build time anywhere in the chain (`python3`
appears only in design-time `scripts/stage0/regen-*.sh` maintainer
scripts).

Host `awk` has been removed from the **entire amd64 build-time chain**
(Nix track): the M1 code/data split and cross-object synth-label injection
are chain-built C tools (`bootstrap/m1-split.c`, `bootstrap/synth-inject.c`,
compiled through M2-Planet → M1 → hex2) used uniformly across the
`mescc-libc/*`, `mes/*`, `tinycc/*` boot-cycle, the TinyCC-darwin-cc
wrapper, the GCC link path, and `cctools/ar`.  The `mescc-tools` helpers are
built live in two forms: **C → M2-Planet → M1 → hex2** for `m1-split`,
`m1-to-hex2`, `hex2-data-relocs`, `cc-arch-helper`, `synth-inject` (from
`bootstrap/*.c`); and **hand-written Mach-O `.M1` → M1 → hex2** for
`elf64-to-m1`, `macho-patcher` (from `tools/*.M1`).  In both forms stdenv
only orchestrates (`cp`/`dd`/`install`); the previous committed
`.hex0` binary dumps were removed once the live builds were verified
byte-identical.  The only remaining host `awk` is the deferred
`stage0-posix/hex1` aarch64 candidate path and maintainer-only `scripts/`.

Deterministic GCC source/configure edits and the modern-GCC bootstrap
sysroot are committed `.patch` files and committed headers
(`patches/`, `bootstrap/headers/gcc-modern-sysroot`) applied/copied at
build time; the chain-built `gnupatch` applies the GCC patches.  (One
earlier source-prep step, the `tinyccMesSrc` derivation in `packages.nix`,
still applies its committed `patches/tinycc-mes-bootstrap.patch` with the
stdenv host `patch` — chain `gnupatch` does not exist that early.)  Host `perl`
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
