# Bootstrap breakage on Darwin 25.3 (Apple Silicon / Rosetta) — running log

Host: `aarch64-darwin`, Darwin 25.3.0, Rosetta 2 installed.
Tracks exercised: `./bake/build.sh` and `NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix build --impure .#default`.

Status legend: ✅ fixed · 🔧 fix known, not yet applied · ❓ needs investigation

> **Rebase note (2026-06-23):** issues **1–4** were resolved independently on
> `origin/main` (commits `3872cdd`, `b3aaa86`, `3a0f6fb` — same root causes,
> slightly different source layout) and this branch is rebased on top of them,
> so 1–4 are kept below only as the diagnostic record.  This branch's own work
> is issues **5, 6, 7** (the bake gnumake + gcc-4.6 + gcc-10 phases).

---

## 1. ✅ hex0 seed Mach-O segfaults under modern dyld

**Symptom:** `./bake/build.sh` dies at `01-hex0` with `Segmentation fault: 11`;
the Nix track dies identically building `hex0-raw` (`builder failed due to
signal 11`). Both tracks share the same seed (`bake/seed` → `hex0/seed`).

**Root cause:** The committed 4 KB seed (`hex0/seed/hex0-amd64-darwin`,
materialized from `hex0/hex0-amd64-darwin.hex0`) is a hand-rolled Mach-O with
`MH_DYLDLINK` set but **no `LC_DYLD_INFO`, no chained-fixups, no `__LINKEDIT`,
no symtab/dysymtab**. The crash report shows the fault is *inside dyld*
(`dyld4::Loader::applyFixups` → `MachOAnalyzer::forEachRebase_Relocations`),
`EXC_BAD_ACCESS (KERN_INVALID_ADDRESS at 0x48)`. Older dyld tolerated a
fixup-free image with no linkedit metadata; the Darwin 25 dyld takes the
classic-relocations path and dereferences a null dysymtab.

**Fix applied:** Added an empty (all-zero) `LC_DYLD_INFO_ONLY` (cmd
`0x80000022`, cmdsize 48) to the seed's load commands — ncmds 7→8, sizeofcmds
`0x180`→`0x1b0`, reclaiming 48 bytes of padding so `__text` stays at file
offset `0x400` and the file stays 4096 bytes. Edited
`hex0/hex0-amd64-darwin.hex0` and regenerated `hex0/seed/hex0-amd64-darwin`.
Verified: materializes to 4096 bytes, runs (unsigned) under Rosetta, and
self-hosts byte-identical. `hex1`/`hex2` `.hex0` sources already carried this
load command — only the seed was missed.

