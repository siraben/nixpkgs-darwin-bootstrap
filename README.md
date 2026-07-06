# nixpkgs-darwin-bootstrap

A from-source bootstrap of a full C/C++ toolchain on Darwin (x86-64
Mach-O, run under Rosetta 2 on Apple Silicon), reproducing the Linux
`minimal-bootstrap` stage0 → M2-Planet → Mes/MesCC → TinyCC → GCC path
as a native Mach-O chain.  The trust root is a single committed 4 KB
binary, `seed/hex0-amd64-darwin`; everything downstream is built from
committed, auditable text sources plus SHA-256-pinned upstream release
tarballs.

The repo carries **two tracks over the same sources**:

- **The shell track (repo root)** — live-bootstrap style.  A single
  `sh build.sh` iterates `steps/*.sh` from the seed to a working
  gcc-10 `cc1` + `xgcc` that compile and run C, using Apple's `/bin/sh`
  and POSIX utilities for orchestration.  No Nix, no bootstrap-tools,
  no clang/gcc/as/ld in the chain's code-translation path.
- **The Nix track (`nix/`)** — nixpkgs `minimal-bootstrap` style.  The
  flake builds the chain as per-package derivations up to a strict
  self-hosted modern GCC (`gcc_latest`, 15.2.0 with the current lock)
  and gates the result on a byte-exact GNU Hello hash baseline.

```
hex0 → hex1 → hex2 → catm → M0 → macho-patcher → cc_arch → M2-Planet
  → blood-elf → M1 → hex2 (linker) → kaem
  → mes → mescc-libc → tinycc → tcc-darwin-cc   (native Darwin C compiler)
  → GNU Make
  → gcc-4.6 (incl. C++ / libstdc++)
  → gcc-10 (shell track)  /  gcc-10 → gcc-15 + GNU Hello gate (Nix track)
```

## Layout

```
.
├── seed/hex0-amd64-darwin   # THE trust root: 4096 committed Mach-O bytes
├── build.sh                 # shell-track driver (TARGET=, BOOT_START_FROM=,
│                            #   BOOT_STOP_AFTER=)
├── steps/                   # ordered build steps: 01-hex0 … 55-gcc10-all-gcc
├── sources/                 # committed auditable text sources for the steps
│   ├── stage0-posix/        #   vendored oriansj/stage0-posix-1.9.1
│   ├── tcc-darwin/          #   the tcc-darwin-cc compiler/linker wrapper
│   └── tools/               #   chain-built C tools (boot-patch, boot-ar, m1-split,
│                            #     tsv-col, ctor-table, line-rewrite,
│                            #     synth-inject) + elf64-to-m1.M1
├── scripts/                 # shell-track helpers (fetch-sources.sh, goal test,
│                            #   boot-ar/boot-ranlib shims, gcc10 env)
├── tarballs/                # upstream tarballs (gitignored; fetched against
│                            #   pinned SHA-256s by scripts/fetch-sources.sh)
├── target/                  # shell-track build outputs (gitignored)
├── nix/                     # the Nix track: flake package set
│   ├── packages.nix         #   package wiring (callPackage-style)
│   ├── stage0-posix/ mescc-tools/ mes/ mescc-libc/ tinycc/ gnumake/
│   │   gnupatch/ coreutils/ bootstrap-deps/ cctools/ gcc-4.6/ gcc-10/
│   │   gcc-latest/          #   per-package directories, nixpkgs
│   │                        #     minimal-bootstrap layout
│   ├── hex0/ M2libc/ bootstrap/ patches/ scripts/ tools/ vendor/ ...
│   └── checks.nix           #   validation-only probes (flake checks)
├── docs/                    # REVIEW.md (faithfulness audit), STATUS.md
│                            #   (build log), todos.md pointers
└── flake.nix                # flake entry; imports nix/packages.nix
```

Many files under `sources/` are symlinks into `nix/` — both tracks build
from the same committed sources.

**Git LFS**: the `nix/hex0/sources/**/*.hex0` machine-code sources are
LFS-tracked.  Install `git lfs` before cloning, or they arrive as
pointer files and the bootstrap fails opaquely.  The seed binary itself
is tracked directly (4 KB).

## Trust roots

Everything the bootstrap's correctness rests on, per track.  The
compiler/translator path — everything that turns source text into
executable bits — is chain-built in both tracks; the tracks differ in
which host tools orchestrate the builds and in a small set of
documented boundaries.

### Shared by both tracks

1. **`seed/hex0-amd64-darwin` (4096 bytes)** — the one opaque binary.
   A hand-assembled hex0 assembler; step 01 verifies it is
   self-hosting (assembling its own commented `.hex0` source reproduces
   the seed byte-for-byte).  A second committed seed,
   `seed/hex0-aarch64-darwin` (34 KB), serves the deferred native
   aarch64 path and is outside the trusted amd64 chain.
2. **Committed text sources** — `sources/`, `nix/`, `steps/`: hand
   written `.hex0`/`.M1`/`.hex2`/C sources, patches, and build scripts,
   all auditable.
