# nixpkgs-darwin-bootstrap

A from-source bootstrap of a full C/C++ toolchain on Darwin (x86-64
Mach-O, run under Rosetta 2 on Apple Silicon), reproducing the Linux
`minimal-bootstrap` stage0 → M2-Planet → Mes/MesCC → TinyCC → GCC path
as a native Mach-O chain.  The declared binary seed is the committed 4 KB
`seed/hex0-amd64-darwin`, with committed text and SHA-256-pinned release
sources downstream.  Under the strict stage0 policy used by this repository's
audit, however, host semantic text transformations and host-built runtime stubs
still enlarge the effective trust boundary; neither track is yet a faithful
“4 KiB seed plus text” bootstrap.  The exact blockers and evidence are in
`docs/BOOTSTRAP-REVIEW.md`.

The repo carries **two tracks over the same sources**:

- **The shell track (repo root)** — live-bootstrap style.  A single
  `sh build.sh` iterates `steps/*.sh` from the seed to a working
  gcc-10 `cc1` + `xgcc` that compile and run C, using Apple's `/bin/sh`
  and POSIX utilities for orchestration.  It does not use Nix or
  bootstrap-tools, but its effective trust boundary still includes the host
  semantic transformations, runtime-stub compilation, and target assembler/
  linker described below.
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
├── seed/hex0-amd64-darwin   # declared seed: 4096 committed Mach-O bytes
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

The stage0 `.hex0` sources are native Git text blobs, not Git LFS objects.
This is required for clean `git+file:` and remote Git flake builds: Nix imports
the Git object, without applying an LFS smudge filter.  The seed binary is also
tracked directly (4 KB).

## Trust roots

The inventory below describes the repository's intended trust boundary.  Under
the stricter stage0 policy used by `scripts/audit-bootstrap.sh`—where host
`awk`, `perl`, `python`, `sed`, or `patch` may not perform semantic source or
generated-code transformations—neither track is yet a fully faithful stage0
bootstrap.  See `docs/BOOTSTRAP-REVIEW.md` for the blockers and the evidence
needed to close them.

The inventory below separates the declared seed lineage from each track's
effective host boundaries.  The main compiler succession is seed-descended,
but semantic source preparation, assembler/linker work, generated-code tools,
and runtime stubs listed below also influence executable bits and therefore
remain trust inputs.

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
  `grep`, `find` run the build scripts.  The strict derivations disable host
  C/C++ compilation of chain source, but that narrower property does not remove
  the semantic host text transformations documented below from the effective
  trust boundary.
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
- **Ad-hoc code signing** of generated Mach-O binaries via the pinned nixpkgs
  `darwin.signingUtils`.  The early stage0 execution tools are signed at their
  declared Mach-O `__LINKEDIT` boundary.  Separately, writable copies of the
  exact stdenv orchestration inputs are ad-hoc-signed for host execution; this
  changes execution metadata, not the compiler or source lineage.
- **Host `perl`** applies the remaining deterministic edits to
  *generated* configure outputs (Makefiles, `config.h`) and stages the
  gcc-4.6 libgcc tree (`nix/gcc-4.6/libgcc.pl`).  GCC *source* edits
  are committed `.patch` files applied by the chain-built `gnupatch`
  (exception: `tinyccMesSrc` applies its patch with stdenv `patch` —
  chain `gnupatch` does not exist that early).
- **Chain-built `bootstrap-gnumake`** runs the modern GCC phases and
  gcc-4.6 C++ packaging; the gcc-4.6 intermediate `all-gcc` and
  `libgcc` steps invoke the stdenv `make`.
- The M1 code/data split and cross-object synth-label injection are
  chain-built C tools (`nix/bootstrap/*.c`, compiled through M2-Planet
  → M1 → hex2) used uniformly from `mescc-libc` through `cctools/ar`.
  This does not eliminate host semantic text processing from the full
  track: GCC 4.6 still runs host `gawk` generators (including
  `opt-functions.awk`/`optc-gen.awk` to emit `options.c`), alongside the
  host Perl edits listed above.  Those are explicit fidelity blockers in
  `docs/BOOTSTRAP-REVIEW.md`.

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

For the provenance audit and repeatable performance suites:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py'
./scripts/audit-bootstrap.sh
python3 ./scripts/collect-gcc46-provenance.py \
  --producer "$(nix path-info .#gcc46-all-gcc)" \
  --consumer "$(nix path-info .#gcc46-cxx)" \
  --output /path/to/new/provenance-bundle
RUNS=3 PROFILE=stages ./scripts/time-nix-suite.sh
RUNS=3 PROFILE=e2e ./scripts/time-nix-suite.sh
RUNS=3 ./scripts/time-shell-e2e.sh
RUNS=3 ./scripts/time-gcc46-reuse-ab.sh
python3 ./scripts/summarize-process-snapshots.py \
  --input-glob '/path/to/campaign/**/*.processes.tsv' \
  --output process-summary.tsv --detail-output process-detail.tsv \
  --command-output process-commands.tsv
python3 ./scripts/summarize-system-state.py \
  --root /path/to/campaign --output system-state.tsv \
  --summary-output system-state-summary.tsv