**Note:** `codesign -s -` refuses the seed ("main executable failed strict
validation") and signing is unnecessary — unsigned x86_64 runs under Rosetta
once the dyld-info command is present.

---

## 2. 🔧 bake steps 02–07 omit the dd zero-padding the Nix track applies

**Symptom:** After the seed fix, `04-catm` fails with `Killed: 9` (SIGKILL)
when first *executing* a stage0 binary. `hex2-darwin` materializes to only
**2444 bytes** (hex1 → 3596 bytes) but its Mach-O header declares
`__TEXT`/`__DATA`/`__LINKEDIT` segments extending to `0x1800000` (24 MB). The
kernel SIGKILLs because segments point far past EOF.

**Root cause:** The bake early steps (`02-hex1`, `03-hex2`, `04-catm`,
`05-m0`, `06-macho-patcher-early`, `07-cc-arch` — the "6 already-pure phases"
from commit `27d84a0`) assemble from the *unpadded* Nix sources (the bake
sources are symlinks into `hex0/sources/…`) but never pad. Their comments
claim "padding baked into source", which is false. The Nix derivations pad
with `dd` *after* assembling; the bake steps forgot to. (Other bake steps —
08, 09, 11, 18, 30, … — do `dd`-pad.) Likely worked on an older macOS that
zero-filled segments past EOF; Darwin 25 does not.

**Fix (known, mirror the Nix `dd` targets):**
| step | binary | pad-to (seek = size−1) |
|------|--------|------------------------|
| 02-hex1 | hex1-darwin | `0x1000000` |
| 03-hex2 | hex2-darwin | `0x1800000` |
| 04-catm | catm-darwin | `0x900000` (data_end) |
| 05-m0   | M0-darwin   | `0x2800000` |
| 06-macho-patcher-early | (verify target in `mescc-tools/macho-patcher-early.nix`) | ❓ |
| 07-cc-arch | cc_arch-darwin | `0x2800000` |

Verified manually: padding `hex2-darwin` to `0x1800000` stops the SIGKILL and
it runs correctly on a small fixture (`stage0-posix/fixtures/hex2-labels.hex2`
→ `Hi\n`).

---

## 3. ❓ bake step 04 references a dangling symlink (missing combined catm source)

**Symptom:** Once `hex2-darwin` is padded, `04-catm` runs
`hex2-darwin "$SOURCES/catm_AMD64_darwin_combined.hex2" …` and hangs forever
(0-byte output) — hex2 loops on a failed `open` of a non-existent input.

**Root cause:** `bake/sources/catm_AMD64_darwin_combined.hex2` is a symlink to
`../../hex0/sources/catm/catm_AMD64_darwin_combined.hex2`, which **does not
exist** in `HEAD`. Git history shows commit `5014ea2` ("defrost: build all 6
stage0 phases live from source (#82 #83)") reorganized these sources; the
combined file was removed but the bake symlink + step were not updated.

The Nix `catm.nix` does **not** use a combined file — it assembles the header
(`tools/templates/MACHO-amd64-catm-header.hex2`) and body
(`M2libc/amd64/catm_AMD64_darwin_body.hex2`) separately, then `cat`s the two
binaries and pads to `0x900000`.

**Fix (proposed):** Rewrite bake `04-catm` to match `catm.nix`: assemble
header + body separately via `hex2-darwin`, concatenate, pad to `0x900000`;
drop the dangling `catm_AMD64_darwin_combined.hex2` symlink. (Implies hex2
robustness gap: it should fail, not hang, on a missing input — secondary.)

---

## 4. 🔧 Nix eval: `cannot coerce null to a string` building `.#default` on aarch64

**Symptom:**
```
NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM=1 nix build --impure .#default
error: cannot coerce null to a string: null
  … while evaluating attribute 'buildPhase' of derivation 'catm-…'
  … at stage0-posix/catm.nix:29:  ${hex2-0}/bin/hex2-darwin
```

**Root cause:** The whole chain is x86_64-only. `stage0-posix/hex2.nix` (and a
handful of siblings) guard with `if hostPlatform.isx86_64 then … else null`,
so on `aarch64-darwin` `hex2-0` evaluates to **null**. But `catm.nix` (and
most downstream phases) are *not* guarded and interpolate `${hex2-0}` →
coercion error. The flake's `default` selector also picks `gcc-latest-strict`
on aarch64 (it isn't null-guarded) and then explodes deep in its deps.

Confirmed: `b.hex2-0` is `"null"` on aarch64-darwin, `"set"` on x86_64-darwin.

**Fix options:**
- (a) On Apple Silicon, build the amd64 set explicitly:
  `nix build .#packages.x86_64-darwin.default` (runs under Rosetta in the
  sandbox; needs `extra-platforms = x86_64-darwin`). Documented runnable path.
- (b) Make the flake degrade cleanly on aarch64 — alias the aarch64 outputs
  (or at least `default`) to the x86_64 package set, so `.#default` builds the
  real chain under Rosetta instead of evaluating null amd64 phases. **Preferred
  to honor the user's `.#default` invocation.**

Also note: even the x86_64 build is blocked until issue #1 (the seed) is fixed,
which it now is.

---

## 5. ✅ bake step 45 (gnumake) calls a deleted script via a broken symlink

**Symptom:** With stage0 + tinycc fixed, the bake build runs to `45-gnumake`
and dies: `/bin/bash: .../bake/scripts/phase39-patch-job.sh: No such file or
directory`.

**Root cause:** `bake/scripts/phase39-patch-job.sh` is a symlink to
`scripts/gnumake/phase39-patch-job.sh`, which the "wave 3a" refactor (commit
5556202) deleted — it replaced the perl `src/job.c` fork/exec rewrite with the
committed patch `patches/gnumake-4.4.1-job-fork-exec.patch` applied by gnupatch
(see `gnumake/default.nix`).  The bake step + symlink were never updated.

**Fix applied:** Apply the committed patch in step 45 via host `patch` (same
convention bake already uses for the tinycc/gcc46 patches — `/usr/bin/patch
-p1 < "$SOURCES/.../x.patch"`).  Added a `bake/sources/gnumake/` symlink to
`patches/gnumake-4.4.1-job-fork-exec.patch` and removed the dangling
`bake/scripts/phase39-patch-job.sh`.  Verified: the patch applies cleanly to
make-4.4.1 and `bake/target/bin/make` builds and reports its version.

---

## 6. ✅ bake gcc-4.6 steps (48–52) point at renamed scripts via broken symlinks

**Symptom:** bake runs to `48-gcc46-all-gcc` and dies:
`/bin/bash: .../bake/sources/gcc46-scripts/phase35-prepare-source.sh: No such
file or directory`.

**Root cause:** All nine `bake/sources/gcc46-scripts/*` symlinks point into a
`scripts/gcc46/phaseNN-*` directory that the "drop phaseXX" rename (commit
40a3a9c) replaced with `scripts/gcc-4.6/*` (hyphenated dir, `phaseNN-` prefix
dropped).  The bake step references and symlinks were never updated.  Same
class as #3 and #5.

**Fix applied:** Repointed the 7 referenced symlinks
(`phase35-prepare-source.sh`→`prepare-source.sh`, `phase36-*`→`*`,
`phase37-driver.sh`→`driver.sh`, `gxx-bootstrap-wrapper.sh`) to
`../../../scripts/gcc-4.6/<name>`, keeping the symlink names so the steps still
resolve.  Removed two unreferenced dangling links
(`phase36-bootstrap-as.awk`, `phase44-cxx.sh`).  These are the same scripts the
Nix gcc-4.6 derivations use, so the targets are correct.  Verified step 48 now
runs past the prepare-source call.

---

## 7. ✅ bake step 55 (gcc-10 all-gcc) gcov stub write fails on a clean build

**Symptom:** bake reaches the final step `55-gcc10-all-gcc` and dies:
`55-gcc10-all-gcc.sh: line 59: .../build/gcc/gcov: No such file or directory`.

**Root cause:** Step 55 pre-places `gcov`/`gcov-dump`/`gcov-tool` no-op stubs
(far-future mtime) in `$GCC10_BUILD/gcc/` so `make all-gcc` skips linking them
(gcov-tool pulls in `nftw(3)`, absent from the chain sysroot libc).  But on a
clean from-seed build the top-level configure only writes `build/Makefile`;
the `gcc/` build subdir is created by make *during* all-gcc.  So the stub
redirect writes into a non-existent dir.  The author only ever hit this on a
warm tree where `gcc/` already existed from a prior make.

**Fix applied:** `mkdir -p "$GCC10_BUILD/gcc"` before the stub loop.  make's
`configure-gcc` still runs (it keys off `gcc/config.status`, which we don't
create) and leaves the future-mtime stubs in place, so the gcov link is
skipped as intended.

---

## 8. ✅ bake step 55 wedges forever on gmp's "nested variables" configure probe

**Symptom:** after the gcov fix (#7), step 55's `make all-gcc` reaches the
in-tree gmp sub-configure and hangs indefinitely at `checking whether make
supports nested variables...` — load drops to ~0, no progress.  `lsof` shows
the inner chain-make blocked with **stdin = an open PIPE**.

**Root cause:** automake's nested-variables probe runs `make -f -`, feeding a
tiny makefile through a here-doc pipe.  The chain-built GNU make spools `-f -`
stdin to a temp file and blocks waiting for an EOF that never arrives on that
pipe.  build.sh already redirects each step's stdin from `/dev/null`, but the
gmp configure creates its *own* pipe for this probe, so that mitigation doesn't
reach it.  A warm tree skips the probe via a cached `config.cache`; a clean
from-seed build hits it every time (same warm-tree-only blind spot as #7).

**Fix applied:** pre-set `am_cv_make_support_nested_variables=yes` in
`bake/sources/gcc10-darwin/config.site` (already used to pre-answer the depmode
probe), so every subdir configure skips the wedging `make -f -` check.  The
chain make is GNU make 4.4.1, which does support nested variables, so the
forced answer is correct.  Verified: the probe now prints `(cached) yes` and
gmp configure proceeds.

---

## 9. ✅ bake step 55: build-side libcpp.a emptied by Apple's `ar` (genmatch link) — ROOT-CAUSED + FIXED

**Symptom:** with #7/#8 fixed, step 55 reaches `build/genmatch` and the chain
link fails: `Target label _ZNK13rich_location7get_locEj is not valid`
(`rich_location::get_loc`).  genmatch links the *build* libcpp
(`build-x86_64-apple-darwin/libcpp/libcpp.a`), which came out **96 bytes** — an
Apple `__.SYMDEF`-only, member-less archive — while the host
`build/libcpp/libcpp.a` (865 KB) and the build `libiberty.a` (629 KB) are fine.

**Root cause (traced all the way):**
- The 96-byte `__.SYMDEF` archive is *exactly* what Apple's `/usr/bin/ar`
  emits when handed ELF objects — it warns `archive member 'charset.o' not a
  mach-o file` and drops them all (verified directly).  bake-ar never writes
  `__.SYMDEF`, so Apple's `ar` produced it.
- But no Makefile configures Apple's tools: every `AR`/`RANLIB`/`*_FOR_BUILD`
  in the build tree points at `bake/scripts/bake-{ar,ranlib}`.  The culprit is
  that gcc's **`libcpp/Makefile.in` (and `intl`, `libdecnumber`) hardcode a
  LITERAL `AR = ar`** — a bare tool name, *not* `@AR@` — so configure, the
  exported `AR`, and `config.site` are all ignored; the archive rule always
  runs a bare `ar`, resolved via `PATH`.
- `PATH` is `target/bin:/usr/bin:/bin` (chain `ar`→bake-ar first), so the bare
  `ar` *usually* hits bake-ar.  But on the **first full `make all-gcc`** the
  build-side (`build-x86_64-apple-darwin`) recursion intermittently loses that
  race and resolves `ar` to `/usr/bin/ar` → empty archive.  `build/genmatch`
  is the only generator that links the build-side libcpp.a, so it alone fails.
- Confirmed via a logging chokepoint on the bake-ar binary: on warm/incremental
  rebuilds both libcpp.a always build via bake-ar → 865 KB (heisenbug dodged),
  which is why hand-rebuilding the archive always "worked".

**Fix applied:** step 55 now rewrites the literal `AR = ar` in the **source
templates** (`$GCC10_SRC/{libcpp,intl,libdecnumber}/Makefile.in`) to the
absolute chain ar (`$TARGET/bin/bake-ar`) *before* configure runs, so every
generated Makefile (host AND build-side) gets a PATH-independent archiver that
can never reach `/usr/bin/ar`.  Already-generated Makefiles are rewritten too
(warm trees), and the `ar`/`ranlib` PATH symlinks stay as belt-and-suspenders.
Replaces the previous non-bulletproof "put bake-ar on PATH as `ar`" mitigation,
which still let the bare `ar` lose the race.

## 10. ✅ bake step 55: genmatch link can't resolve `fstat$INODE64` — FIXED

**Symptom:** with libcpp.a repaired (#9), genmatch links past rich_location and
then fails: `Target label ELF_fstat_INODE64 is not valid`.

**Root cause:** the chain's `bootstrap/headers/tcc-darwin-bootstrap/sys/stat.h`
deliberately binds `stat`/`fstat`/`lstat`/`fstatat` to the `$INODE64`-suffixed
libSystem symbols *for gcc* (`#if defined(__GNUC__) && !defined(__TINYC__)`),
because "binutils ld from gcc-10 onward" doesn't rewrite the reference the way
Apple's ld does.  That's correct for the **Nix** track (gcc-10 genmatch links
with binutils `/usr/bin/ld` — `scripts/gcc-modern/bootstrap-gcc.sh`).  But the
**bake** track links gcc-compiled objects (genmatch, cc1) with the **chain tcc
path** (`gxx-bootstrap-wrapper.sh` always links via `$TCC`; bake-only — no Nix
file references it), which resolves against the bootstrap libc, whose plain
`fstat`/`stat` already do the 64-bit `stat64` syscall and fill the 64-bit
`struct stat` (`bootstrap/tinycc-sysv-libc.c:446-447`).  The `$INODE64` symbols
don't exist there, so the chain link fails.

**Fix applied:** guard the `$INODE64` branch with `&& !defined(__BAKE_PLAIN_STAT__)`
and have the bake g++ wrapper (`scripts/gcc-4.6/gxx-bootstrap-wrapper.sh`) pass
`-D__BAKE_PLAIN_STAT__`, so bake's chain-linked gcc objects use the plain
symbols (→ bootstrap libc, correct 64-bit struct) while the Nix binutils-ld
path keeps `$INODE64` unchanged (it never defines the macro / never uses the
wrapper).

> **Step 55 status: ✅ GOAL REACHED.**  #7, #8, #9 and #10 are all fixed and
> committed.  From the fixed tree, `bake` step 55 builds a working gcc-10
> `cc1` + `xgcc`, and `bake/scripts/gcc10-goal-test.sh` passes:
> `GOAL PASS: from-seed xgcc-10 compiled & ran C (returned 7)`.
>
> Remaining (not part of the cc1+xgcc goal): the *real* libgcc build
> (`gcc10-build-libgcc.sh`) fails at `_divdi3.o` (`all-target-libgcc`), so step
> 55 falls back to its stub `libgcc.a` as designed — the C goal test needs none
> of libgcc's symbols.  A from-scratch `./bake/build.sh` (vs. the warm-tree
> resume used to iterate here) is the final confirmation; all the source fixes
> it needs are committed.

---

## 11. ✅ Nix gcc-10/gcc-15: flex regen deletes shipped `gengtype-lex.c`

**Symptom:** `nix build .#packages.x86_64-darwin.gnu-hello-hash-comparison`
fails building `gcc-10.4.0`: `make[1]: [Makefile:2947: gengtype-lex.c] Error
127 (ignored)` (flex not found) followed by `g++.real: error: gengtype-lex.c:
No such file or directory`.

**Root cause:** GCC ships pre-generated `gcc/gengtype-lex.c` (from
`gengtype-lex.l`), but flex isn't a build input.  `scripts/gcc-modern/
bootstrap-gcc.sh` stages the source with `cp -R`, giving `.c` and `.l`
near-identical mtimes, so make sometimes decides the `.l` is newer and runs
flex; flex is missing (exit 127), the *ignored* rule truncates/removes the
shipped `.c`, and the next step can't find it.  A clean from-source build hits
this; a cached gcc-10 (the usual case) never rebuilds and dodges it.

**Fix applied:** after staging+patching the source, `bootstrap-gcc.sh` now
makes every shipped flex/bison output (`*.l`→`*.c`, `*.y`→`*.c/cc/h/hh`)
decisively newer than its source (`touch -t 200001010000` the source, `touch`
the generated file), so make never runs flex/bison.  The committed `.c` is
byte-identical to what they'd emit, so build output (and the gnu-hello hash) is
unchanged.  Applies to gcc-10, gcc-latest and gcc-latest-strict (all use this
script).

## ✅ Nix gnu-hello gate passes (the headline deliverable)

With #11 fixed, on this branch (rebased on origin/main):

```
nix build .#packages.x86_64-darwin.gnu-hello-hash-comparison   # exit 0
  phase46_gcc_latest        = 0854f4ab9cf2…257f90a   (== pinned baseline)
  phase47_gcc_latest_strict = 0854f4ab9cf2…257f90a   (== pinned baseline)
  phase46_phase47_equal     = yes                    (byte-identical, determinism check)
  phase47_nixpkgs_equal     = no                     (expected: from-seed ≠ nixpkgs ref)
```

The full from-seed Nix chain (stage0 → mes → tinycc → gcc-4.6 → gcc-10 →
gcc-15 bootstrap + strict → gnu-hello ×3) builds clean on Darwin 25 and
reproduces the baseline `0854f4ab…` GNU Hello hash.  The from-seed bake
gcc-10 (cc1+xgcc) goal also passes (Step-55 status above).

## Cross-cutting note

The `nixpkgs-unstable` lock warns: *"Nixpkgs 26.05 will be the last release to
support x86_64-darwin."* The entire trusted chain is `x86_64-darwin`/amd64 and
relies on Rosetta. Worth tracking for longevity, not a blocker today.