3. **Pinned upstream tarballs** — Mes, nyacc, TinyCC, GNU Make, patch,
   coreutils, GMP/MPFR/MPC/ISL, GCC 4.6/10/15, GNU Hello: fetched
   against fixed SHA-256 hashes (`scripts/fetch-sources.sh`,
   `nix/sources.nix`).
4. **Darwin kernel + `/usr/lib/dyld` + `libSystem`** — the platform
   ABI every chain binary links against and runs on.

### Shell track boundaries

- **Apple-signed `/bin/sh` + `/usr/bin` POSIX utilities** (`cp`, `dd`,
  `cmp`, `tar`, `grep`, ...) orchestrate the steps.
- **Host `awk`** performs the M1 code/data splits in the pre-compiler
  steps (21–42).  These splits partition already-translated M1 text;
  the C→M1 translation is chain `mescc` and the M1→Mach-O assembly is
  chain `M1`+`hex2`.  From step 44c on, the chain-built `m1-split`
  does the job.  The bootstrap-ordering analysis is in
  [`docs/REVIEW.md`](docs/REVIEW.md).
- **Source-prep tools**: committed `.patch` files in the shell track are
  applied by chain-built `boot-patch` (step 14b; used by steps 22, 47,
  48, 51).  Host `python3` (step 53b) and `perl`
  (`scripts/phase13-patch-assert-fail.sh`) still apply deterministic,
  committed edits to source text.
- **System `as`/`ld` for gcc-10 target codegen**: the chain builds the
  gcc-10 binaries themselves through its own `tcc-darwin-cc → hex2`
  Mach-O pipeline, but the resulting `xgcc` is configured with the
  platform assembler and linker as its *target* tools, so every `xgcc`
  compile/link (the goal test, the real core `libgcc.a`) uses them.
  Replacing them needs an in-chain Mach-O assembler and executable
  linker.
- **Host `cc` + `ar` for the `libgcc_eh`/`libgcc_s`/`libemutls_w`
  stubs** (step 55).  The core `libgcc.a` is a real archive built by
  the from-seed `xgcc` (`scripts/gcc10-build-libgcc.sh`).

### Nix track boundaries

- **nixpkgs stdenv orchestration**: host `bash`, coreutils, `sed`,
  `grep`, `find` run the build scripts.  No host compiler compiles any
  chain source; the purity claim covers the compiler/translator/make/
  patch trust path.
- **nixpkgs clang/binutils/cctools at the Mach-O assemble/link/archive
  boundary**: GCC phases assemble and link with store-pinned Apple
  tools (`${apple-sdk}`, `${cctools}`, `${darwin.binutils-unwrapped}`).
  `cctools/ar`'s `ar`/`ranlib` drivers and their support archives are
  chain-compiled by gcc-15; host `ar` still packs those archives and
  extracts/packs `.a` files in the tcc link path and the
  bootstrap-deps/coreutils builds.
- **macOS SDK headers** at selected GCC boundaries; the modern-GCC
  builds compile against a committed bootstrap sysroot
  (`nix/bootstrap/headers/gcc-modern-sysroot`).
- **Ad-hoc code signing** of generated Mach-O binaries via nixpkgs
  `darwin.signingUtils`; the earliest stage0 tools run unsigned in the
  Nix sandbox.
- **Host `perl`** applies the remaining deterministic edits to
  *generated* configure outputs (Makefiles, `config.h`) and stages the
  gcc-4.6 libgcc tree (`nix/gcc-4.6/libgcc.pl`).  GCC *source* edits
  are committed `.patch` files applied by the chain-built `gnupatch`
  (exception: `tinyccMesSrc` applies its patch with stdenv `patch` —
  chain `gnupatch` does not exist that early).
- **Chain-built `bootstrap-gnumake`** runs the modern GCC phases and
  gcc-4.6 C++ packaging; the gcc-4.6 intermediate `all-gcc` and
  `libgcc` steps invoke the stdenv `make`.
- Host `awk` and host `python` are absent from the entire amd64
  build-time chain.  The M1 code/data split and cross-object
  synth-label injection are chain-built C tools (`nix/bootstrap/*.c`,
  compiled through M2-Planet → M1 → hex2) used uniformly from
  `mescc-libc` through `cctools/ar`.

## Shell track: running it

```sh
sh scripts/fetch-sources.sh          # fetch pinned tarballs into tarballs/
sh build.sh                          # full chain into target/
TARGET=/tmp/verify sh build.sh       # clean from-seed run into a scratch tree
TARGET=/tmp/verify sh scripts/gcc10-goal-test.sh   # xgcc compiles+runs C → 7
```

Resume and range controls: `BOOT_START_FROM=54 sh build.sh` skips ahead
(and keeps the existing `TARGET`), `BOOT_STOP_AFTER=14 sh build.sh`
stops after a named step.

The gcc-10 phase is long: `cc1plus` runs x86-64 under Rosetta 2.  The
final cc1 link is the single largest operation (a ~335 MB combined M1);
the chain link tools' M2libc heap is sized (4 GB) to hold it.