```

Run the GCC provenance collector only after both store outputs are finalized;
never point it at a mutating build tree.  It records artifact hashes, retained
evidence, compiler components, full compile commands, compile-log coverage,
and the `cc1plus` link command.  The C++ checkpoint retains its regular GCC
source/build artifacts in a normalized compressed archive; the collector hashes
those members directly, without extracting them or relying on a vanished Nix
sandbox.  Its own methodology explicitly does not treat that evidence as
authorization for mismatched backend-object reuse.

The timing harnesses require three quiet preflight observations and reject an
attempt if monitored background services or a competing `nix build` appear
during the workload.  They also require AC power, lock the active `pmset`
power-mode value before environment capture, and reject any power-source or
power-mode transition.  `PROFILE=e2e` deletes only its evaluated, closed set of
project output paths and exact `.drv` plans, then re-evaluates those plans
before timing.  It refuses to proceed when an outside output or derivation
referrer exists.  `PROFILE=stages` proves every measured output is already
valid before monitoring starts and fails rather than folding missing
dependencies into an isolated-stage sample.  Raw accepted and rejected
attempts remain in the printed log directory.  Per-workload `vm_stat`, swap
usage, and memory-pressure snapshots expose cache and memory state; fresh output
deletion is not presented as a privileged cold-cache purge.
Because shell builds consume the working tree rather than a Git flake revision,
their harness records the mode, size, and SHA-256 of every effective file under
`build.sh`, `seed/`, `sources/`, and `steps/`, following source symlinks.  This
manifest is generated before quiet waiting and timing and excludes `bake/`.
The process summary is diagnostic rather than an allowlist: every per-file row
and every exact-command row must be reviewed, and no
`unclassified-review-required` or `mixed-review-required` row may remain
unresolved when its samples are finally accepted.  The exact-command output
also prevents a foreign process from hiding behind a workload-looking basename.
Its RSS columns summarize only the periodic observations for processes that
reported at least the configured CPU threshold (5% by default); they are not
whole-workload or true peak-RSS measurements.
The timing summarizer rejects malformed, non-finite, or negative measurements;
shell and Nix suites additionally require exactly one identical ordered stage
set in each of the requested number of accepted input files.
Accordingly, `accepted=1` in a harness TSV is provisional automated acceptance,
not final review acceptance.

The GCC 4.6 wrapper pins its high-fanout overlay operations to Apple's signed
`/bin` and `/usr/bin` file utilities.  A prior `-j18` run resolved those tools
through the build `PATH`, drove `taskgated` to roughly 150 detached-signature
lookups per second, and exposed a macOS IPC-voucher kernel panic.  The
`gcc46-all-gcc` builder also ad-hoc-signs private copies of the exact
derivation-selected x86_64 build tools before their high-rate execution; a
50-launch control measured 50 detached-signature lookups unsigned and zero
signed.  The shared tool closure signs the exact stdenv Coreutils multicall
binary once and exposes every applet name through symlinks to that signed
copy, including names that Bash builtins hide from `command -v`.  Absolute
wrapper paths to the pinned TinyCC link/signing helpers are
redirected to signed private copies of `sigtool`, `codesign`, and
`codesign_allocate`.  The seed-built `elf64-to-m1` is signed at its declared
Mach-O `__LINKEDIT` boundary.  These remain disclosed host
execution/orchestration boundaries only; compiler source translation still
uses the seed-descended chain.  See `docs/BOOTSTRAP-REVIEW.md` for the panic
evidence and post-fix validation requirements.

The chain tip is a strict self-hosted GCC matched to nixpkgs
`gcc_latest.version`, rebuilt with external GMP/MPFR/MPC/ISL, and
verified by `gnu-hello-hash-comparison`: GNU Hello 2.12.2 built with the
bootstrap GCC and with the strict handoff must be byte-identical and equal the
pinned bootstrap baseline
`0854f4ab9cf255a37ddfb6251198164e6f14f3606239c963d2530f77e257f90a`.
The independently exercised nixpkgs `gcc_latest` reference is pinned at
`f23f901be1f6c913487bfc939364f746127357805c0ccbe2a922c7c6b793f417`.
It is not expected to be byte-identical because nixpkgs's compiler/linker
wrappers deliberately add frame-pointer, deployment, search-path, and RPATH
policy absent from the minimal bootstrap wrapper.  Both baselines are enforced
inside the derivation, so drift fails the build and `nix flake check`.

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
   `tinycc/darwin-cc`, the seed-descended C compiler used for the first GCC
   checkpoint.  Host-generated source and platform-tool boundaries still apply
   as disclosed above.
3. **GCC 4.6** (`nix/gcc-4.6/`): TinyCC builds the C-only `all-gcc`
   checkpoint, followed by libgcc and a GCC 4.6 C compiler.  The default C++
   checkpoint retains disclosed prior-stage generators and generated sources
   but recompiles its C/C++ frontend and language-independent backend with GCC
   4.6; mismatched TinyCC-built backend-object reuse is experimental only.
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

These particular Python and `awk` regenerators are design-time tools.  That
does not clear the promoted chains of host semantic processing: the shell
step-53b/pre-44 boundaries and the Nix GCC Perl/`gawk` boundaries are separately
documented above and in `docs/BOOTSTRAP-REVIEW.md`.  The deferred native aarch64
candidate path is outside the reviewed promoted chain.

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