The `tcc-darwin-cc` link path now asks `m1-to-hex2 --auto-data-align`
for the page-rounded data address, then rewrites a low-data Mach-O
template for each link.  This keeps small `configure` conftest
compile+links near the old tiny-template cost instead of padding every
binary to the large layout.

## Nix track: running it

On an `x86_64-darwin` builder (or Apple Silicon with
`extra-platforms = x86_64-darwin` in `nix.conf` — the flake maps
`aarch64-darwin` to the `x86_64-darwin` package set, so the chain
builds under Rosetta 2):

```sh
nix build .#hex0
nix build .#default                       # = gcc-latest strict bootstrap
nix build .#gnu-hello-hash-comparison     # verify against baseline hash
nix flake check
```

The chain tip is a strict self-hosted GCC matched to nixpkgs
`gcc_latest.version`, rebuilt with external GMP/MPFR/MPC/ISL, and
verified by `gnu-hello-hash-comparison`: GNU Hello 2.12.2 built with the
bootstrap GCC and with the strict handoff must be byte-identical, and
the hash must equal the pinned baseline
`0854f4ab9cf255a37ddfb6251198164e6f14f3606239c963d2530f77e257f90a`.
The gate is enforced inside the derivation, so drift fails the build
and `nix flake check`.

Outputs are exposed under plain semantic names and per-directory
aliases:

```sh
nix build .#kaem                          # = .#"stage0-posix/kaem"
nix build .#mes-m2                        # = .#"mes/m2"
nix build .#tinycc-darwin-cc              # = .#"tinycc/darwin-cc"
nix build .#gcc46                         # = .#"gcc-4.6/bootstrap"
nix build .#gcc-latest-strict             # = .#"gcc-latest/strict"
```

From another Darwin host, select the amd64 set explicitly:
`nix build .#packages.x86_64-darwin."gcc-latest/strict"`.

The Nix chain in detail:

1. **Stage0** (`nix/stage0-posix/`): `hex1`, `hex2`, `catm`, `M0`,
   `cc_arch`, `M2`, `blood-macho`, `M1`, the full `hex2` linker, `kaem`
   — all built live from committed source.  The hex0 derivation uses
   the seed itself as the Nix `builder` (no stdenv); its closure is 3
   store paths.  The seed carries an empty `LC_DYLD_INFO_ONLY` load
   command so it loads under the Darwin 25 dyld.
2. **Mes / mescc-libc / TinyCC** (`nix/mes/`, `nix/mescc-libc/`,
   `nix/tinycc/`): the MesCC and TinyCC boot cycle culminating in
   `tinycc/darwin-cc`, the working TCC that builds every downstream
   GCC.
3. **GCC 4.6** (`nix/gcc-4.6/`): the C compiler is chain-built first; the
   C++ stage reuses that `cc1` while compiling C++ frontend sources through
   the chain compiler. nixpkgs clang/binutils assemble and link only.
4. **Modern GCC** (`nix/gcc-10/`, `nix/gcc-latest/`): compiler-only
   GCC 10.4.0, then nixpkgs-matched `gcc_latest`, then the strict
   rebuild with external math libs.  All three compile their build
   helpers with the chain input compiler and ship from-stage0 `libgcc`
   and `libstdc++`.
5. **Package proof** (`nix/gnu-hello.nix`): the GNU Hello hash gate.

## Maintainer scripts

Helper scripts under `nix/scripts/` regenerate derived committed inputs
when their upstream sources change:

- `nix/scripts/stage0/regen-hex0-sources.sh` — regenerates
  `nix/hex0/sources/hex{1,2}_AMD64_darwin.hex0` from the legacy perl
  helpers kept at `nix/scripts/stage0/legacy/`.
- `nix/scripts/stage0/regen-preported.sh` — regenerates the committed
  `nix/M2libc/amd64/*.hex2` and `nix/tools/macho-patcher-m0.M1` from
  the awk port scripts in `nix/scripts/stage0/`.
- `nix/scripts/refactor/` — one-shot layout-refactor tools kept for
  future passes.

`python3` and the maintainer-only `awk` appear in these design-time
scripts and nowhere in the promoted amd64 build-time chain
(shell-track exception: the documented step-53b/pre-44 boundaries
above).  The deferred native aarch64 candidate path is not part of that
claim.

## aarch64 status

`aarch64-darwin` has raw syscall smoke coverage, Darwin M2libc checks,
a runnable Mach-O template hello check, and a signed phase-1 `hex1`
candidate.  It is not promoted to the trusted bootstrap chain: the
upstream `AArch64/hex1_AArch64.hex0` path still needs its ELF-era
writable-data model reworked for high-base Mach-O/`LC_MAIN` Darwin
execution.

## Further reading

- [`docs/REVIEW.md`](docs/REVIEW.md) — the shell-track faithfulness
  audit (external review + fix status for every finding).
- [`docs/STATUS.md`](docs/STATUS.md) — the shell-track build log:
  reproducibility runs, the gcc-10 debugging history, step inventory.
- [`todos.md`](todos.md) — the working log and open follow-ups.
