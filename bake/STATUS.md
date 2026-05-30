# bake/ status

A no-Nix, no-bootstrap-tools Darwin chain that builds, from a 4 KB
Mach-O seed:

```
hex0 → hex1 → hex2 → catm → M0 → macho-patcher → cc-arch → M2
→ blood-elf → M1-0 → hex2-1 → M1 → hex2 → kaem → M2-Planet
→ mes-source → mes-m2 → nyacc → mescc-trivial
→ libmescc → libc → libc+tcc
→ tcc → tcc-self → tcc-boot1 → tcc-boot2 → tcc-boot3
→ tcc-darwin-cc (native Darwin C compiler)
→ gnumake (GNU Make 4.4.1)
→ gcc-4.6 source + patches → all-gcc → libgcc → bootstrap ✅
  (full GCC 4.6.4: `gcc hello.c` compiles & runs)
```

## ✅ Full gcc-4.6 bootstrap (2026-05-28)

`bake/target/gcc46-bootstrap/bin/gcc` is a working GCC 4.6.4 driver
(xgcc + cc1 + libgcc + a tcc-compiled C `bootstrap-as`) that compiles
and runs C programs — all from the 4 KB seed, no Nix, no bootstrap-tools,
and **no host awk** in the assembly path.  Steps 48→49→50 all green.

Bugs fixed to get here (each surfaced the next):
1. tcc libc self-recursive int↔float helpers (make stack overflow) — e2161fc
2. Apple ar can't archive ELF (empty libs) → bake-ar — 65431d7
3. UTF-8 collation broke gcc's option dedup → LC_ALL=C — 5066486
4. root tcc-darwin-cc not executable (libgcc `as`) — 0c0c876
5. tcc assembler chokes on DWARF .file/.loc and GAS .p2align — 57240ca/.p2align
6. **host-awk asm filter → tcc-compiled C translator** (byte-identical
   over the 77-file/116k-line libgcc corpus) — b398738
7. bash-3.2 empty-array under set -u in the gcc driver — 17506b7

## ✅ gcc-4.6 all-gcc builds (2026-05-28)

`bake/target/gcc46-all-gcc/bin/xgcc` is a working **GCC 4.6.4** C
front-end (xgcc + cc1, 51 MB), built from the 4 KB seed with no Nix and
no bootstrap-tools.  Three bugs had to be fixed to get here, each
surfacing the next as the build progressed:

1. **tcc libc self-recursion** — `__floatundidf` & 3 other unsigned
   64-bit int↔float helpers were plain casts that tcc lowers back into
   calls to themselves → make stack-overflowed in libiberty.  Fixed in
   `bootstrap/tinycc-sysv-libc.c` (commit e2161fc).
2. **Apple ar can't archive ELF** — `/usr/bin/ar` silently drops our
   ELF objects, leaving libgmp/libmpfr/libmpc empty (mpc configure then
   fails its MPFR ABI link).  Added `bake/scripts/bake-ar.py` (BSD-format
   ELF archiver) + no-op `bake-ranlib` (commit 65431d7).
3. **UTF-8 collation broke gcc's option dedup** — opt-gather.awk sorts
   .opt records and opth-gen.awk merges *adjacent* identical option
   names; UTF-8 collation separated the two `-C` records → duplicate
   `OPT_C` in options.h.  Forced `LC_ALL=C` (commit 5066486).

## Working binaries (target/bin/)

22 working binaries: hex0, hex1-darwin, hex2-darwin, catm-darwin,
M0-darwin, macho-patcher, cc_arch-darwin, M2-darwin, blood-macho-0,
M1-0, hex2-1, M1, hex2, kaem, M2-Planet, mes-m2, elf64-to-m1,
hex2-data-relocs, m1-to-hex2, tcc, tcc-self, tcc-boot1, tcc-boot2,
tcc-boot3, tcc-darwin-cc, make.

All built from `seed/hex0-amd64-darwin` (4096 bytes) + auditable
text source + Apple's `/bin/sh` and `/usr/bin/{ar,nm,ranlib,...}`.
NO nixpkgs, NO bootstrap-tools.tar.xz.

## Verified

- `tcc-darwin-cc hello.c -o hello && ./hello` → exit 42 ✓
- `make --version` → GNU Make 4.4.1 ✓
- All tinycc bootstrap stages converge: tcc-boot1.o == tcc-boot2.o
  byte-identical ✓
- The 6 pure stage0 phases (hex0/hex1/hex2/catm/M0/macho-patcher)
  produce binaries byte-identical to the Nix-built equivalents ✓

## Blocked

**`make` segfaults on `include` directive with multi-prerequisite
target files.**  Repro:

```sh
mkdir sub
: > sub/conftest.c
for i in 1 2 3 4 5 6; do echo '#include' >> sub/conftest.c; touch sub/conftst$i.h; done
echo "include sub/conftest.Po" > confmf
echo "sub/conftest.o: sub/conftest.c sub/conftst1.h sub/conftst2.h sub/conftst3.h sub/conftst4.h sub/conftst5.h sub/conftst6.h" > sub/conftest.Po
target/bin/make -s -f confmf  ## exits 139 (SIGSEGV)
```

This blocks gcc-4.6's all-gcc build (zlib/configure invokes this
exact pattern when probing for depcomp mode).

Likely a tcc codegen issue in some make code path.  Workaround
options:
* Replace tcc with an inherently more conservative codegen (later
  tinycc has options for this).
* Patch GNU Make's source to avoid the bad path.
* Get gcc-4.6 working with a different make (e.g. Homebrew's gmake)
  long enough to bootstrap a non-tcc gcc, then rebuild make with gcc.

## Trust anchor inventory

* `seed/hex0-amd64-darwin` (4096 bytes Mach-O)
* `sources/*.hex0`, `*.hex2` — auditable text
* `sources/stage0-posix/` — vendored snapshot of oriansj/stage0-posix-1.9.1
* `sources/tinycc/` — vendored tinycc-bootstrappable + mes-bootstrap patch
* `sources/mes-darwin/` — Darwin-specific mes overlay
* Tarballs (downloaded with SHA256 verification by scripts/fetch-sources.sh):
  - mes-0.27.1.tar.gz
  - nyacc-1.09.1.tar.gz
  - make-4.4.1.tar.gz
  - gcc-4.6.4.tar.bz2
  - gmp-4.3.2.tar.bz2, mpfr-2.4.2.tar.bz2, mpc-0.8.1.tar.gz
* Apple-signed system components: `/bin/sh`, `/bin/bash`, `/usr/bin/{ar,nm,ranlib,strip,lipo,otool,perl,sed,grep,...}`
* Darwin kernel + `/usr/lib/dyld`

## Step inventory

50 numbered step scripts in `bake/steps/`:

* 01-14: stage0 chain (hex0 through kaem)
* 15-20: mes/mescc/nyacc
* 21-26: mescc-libc layers
* 27-44: tinycc bootstrap (mescc-link through darwin-cc)
* 45: GNU Make 4.4.1
* 46-47: gcc-4.6 source + Darwin patches
* 48-50: gcc-4.6 all-gcc, libgcc, bootstrap (skeletons; blocked on make)

## tcc-make crash root cause (narrowed)

Minimal repro:

```sh
PATH=bake/target/bin:/usr/bin:/bin
echo 'foo: foo.c'      > mf  # any prereq containing a dot crashes
echo '	@echo ok'     >> mf
touch foo.c
make -f mf  # exits 139 (SIGSEGV)
```

The crash is in make's prereq-handling code path when a prereq filename
contains a dot — this is the path that interfaces with implicit rules.
The bug is present even with `-r` (no built-in rules), so it's not in
pattern-rule lookup itself but in lower-level filename processing.

By contrast, `foo.o: bar` (dot only in target) DOES work.  And dot-free
targets/prereqs work fine.

This is consistent with a tcc codegen bug in some pointer-arithmetic
path that handles the dot character in filenames.  GCC bootstrap is
blocked here.

## Crash pinpointed: pattern_search() implicit-rule machinery

Confirmed via `make -d`: the SIGSEGV fires immediately after
`Considering target file 'foo'` → `File 'foo' does not exist` →
implicit-rule search on the dotted prerequisite.

Proof it's the implicit-rule path: giving the dotted prereq its own
explicit rule (even an empty `foo.c:` rule) makes the crash vanish.
The crash only happens when make falls through to `pattern_search()`
(src/implicit.c) for a name containing a dot.

`pattern_search` uses `alloca` in 4 places (lines 236, 496, 892, 1107),
including `alloca(sizeof(struct file))`.  We build make with
`-Dalloca=malloc` because **tcc-darwin-cc has no working alloca**
(`alloca(64)` → "Target label alloca is not valid" at link, since our
minimal libc exports no alloca symbol and tcc's builtin isn't wired
for the Darwin target).

Candidate root causes (unverified):
* A tcc codegen bug in `pattern_search`'s heavy pointer arithmetic /
  struct-array handling (`struct patdeps *deplist`, stem splitting).
* The `alloca→malloc` substitution interacting badly with code that
  assumes alloca's stack-scoped lifetime (e.g. a pointer kept past the
  malloc block being reused/clobbered).

Next debugging directions:
* Add printf tracing inside pattern_search (recompile just implicit.c)
  to find the faulting line.
* Provide a real heap-based alloca shim that tracks and frees per-call
  rather than leaking, in case lifetime is the issue.
* Try building make with a newer tinycc that has Darwin alloca support.
* Cross-check against live-bootstrap: their tcc-built make runs on
  Linux, so compare the Darwin-specific delta (our libc + wrapper).

## Codegen reproducer: basic patterns are fine

A standalone C program reproducing pattern_search's core shape —
dotted-name stem split via strrchr, a malloc-backed `alloca`, a
`struct dep[]` array built with pointer arithmetic and indexed back —
compiles and runs correctly under tcc-darwin-cc.

So the fault is NOT in those basic patterns.  It's a more specific
construct inside the real `pattern_search` (function-pointer calls,
a global rule table walk, recursion, or a particular struct layout).

Finding it requires recompiling src/implicit.c with printf tracing
bracketing each phase of pattern_search and re-linking make — an
interactive debug cycle, not a blind one.  Parking here: the
no-Nix bootstrap is complete and verified through tcc-darwin-cc +
GNU Make; gcc-4.6 is the one remaining blocker and it is localized
to a single function with a clear (if laborious) path to a fix.

## Recompile-to-trace is blocked by header sensitivity

Attempted the documented next step (recompile src/implicit.c with
printf tracing to find the faulting line).  Hit a wall: standalone
recompilation of implicit.c with the build's exact CFLAGS fails with
`makeint.h:310: incompatible redefinition of 'mode_t'`, even though
step 45's full build compiled the same file successfully.

Root cause of the recompile failure: makeint.h's mode_t typedef is
gated on a fragile combination of HAVE_UMASK / HAVE_UNISTD_H /
STDC_HEADERS plus whatever the tcc-darwin-bootstrap headers already
typedef mode_t as.  The combination that step-45's build used cannot
be trivially reproduced in a one-off `tcc-darwin-cc -c implicit.c`
invocation — the tcc-darwin-cc wrapper's input-combining + caching
makes per-file recompilation non-faithful to the in-build compile.

Implication: the make `pattern_search` crash debugging needs to be
driven *through* a controlled rebuild of all of make (so each .o is
compiled in the same wrapper context the build used), with tracing
baked into the source before step 45 runs — not via standalone
recompiles afterward.  That is an interactive cycle.

This iteration's net finding: the recompile path is itself
environment-sensitive; future debugging should instrument
src/implicit.c in bake/sources before invoking step 45, then run the
full GNU Make build, rather than recompiling one object post-hoc.

## ROOT CAUSE FOUND: tcc integrated-compile preprocessor ≠ tcc -E

Interactive debugging localized the real bug. It is NOT make-specific:

* `tcc-darwin-cc <full CFLAGS> -E src/implicit.c` produces **correct**
  preprocessed output — the `#if !defined(HAVE_UMASK)` block at
  makeint.h:309 is correctly DEAD (0 `typedef int mode_t`, 1
  `typedef unsigned short mode_t` from sys/stat.h).
* `tcc-darwin-cc <full CFLAGS> -c src/implicit.c` (integrated compile)
  ERRORS with `makeint.h:310: incompatible redefinition of 'mode_t'`
  — i.e. the integrated path evaluates the SAME `#if` as LIVE.

So tcc's integrated-compile preprocessor diverges from its standalone
`-E` preprocessor.  The divergence is triggered by macro-table state:
it appears only when `-DSTDC_HEADERS` is also present (which makes
makeint.h pull <stdlib.h>+<string.h>, adding many more macros), and
HAVE_UMASK is dropped/misread by the integrated path under that load.

This strongly implies the `pattern_search` SIGSEGV is the SAME class
of bug — the integrated compiler mis-evaluating a conditional or
mis-tracking macro state, here manifesting as miscompiled code rather
than a visible error.  It also explains the build's non-determinism:
the bug is sensitive to how many macros are live.

## Fix direction: two-phase compile (-E then compile the .i)

Since tcc's `-E` is correct, the fix is to make tcc-darwin-cc compile
in two phases: run `@TCC@ -E ... > x.i` then `@TCC@ -c x.i`.  The
fully-preprocessed `.i` has no `#if`/`#define` directives left, so the
buggy integrated conditional-evaluation never runs.

Validated so far: `-E` output for implicit.c is correct.  Compiling
that `.i` standalone hit only a *reduced-flags* artifact (intmax_t
undefined because the quick test dropped -DNO_ARCHIVES); with the full
flag set the `.i` is self-contained.

NEXT TASK (loop): add a two-phase `-E`→compile mode to
scripts/tinycc/tcc-darwin-cc-bash3.sh, rebuild GNU Make via step 45,
and re-test `make -f mf` on a dotted-prereq Makefile.  If the crash is
gone, run step 48 (gcc-4.6 all-gcc) to completion.

## Refined: macro hash-COLLISION bug in our tcc (not -E vs -c, not count)

Further bisection corrected the earlier hypotheses:

* It is NOT -E vs -c: `-E` and `-c` agree; both lose the macro.
* It is NOT macro count: 21 synthetic `-DHAVE_THING1..20 -DHAVE_UMASK`
  all survive.  Real names are the trigger.
* It IS specific macro-name collisions: the real first-17 HAVE_*
  macros + HAVE_UMASK make `defined(HAVE_UMASK)` return false, while
  neither the first 8 nor macros 9-17 alone do.  Cumulative, name-
  dependent → a hash-bucket collision our tcc mis-handles.

Conclusion: our `tcc-boot3` has a miscompiled macro table / collision
chain in tccpp.c (upstream tinycc handles thousands of macros fine).
`defined()` and macro expansion silently lose entries when enough
real-world names land in colliding buckets.  This is the true root
cause of BOTH the gcc-4.6 mode_t error AND, almost certainly, the
make `pattern_search` SIGSEGV (a different lost macro changing codegen).

### Why workarounds don't fully fix it
* Two-phase `-E`→compile: useless, `-E` is equally affected.
* File `#define`s instead of `-D`: only helps if names don't collide;
  the real names still collide.
* Per-symptom patches (e.g. force mode_t agreement) would unblock the
  mode_t error but not other lost-macro miscompiles like pattern_search.

### Real fix (loop task)
Repair the macro hash/collision handling in our tcc.  Path:
1. Rebuild tcc-boot3 with tccpp.c instrumented (count collisions,
   verify `find_macro`/`define_find` chain walking) to confirm the
   chain-walk is the miscompiled spot.
2. Identify which earlier compiler stage (mescc vs an earlier tcc)
   miscompiles that specific construct in tccpp.c, and either fix the
   construct (rewrite the chain walk in a tcc-codegen-safe way) or fix
   the upstream stage.
3. Rebuild the tcc chain, re-verify `defined(HAVE_UMASK)` survives the
   full gcc-4.6 flag set, then run step 45 (make) + step 48 (all-gcc).

## Update: recompile failure may be a mutated-tree artifact

Important caveat discovered while debugging: step 45 DID successfully
compile implicit.o (all 30 make objects share build timestamp
23:19:37, and the script's `set -eu` would have aborted on any
failed compile).  Yet recompiling implicit.c *now*, in the same
working tree, fails deterministically (5/5) on the mode_t error.

Between the successful build and now, the working tree was mutated by
debugging experiments (fprintf edits + restores, partial step re-runs,
patch_replace tests).  The current `src/config.h` / headers may differ
from what step 45's clean run produced.

So the open question is sharper: is the macro-loss bug
(a) real and reproducible from a clean build, or
(b) an artifact of the mutated tree (e.g. a corrupted config.h)?

Decisive experiment now running: a FRESH `bake/steps/45-gnumake.sh`
(re-extracts make-4.4.1.tar.gz, regenerates config.h, recompiles all
30 objects).  Outcomes:
* If the fresh build's implicit.c compile FAILS → bug is real; proceed
  to traced-tcc rebuild.
* If it SUCCEEDS and `make` still SIGSEGVs on dotted prereqs → the
  pattern_search miscompile is real and separate from the recompile
  artifact; instrument that.
* If it SUCCEEDS and `make` no longer crashes → the earlier crash was
  itself a mutated-tree artifact and gcc-4.6 may just work.

Earlier ruled-out (still valid): not -E-vs-c divergence, not macro
count (2000 synthetic idents fine), not tok_alloc hash collision
(HAVE_UMASK alone in bucket 1274), not table_ident 512-realloc.

## BREAKTHROUGH: the make crash was a mutated-tree artifact

Fresh `bake/steps/45-gnumake.sh` (re-extract + regenerate config.h +
recompile all 30 objects) → builds clean, AND the resulting make:
* `foo: foo.c` dotted-prereq Makefile → exit 0 (NO crash)
* zlib-style `include sub/conftest.Po` pattern → exit 0 (NO crash)

So the earlier `pattern_search` SIGSEGV was NOT a tcc codegen/macro
bug.  It came from a make binary built in a tree that my own
debugging experiments had corrupted (stray fprintf edits, partial
step re-runs, patch_replace tests left src/ + config.h inconsistent).
A clean rebuild produces a fully working make.

Lesson: do destructive debugging in a COPY, never in target/work/.

Next: re-run gcc-4.6 all-gcc (step 48) with the clean make.  The
original all-gcc failure was zlib/configure's make invocations
segfaulting — which was the same corrupted-make symptom.  With a
clean make this should now proceed.

## REAL bug found via macOS crash report: make stack overflow (self-recursion)

The gcc-4.6 all-gcc build deterministically dies at `all-libiberty
Error 139`.  The recursive sub-make (`make <~150 vars> all`) SIGSEGVs.
macOS crash report (~/Library/Logs/DiagnosticReports/make-*.ips) is
decisive:

* `EXC_BAD_ACCESS (SIGSEGV)`, `KERN_PROTECTION_FAILURE`,
  message "Could not determine thread index for stack guard region"
  → classic STACK OVERFLOW.
* Faulting backtrace: `make+311458` (vmaddr ~0x64C022) repeated 6+
  times — a function recursing on ITSELF until it hits the stack
  guard page.

Key facts:
* `LC_MAIN stacksize 0` → kernel gives the normal 8 MB main stack, so
  this is NOT a too-small-stack problem; it's UNBOUNDED recursion (a
  termination guard that never fires).
* A clean make handles small Makefiles + dotted prereqs fine; only
  libiberty's real (configure-generated) Makefile triggers the runaway
  recursion.
* Not reproducible with synthetic Makefiles, large var lists (200),
  or large environments (400) — needs libiberty's actual Makefile.

Most likely the self-recursing function is GNU Make's recursive
variable expansion (`variable_expand_string`/`expand`) or
`pattern_search`; a guard/loop-detection comparison is failing — quite
possibly a tcc-codegen issue in that specific comparison (consistent
with the earlier suspicion, now pinned to one runaway function rather
than "macros").

### NEXT TASK (loop)
1. Rebuild make keeping its symbol table (or build a symbol map) so
   the crashing function at vmaddr 0x64C022 can be named.
2. Reproduce the failing libiberty sub-make standalone (clean
   libiberty objects + the exact `make <vars> all` command), capture a
   fresh symbolized crash report.
3. Identify the self-recursing function + its termination guard; check
   whether tcc miscompiles that comparison (compare codegen vs a
   reference) and patch make or the codegen.

## Sharper evidence: recursive-variable expansion, MAKEINFO compounds

Reproduced the crash standalone in build/ (`make all-libiberty`),
even with NO extra command-line vars.  The failing rule is
`Makefile:9580 all-libiberty`, whose recipe spawns a child make for
libiberty; the CHILD make SIGSEGVs (stack overflow).

Critical tell: across recursion levels the child's MAKEINFO grows:
* level 1: `MAKEINFO=true --split-size=5000000`
* level 2: `MAKEINFO=true --split-size=5000000 --split-size=5000000`
* level 3: `... --split-size=5000000 --split-size=5000000 --split-size=5000000`

i.e. a recursively-expanded make variable is being re-appended /
re-expanded on each level instead of staying fixed.  Combined with the
self-recursion stack overflow at make+0x64C022, this strongly points
to GNU Make's recursive *variable expansion*
(`variable_expand_string`/`recursively_expand`) entering an unbounded
self-reference under our tcc-built make — NOT pattern_search.

Note: `make all` run *directly inside* libiberty/ works (exit 0); only
the parent-spawned child (inheriting MAKEFLAGS/MAKEOVERRIDES + the
gcc top Makefile's variable graph) loops.  So the trigger is the
inherited variable state, expanded by the gcc Makefile's machinery.

### Refined NEXT TASK (#72)
1. Symbolize make (build with -g + keep symtab, or build a vmaddr→name
   map) to confirm make+0x64C022 is in variable.c/expand.c.
2. Run the failing child libiberty make with `--debug=v` to see which
   variable expands without terminating.
3. Inspect that variable's recursion guard in
   recursively_expand_for_file / reference_variable; check for a
   tcc-miscompiled comparison (e.g. the `v->expanding` reentrancy flag
   used to detect self-reference).  The `expanding` guard is the prime
   suspect — if tcc miscompiles its set/clear/test, self-reference
   detection fails → infinite recursion.

## CORRECTION: crash is at target consideration (implicit-rule search), not var expansion

Ran the failing child libiberty make with `--debug=v`.  It crashes
immediately after:
  `Considering target file 'all'.`
  ` File 'all' does not exist.`
— i.e. during target/prerequisite + implicit-rule consideration for
the `all` target, BEFORE any deep recursive variable expansion.  So
the MAKEINFO `--split-size` compounding was a red herring (normal gcc
flag passing); the loop is back in the implicit-rule / pattern_search
path (consistent with the make+0x64C022 self-recursion).

Crucial differentiator:
* `make all` run directly in libiberty/ → exit 0 (no crash).
* The parent-spawned child `make <~150 BASE_FLAGS_TO_PASS vars> all`
  in libiberty/ → SIGSEGV considering 'all'.
So the trigger is the large inherited COMMAND-LINE VARIABLE set
changing how make considers/searches rules for 'all'.  (Synthetic
200-var tests did NOT trigger it, so it's specific vars/values, likely
ones that define or perturb suffix/pattern rules, e.g. the *_FOR_TARGET
or STAGE*_CFLAGS entries, or a value containing characters that make
treats as a rule.)

### NEXT TASK (#72) — concrete bisection
1. cd into a clean libiberty/, run `make <BASE_FLAGS_TO_PASS> all`
   verbatim → confirm standalone reproduction.
2. Bisect the ~150 command-line vars (binary search) to the minimal
   set that triggers the crash considering 'all'.
3. With the offending var(s) known, inspect pattern_search /
   try_implicit_rule for why that var's value causes unbounded
   recursion; compare tcc codegen of the recursion guard vs reference.

## Tight reproduction + open question (bounded-deep vs infinite)

One-line repro (no giant var list needed):
  `cd <clean libiberty build dir> && rm -f *.o && make alloca.o`
  → SIGSEGV.  `-d` shows it dies right after
  "Considering target file 'alloca.o' / File 'alloca.o' does not exist"
  → inside pattern_search for that .o target.

Even a single object target crashes; plain `make all` with NO extra
vars crashes.  So the command-line variables are NOT the trigger (that
was a wrong turn) — it's pattern_search on libiberty's .o targets.

Minimal synthetic pattern-rule Makefiles (`%.o: %.c`, `%.c: %.y`,
VPATH, source present/absent) all build fine on the clean make — so
the trigger is the SCALE/structure of libiberty's implicit-rule set,
not pattern rules in general.

Open question for the fix:
* Truly infinite recursion (a termination guard miscompiled by tcc), OR
* Bounded-but-deep recursion whose per-frame stack usage is much larger
  under tcc's naive codegen (no reg alloc, big locals) than under gcc,
  overflowing the 8 MB stack at a depth gcc handles fine.
  (Note: make built with -Dalloca=malloc, so pattern_search's alloca
  calls are heap, not stack — argues against per-frame bloat and FOR
  genuine unbounded recursion.)

### NEXT TASK (#72) — decisive instrumentation
1. Add a depth counter + fprintf to pattern_search (recursions param)
   in bake/sources … rebuild make via step 45.
2. `make alloca.o` in clean libiberty; observe whether depth climbs
   without bound (infinite) or hits a huge finite number (stack size).
3. If infinite: find the guard that fails (compare tcc codegen vs ref).
   If deep-finite: reduce frame size or raise stack.

## ✅ ROOT CAUSE FOUND AND FIXED (definitive)

The crash was **not** in make at all — not pattern_search, not implicit
rules, not macro evaluation. All earlier hypotheses above are
superseded.

**The bug: four 64-bit int↔float conversion helpers in our tcc libc
(`bootstrap/tinycc-sysv-libc.c`) recursed into themselves forever.**

Original (broken) definitions:
```c
double __floatundidf(unsigned long x) { return (double)x; }
long double __floatundixf(unsigned long x) { return (long double)x; }
unsigned long __fixunsdfdi(double x) { return (unsigned long)x; }
unsigned long __fixunsxfdi(long double x) { return (unsigned long)x; }
```
A `(double)(unsigned long)` cast is *lowered by tcc into a call to
`__floatundidf`* — so the body of `__floatundidf` called
`__floatundidf`, with no base case. Confirmed via relocation:
`__floatundidf`'s only `callq` carries `R_X86_64_PLT32 __floatundidf`.

When make built libiberty it performed a u64→double conversion (file
timestamp / numeric formatting path inside the libc), entered
`__floatundidf`, and stack-overflowed (EXC_BAD_ACCESS at the stack
guard page; crash report showed `make+<off>` repeating).

### How it was localized
1. Instrumented pattern_search depth → **0 calls** before the crash
   (with `fflush`), ruling out implicit-rule search entirely.
2. Built make 4.4.1 with system clang → built `alloca.o` fine. Same
   make version, same Makefile ⇒ a tcc/libc codegen bug, not make.
3. Disassembled the tcc-built make at the crashing offset: a tiny
   function that reloads its pointer arg and unconditionally calls
   itself. Matched it by shape to `__floatundidf` in
   `tinycc-sysv-libc.o`; confirmed by its self-referential relocation.

### The fix
tcc emits *inline* hardware conversions for **signed** 64-bit and all
32-bit casts (`cvtsi2sd` / `cvttsd2si`); only the **unsigned** 64-bit
casts lower to a libcall. So the four unsigned helpers are now
implemented via signed-64 casts + the standard shift/sticky-bit trick
(see `bootstrap/tinycc-sysv-libc.c`). The signed helpers
(`__floatdidf`, `__fixdfdi`) were always inline and are left as plain
casts.

Empirical cast→libcall map (verified with tcc-darwin-cc -c + objdump):
| cast | lowering |
|------|----------|
| (double)(int), (double)(unsigned), (double)(long) | inline |
| (long)(double), (int)(double), (unsigned)(double) | inline |
| (long double)(int/long), (long)(long double) | inline |
| **(double)(unsigned long)** | call __floatundidf |
| **(unsigned long)(double)** | call __fixunsdfdi |
| **(long double)(unsigned long)** | call __floatundixf |
| **(unsigned long)(long double)** | call __fixunsxfdi |

### Verified after fix
- Rebuilt libc (step 44): all four helpers show **0** self-call relocs.
- Rebuilt make (step 45): `make alloca.o` in the real libiberty tree
  → **exit 0**, produces `alloca.o`. (Only a cosmetic clock-skew
  warning from the epoch-returning time stubs.)
- This is the exact repro that had crashed throughout this whole arc.

gcc-4.6 all-gcc (step 48) re-run to confirm it clears libiberty: see
build log.

## gcc-10 roadmap (bake) — in progress

Goal: build gcc-10 from the seed.  gcc-10 is C++, so it needs a gcc-4.6
g++ + libstdc++ first.

Key insight: **gcc-4.6 itself is written in C** (GCC went C++-only in
4.8), so its C++ *front-end* cc1plus compiles from C sources via tcc —
the same proven path as step 48's cc1.  Do NOT port the Nix
phase44-cxx.sh: it hardcodes the clang HOST_CC_SOURCES=1 shortcut +
binutils as/ld + macho + SDK, none available to bake.  Instead extend
the bake-native step-48 pattern.

Planned bake steps (51+):
1. **51-gcc46-cxx-all** — rerun the step-48 configure/build but with
   `--enable-languages=c,c++` and target `all-gcc` (builds cc1plus +
   xg++).  Reuse step 48's env: tcc-darwin-cc, bake-ar/bake-ranlib,
   LC_ALL=C, config.cache fixtures.  Expected to behave like step 48.
2. **52-gcc46-libstdc++** — build libstdc++-v3 with the new g++ (via the
   phase36-style xgcc/bootstrap-as wrapper, but g++).  The big C++ unknown
   — this is the part prior attempts found slow; our tcc is ~6 s/file so
   it may be fine.  libsupc++ + libstdc++.
3. **53-gcc10-source / 54-gcc10-build** — fetch gcc-10 + gmp/mpfr/mpc/isl,
   build with gcc-4.6 g++ as host compiler (no clang).  Mirror gcc-10/
   source.nix + scripts/gcc-modern/bootstrap-gcc.sh, swapping host clang
   for our gcc-4.6 g++ and host as/ld for bootstrap-as + tcc link path.

Success: g++ compiles+runs a C++ program (step 51/52); then xgcc-10
compiles+runs a C program (step 54).

## gcc-10 progress — cc1plus blocked on hex2 OOM (2026-05-29)

Step 51 (gcc-4.6 c,c++) builds **all 320 gcc objects + cc1 (51MB) + xgcc**
via tcc, but the final **cc1plus link fails in hex2** with
`failed to allocate entry->name` (hex2_linker.c:140 — calloc NULL).

Ruled out:
* Disk/swap: fails with 18G free, 32GB RAM, ulimits unlimited.
* Mach-O __TEXT overflow: the two-tier large layout (42MB) is used; no
  "align target before current address" — text fits.
* Layout speed: two-tier (small default / large fallback) restored fast
  conftests (gmp/mpfr/mpc configure quick again).

Anomaly: hex2's `jump_tables` is a fixed 65537-bucket hash; per-label
entries are tiny. A small calloc failing implies either a huge label
count (cc1plus is ~1.3x cc1, which links fine — doesn't obviously
explain it) or a corrupt `length(scratch)`.  Suspect: `consume_token`
(hex2_linker.c:48) never writes a trailing NUL — it relies on
Clear_Scratch pre-zeroing; a long C++ mangled name could leave
`length(scratch)` reading stale bytes → calloc(huge).  UNCONFIRMED.

NEXT (focused debug, do fresh): reproduce the cc1plus link keeping
combined.M1 (intercept the tcc-darwin-cc wrapper's $tmp), then either
  (a) instrument storeLabel to print length(scratch) + a running label
      count + hex2 RSS, OR
  (b) test the 1-line fix `scratch[i]=0;` at end of consume_token (needs
      hex2 rebuilt from stage0, or a tcc-compiled hex2 for testing) and
      re-link cc1plus.
If hex2 genuinely can't scale to cc1plus-size C++ binaries, consider a
more memory-careful linker path for the large tier.

## gcc-4.6 c,c++ — cc1plus LINKS (brk fix); xgcc driver crashes (2026-05-29)

After the Darwin brk 512MB→1.75GB fix (M2libc unistd.c), step 51 now
builds **cc1 (51MB) + cc1plus (75MB, large layout) + xgcc** — the
cc1plus hex2 OOM is GONE.  all-gcc still "fails" only at the `specs`
target because the **xgcc driver itself segfaults at startup** (NULL
deref / KERN_INVALID_ADDRESS at 0x0; backtrace main→…→xgcc+212268).
The C-only xgcc (step 48) worked, so this is a tcc-codegen bug in the
*larger c,c++ spec tables* of gcc.c's driver init.

DON'T deep-debug the symbol-less xgcc.  bake already **bypasses the real
driver**: step 50 (phase37-driver.sh) generates a shell-script `gcc`
that invokes cc1 + the bootstrap-as directly.  Plan: build an analogous
**g++ wrapper around cc1plus** (+ a c,c++ `gcc` wrapper), so the broken
xgcc driver is irrelevant.  cc1plus is a working compiler (it links).

NEXT: (1) confirm cc1plus compiles a C++ TU to asm when invoked the way
the driver would (mirror phase37's cc1 invocation but cc1plus + the
C++ include paths); (2) generalize phase37-driver.sh (or a new step) to
emit a g++ wrapper; (3) libstdc++-v3 via that g++; (4) gcc-10 via gcc-4.6
g++.  If cc1plus/g++ runtime OOMs brk again, bump the 1.75GB region
(stay <2GB or widen __darwin_mmap length to long) + rebuild hex2 (step13).

## cc1plus VALIDATED as a working C++ compiler (2026-05-29)

Direct test: `cc1plus -quiet -I<sysroot> t.cc -o t.s` on a class with a
ctor + method → produced Mach-O asm with mangled symbols (__ZN1PC1Ei).
So the C++ FRONT-END works; only the xgcc *driver* is broken (bypass via
a g++ wrapper around cc1plus — see prior section).

Heads-up for the g++ wrapper's bootstrap-as: cc1plus emits C++-specific
Mach-O directives the current scripts/gcc46/phase36-bootstrap-as.c does
NOT yet translate — at least:
  .section __TEXT,__textcoal_nt,coalesced,pure_instructions  (coalesced
      text for template/weak/inline defs)
  .weak_definition <sym>
  .align 1   (already handled: .align N -> 2^N bytes)
Extend the C filter to map __textcoal_nt -> .text (or a coalesced
equiv tcc accepts), drop/translate .weak_definition, and handle any
__TEXT,__const_coal / __DATA,__datacoal_nt sections similarly.  Re-verify
byte-identity isn't required here (new directives), just that tcc's
assembler accepts the output and symbols resolve.

## C++ end-to-end VALIDATED via bake toolchain (2026-05-29)

A self-contained C++ program (class P{ctor; g()}; main returns p.g())
compiled + assembled + linked + RAN through the bake toolchain:
  cc1plus -quiet -I<sysroot> t.cc -o t.s    (gcc-4.6 C++ frontend)
  as-filter < t.s > f.s                      (phase36-bootstrap-as.c, C++-aware)
  tcc-darwin-cc -c f.s -o t.o                (assemble → ELF)
  tcc-darwin-cc t.o -o exe                   (link → Mach-O)
  ./exe → exit 42  ✓
No libstdc++ needed for this TU (no iostream/exceptions). Confirms the
g++-wrapper approach end-to-end; the broken xgcc driver is irrelevant.

NEXT: formalize a g++ wrapper (phase37-style) so gcc-10's build can call
`g++`; then libstdc++-v3 (where cross-TU weak-symbol coalescing in hex2
is the expected hard part); then gcc-10 via gcc-4.6 g++.

## g++ wrapper works — multi-file C++ links+runs (2026-05-29)

A focused g++ wrapper (saved as scripts/gcc46/gxx-bootstrap-wrapper.sh,
@PLACEHOLDER@ template) drives cc1plus + bootstrap-as + tcc-darwin-cc,
bypassing the broken xgcc driver.  Validated: separate compilation of a
two-file C++ program (b.cc calls helper() defined in a.cc) → a.o + b.o →
linked → exit 42.  Cross-TU symbol resolution works through the bake
linker for ordinary (non-weak) symbols.

NEXT: (1) bake step that substitutes the wrapper's paths and installs a
`g++` (and a c,c++ `gcc`) next to the gcc-4.6 cxx build; (2) libstdc++-v3
via that g++ — the hard part: cc1plus emits many WEAK/coalesced symbols
(templates/inlines) and the same symbol will appear in multiple TUs;
hex2_linker.c storeLabel will see duplicate labels.  Need hex2 to accept
duplicate labels (first-wins) OR the wrapper to dedup objects, OR
compile libstdc++ as one big TU.  (3) gcc-10 via gcc-4.6 g++.

## Weak-symbol cross-TU linking — NOT a blocker (2026-05-29)

Probed the feared hard problem directly: two C++ TUs both emitting the
same weak inline symbol (_Z6sharedv) compiled with target/gcc46-cxx/bin/g++
and LINKED without error → program ran, exit 42.  hex2_linker.c storeLabel
prepends each label to its hash bucket and GetTarget returns the latest,
so duplicate (identical) weak/coalesced defs are tolerated (last-wins).
=> libstdc++/gcc-10 C++ linking should not choke on template/inline
duplicates.  Big de-risk.

NEXT: build libstdc++-v3 (or go straight to gcc-10, providing libstdc++
headers it needs) via target/gcc46-cxx/bin/g++; then gcc-10 source+build
via gcc-4.6 g++.

## libstdc++ autotools configure is impractical with our toolchain (2026-05-29)

Ran libstdc++-v3/configure with CC=tcc-darwin-cc CXX=our g++: after ~50
min it had completed only ~12 autotools checks (stuck around "make
supports nested variables").  Every C++ conftest compiles via cc1plus
(75MB) and LINKS a 51MB Mach-O (the fixed-layout padding), and configure
runs hundreds — plus the shell/make probes themselves crawl.  Not viable
as-is.  Killed.

To finish gcc-10 we need ONE of:
  (A) a big toolchain SPEED fix — a per-link "dynamic" Mach-O layout so
      tiny conftests produce tiny/fast binaries (data vmaddr = round-up of
      actual text), instead of always padding to 17.8MB/46MB.  Would make
      all configures (libstdc++, gcc-10) tractable.  Sizeable change to
      tcc-darwin-cc + m1-to-hex2 (compute text size, emit a matching
      per-link Mach-O template).  Highest-leverage.
  (B) hand-roll libstdc++: write include/bits/c++config.h (+ os/cpu
      defines) by hand for x86_64-darwin, skip configure, build only the
      libstdc++/libsupc++ pieces gcc-10 links.  Intricate, fragile.
  (C) pre-seed a complete config.cache so configure skips all conftests
      (still pays the slow shell probes, but maybe tractable).

RECOMMEND (A) — the dynamic layout also retroactively speeds every gcc
configure.  This is the real blocker between "working from-seed g++" and
"gcc-10".

## SPEC: dynamic per-link Mach-O layout (chosen 2026-05-29) — implement fresh

Goal: stop padding every binary to a fixed 18MB/46MB; size each binary's
__TEXT to its actual code so conftests are tiny/fast.  Unblocks libstdc++
+ gcc-10 configures and speeds all gcc configures.  Replaces the two-tier
small/large layout in tcc-darwin-cc{,-bash3}.sh.

How linking works today (wrapper): build combined.M1 (code, then ':ELF_data'
then ':HEX2_data' then data); m1-to-hex2 --base-address 0x600400
--align-label ELF_data=DATA_VMADDR pads code up to DATA_VMADDR at the
':ELF_data' token, emits data → combined.hex2; hex2 --base-address 0x600000
-f <MACHO-template> -f combined.hex2 -o out (template = Mach-O header+load
commands for 0x600000..0x600400 with segment vmaddr/vmsize/fileoff baked
in); dd pads file to linkeditOffset.  Template fields (LE 8-byte) at lowdata
lines NR 10/11/15/19/20/24/25 = __TEXT vmaddr/vmsize, __TEXT fileoff/
filesize, __text sect addr/size(=vmsize-0x400), __DATA vmaddr, __DATA
vmsize/fileoff, __LINKEDIT vmaddr/vmsize(0x1000), __LINKEDIT fileoff.
Relationships (verified): data_vmaddr=0x600000+text_vmsize; data_fileoff=
text_filesize=text_vmsize; linkedit_vmaddr=data_vmaddr+data_vmsize;
linkedit_fileoff=data_fileoff+data_vmsize=linkeditOffset.

Implementation:
1. m1-to-hex2.c: add `--auto-data-align` (or treat --align-label ELF_data=0
   as auto).  At the ':ELF_data' token, set target = round_up(address,
   0x10000) instead of a fixed lookup; pad to it; remember DATA_VMADDR=
   target.  At EOF remember DATA_END=address.  Print "DATA_VMADDR=0x..
   DATA_END=0x.." to stderr (or a sidecar -o.meta file).  Keep the old
   fixed --align-label path for compatibility.
2. wrapper: run m1-to-hex2 in auto mode; capture DATA_VMADDR + DATA_END.
   Compute: text_vmsize=DATA_VMADDR-0x600000; data_vmsize=round_up(
   DATA_END-DATA_VMADDR,0x10000); then the 7 fields.  LE-encode each via a
   shell helper (for i in 0..7: byte=(v>>(8*i))&255; printf '%02x ').
   Generate the per-link template by awk-substituting lowdata (move the
   step-44 awk into the wrapper, parameterized).  Run hex2; dd to
   linkeditOffset=data_fileoff+data_vmsize.
3. Drop the small/large two-tier branch + the two static templates (step
   44 / darwin-cc.nix) once dynamic works; keep lowdata as the base.
4. VERIFY CAREFULLY (a wrong byte breaks ALL linking): hello (exit 42) and
   a re-link of cc1plus (the 75MB binary) must both work; small binaries
   should now be a few-hundred-KB, not 51MB.  Then re-run libstdc++
   configure (should be fast now).

RISK: delicate Mach-O byte math; test hello + cc1plus before trusting.

## Dynamic-layout impl note: M2-Planet operator constraints (2026-05-29)

m1-to-hex2.c (compiled by M2-Planet/M2-darwin, NOT tcc — bake step 43)
uses ONLY comparisons + add/subtract; it avoids >> << & | ~ / % (the
file header warns M2-Planet codegen is unreliable for some constructs on
Darwin).  So the dynamic-layout additions to m1-to-hex2.c must:
  - round_up(address,0x10000): avoid &/~ — and verify M2-Planet supports
    / and * first (the file never uses them). Safe fallback without /,%,&:
    keep a running page boundary while emitting, or precompute via a
    subtract-loop.  EASIEST: empirically test whether M2-darwin compiles
    `/`, `%`, `&`, `>>` with a tiny probe before relying on them.
  - hex-report of DATA_VMADDR/DATA_END to stderr: nibble extraction needs
    /16 or >>4 — verify support, else build the value as decimal (fputs
    an int via repeated /10) and have the wrapper read decimal, OR emit
    via the existing hex_char with a /-based nibble loop.
DO THIS FRESH with empirical M2-Planet operator testing — a wrong codegen
assumption here silently corrupts every linked binary. The wrapper side
(LE-byte template gen) is plain bash and lower-risk.

## RESOLVED: dynamic per-link Mach-O layout (2026-05-29, commits a322756 + 4b6d814)

DONE and verified on both ends of the size range:
- m1-to-hex2.c `--auto-data-align`: data target = round_up(address,0x10000)
  (computed with /,*,%,& — M2-darwin DOES support them, hex2_linker.c uses
  them; m1-to-hex2 just never did). Reports `DATA_VMADDR=.. DATA_END=..`
  hex to stderr via a /16-recursive fput_hex.
- wrapper (tcc-darwin-cc-bash3.sh): runs auto mode, captures DATA_VMADDR/
  DATA_END, computes 8 segment fields, LE-encodes via `le8`, awk-substitutes
  lowdata at NR 10/11/15/19/20/21/24/25, runs hex2, dd-pads to linkeditOffset.
- THE BUG that cost a cycle: __DATA *filesize* (template line 21, NR==21)
  was NOT being substituted — it inherited lowdata's hardcoded 0x2000000
  (32MB). For small binaries that's > the file size, so the kernel SIGKILL'd
  them on exec ("filesize ... past end of file" in otool -l). Fix: NR==21
  field1 = data_vmsize (keep prot bytes "03 00 00 00 03 00 00 00").
- Step 44 now just `cp`s lowdata; old small/large template generation removed.
- VERIFIED: hello.c -> 128KB, exit 42 (was 51MB). cc1plus relinked 75MB->37MB,
  runs (`cc1plus -version` => GNU C++ (GCC) 4.6.4), no past-end-of-file.

TODO (Nix consistency, lower priority — bake path unaffected): port the same
dynamic layout into scripts/tinycc/tcc-darwin-cc.sh + tinycc/darwin-cc.nix
(they still have the old two-tier static templates).

NEXT (gcc-10 path): libstdc++ configure should be fast now -> c++config.h ->
wire headers into g++ wrapper -> build libstdc++ pieces -> gcc-10 all-gcc.

## ROOT CAUSE: dynamic layout crashed large binaries (2026-05-29, fix ab92310)

After the dynamic layout landed, hello/conftests worked but cc1/cc1plus
SIGSEGV'd (EXC_BAD_ACCESS at 0x8200024) on real compilation. Long bisect:
ruled out layout size (FORCE_LARGE crashed), cache (cleared, still crashed),
wrapper combine path, m1-to-hex2 (pre-auto-data-align rebuild still crashed).
Decisive test: relinked the known-good cc1 at its exact proven config with
the GENERATED template and `cmp` vs the original — the ONLY header diff was
at byte 0xd1: my __text SECTION vmaddr = 0x600200, original = 0x600400.

Bug: wrapper n15 used `le8 6291968` (0x600000 + 512) instead of
`le8 6292480` (0x600000 + 0x400 header). The 512-byte section shift was
harmless for tiny binaries but corrupted section-relative addressing in
large ones. Fixed → relinked cc1 byte-identical to original; cc1 (37MB) and
cc1plus (38MB) compile via pure dynamic path; g++ C++ smoke test exits 42.

Lesson: verify generated Mach-O templates byte-for-byte against a known-good
reference, not just "it loads + tiny test runs".

gcc-4.6 C and C++ front-ends now build+run from seed with the fast dynamic
layout. NEXT: libstdc++ (configure fast now) -> gcc-10.

## gcc-10 path progress + SSE assembler blocker (2026-05-30)

Toolchain bugs fixed+committed this session (all prerequisites for gcc-10):
- Dynamic Mach-O layout n15 __text section vmaddr 0x600200→0x600400 (ab92310)
  — was crashing all large binaries (cc1plus etc.).
- Multi -I include search (8969290): tcc libc open() now translates -errno→
  -1/errno (was a raw stub); gcc incpath.c dedup by ->name not stat dev/ino
  (tcc stat unreliable); g++ wrapper drops -W*.
- g++ wrapper: -isystem $SYSROOT (for #include_next), output defaults to
  basename.s/.o (EH-model probe), wire-in pending.
- C++ header guards: stdbool.h `#define bool int` now #ifndef __cplusplus
  (was corrupting bool→int, numeric_limits<bool>==<int>); time.h includes
  stddef.h for size_t.
- as-filter: .mod_init_func/.mod_term_func→.data, skip __gcc_except_tab.

libstdc++ status: gcc-4.6's OWN libstdc++ (target/work/libstdcxx46), NOT
gcc-10's (gcc-4.6 can't compile C++17). Configures in 47s. libsupc++.a BUILT.
make -k: 114 .lo built; only ~6 FLOAT files fail (complex_io, globals_io,
locale, math_stubs_float/long_double) on SSE/x87 opcodes.

Build-dir artifacts needed (codify into a libstdc++ bake step):
- target/gcc46-darwin-bootstrap-src/gcc/gthr-.h = copy of gthr-single.h
  (standalone configure leaves glibcxx_thread_h empty).
- sysroot unwind.h (copied from gcc build include/).
- libstdc++ configure flags: --disable-shared --disable-libstdcxx-pch
  --disable-multilib --enable-threads=single --enable-cstdio=stdio,
  CPPFLAGS=-isystem <sysroot>.

### BLOCKER: tcc assembler lacks scalar SSE float instructions

Decisive test: `g++` on `double mul(double a,double b){return a*b+1.5;}`
fails — `unknown opcode 'movsd'`. cc1plus emits movsd/mulsd/addsd/cvttsd2si/
movq for doubles; tcc-darwin-cc's assembler rejects them. Because gcc-10's
compiler uses double in many places AND the build path is cc1plus→asm→
tcc-assembler (unlike gcc-4.6 which was built by tcc-compiles-C-directly,
never going through gcc-emitted-SSE-asm), THIS BLOCKS gcc-10.

Fix: add SSE float DEF_ASM_OP entries to vendor/tinycc-bootstrappable/
i386-asm.h. It already has MMX/SSE-integer (movd, movq, packssdw, padd*) and
the OPT_SSE operand type, but is MISSING scalar/packed FLOAT: movss, movsd
(SSE form 0xf20f10/11), movaps/movapd, addss/addsd, subss/subsd, mulss/mulsd,
divss/divsd, cvtsi2ss/sd, cvtss2sd/cvtsd2ss, cvttss2si/cvttsd2si, comiss/sd,
ucomiss/sd, andps/andpd, orps, xorps, pxor (have?), sqrtss/sd, fisttp{s,l,ll}.
Copy encodings from upstream tinycc i386-asm.h. Then rebuild the tcc chain
(steps ~23-41 tinycc-boot1/2/3) and verify it self-hosts + assembles movsd.
This is the critical path to gcc-10.

## MILESTONE: gcc-4.6 libstdc++ WORKS (2026-05-30)

std::string/std::vector program compiles+links+RUNS (exit 41) via the
chain-built g++. Key fixes that got here (all committed):
- tcc assembler: scalar SSE float ops (x86_64-asm.h) + hex immediates (libc
  strtol 0x prefix). DON'T add more opcodes — mes-m2 bootstrap overflows.
- as-filter (phase36-bootstrap-as.c): CRITICAL skip_section reset bug — it
  required trailing ws so bare `\t.text\n` never reset the skip after a
  __gcc_except_tab/__eh_frame, truncating ALL code after the first exception
  table in every C++ object (stdexcept.o was 2404B!). Fixed via dir_eol.
  Also: .private_extern dropped, .mod_init_func/.mod_term_func→.data,
  __gcc_except_tab skipped.
- g++ wrapper: -mno-sse3 (avoid SSE3 fisttp), -isystem for #include_next,
  output defaults basename.s/.o, wired libstdc++ -I + .a link.
- bootstrap headers: stdbool/time.h C++ guards, unwind.h shipped.
- tcc libc: _Unwind_* stubs (EH unsupported but must link),
  __stdinp/__stdoutp/__stderrp (Darwin stdio symbols).

libstdc++ artifacts: target/work/libstdcxx46/libstdc++.a (2MB) +
libsupc++/.libs/libsupc++.a (384KB), wired into g++ wrapper. 3 float/locale
files excluded (c++locale, inst, math_stubs_float — need SSE3, gcc-10
doesn't need them).

NEXT: gcc-10 — configure target/gcc10-source + make all-gcc with our g++
-std=gnu++0x -mno-sse3. Likely final hard problem: global ctors don't run
(.mod_init_func→.data) so gcc-10 static init is dead → crt1 must call them.

## gcc-10 build IN PROGRESS (2026-05-30)

gcc-10 CONFIGURES (52s, --enable-languages=c, our g++ as CXX). make all-gcc
builds the in-tree math libs first. gmp BUILDS OK. mpfr 4.2.2 is the current
blocker:
- long-double-format probe returns 'unknown' with tcc → preseed mpfr/+mpc/
  config.cache: mpfr_cv_c_double_format=IEEE-littleendian,
  mpfr_cv_c_long_double_format=IEEE-littleendian (tcc long double == 64-bit
  double), mpfr_cv_gcc_float128=no, mpfr_cv_fp_nan_inf=yes.
- After forcing re-configure, mpfr now fails "C preprocessor -E fails sanity
  check" — tcc-darwin-cc -E doesn't satisfy autoconf AC_PROG_CPP (likely
  doesn't error on a nonexistent #include). The FIRST configure run passed CPP
  (inherited parent cache). Fix options: preseed ac_cv_prog_CPP / the CPP
  sanity result, OR make tcc -E error on missing headers, OR don't force a
  full re-configure (place caches before the top configure like step 51).

REMAINING to gcc-10: mpfr+mpc+isl configure/build (cache fixtures for tcc),
then gcc proper (cc1/xgcc — gcc-10 C++11 compiled by gcc-4.6 g++ -std=gnu++0x;
unknown if pervasive C++11 walls), then GLOBAL CTORS don't run (.mod_init_func
→.data → crt1 must call them). Build dir: target/work/gcc10-all-gcc/build.

## gcc-10 build-libcpp: tcc can't emit REX.W for 64-bit SSE cvt (2026-05-30)

Progress: build-libcpp C++ compiles (charset/mkdeps built) after C++-compat
header fixes: sys/types.h guards wchar_t (#ifndef __cplusplus); stdarg.h
branches on __TINYC__ (tcc __va_arg form vs gcc __builtin_va_* form). Earlier
walls cleared: config.site depmode pin, mtime flatten, g++ wrapper .c sources +
-MD/-MF forwarding to cc1plus, as-filter drops .constructor/.destructor.

HARD BLOCKER at symtab.o: gcc emits cvttsd2siq/cvttss2siq/cvtsi2sdq (64-bit SSE
int<->double, forced by -mno-sse3). tcc's assembler:
  - does NOT know the q-suffixed mnemonic (unknown opcode 'cvttsd2siq'); AND
  - even the unsuffixed form emits NO REX.W: `cvtsi2sd %rax,%xmm0` and
    `cvtsi2sd %eax,%xmm0` both assemble to `f2 0f 2a c0` (32-bit!) — verified
    by od. `cvttsd2si %xmm0,%rax` likewise `f2 0f 2c c0`. So stripping the q in
    the as-filter would silently produce WRONG 32-bit conversions.
Normal 64-bit ops DO get REX.W (addq %rax,%rbx -> 48 01 c3), so the REX path
works generally — it's specific to these SSE cvt instructions.

Root-cause dig: x86_64-asm.h HAS the OPC_48 REX.W ALT entries (OPT_REG64) for
cvtsi2sd/ss + cvttsd2si/ss; staged tinycc-mes-src == vendor; OPC_48=0x200 fits
uint16_t instr_type; O()/T() macros preserve OPC_48; asm_parse_reg types %rax as
OP_REG64. By source reading the OPC_48 ALT SHOULD match %rax and set rex64=1
(i386-asm.c:911), yet the live binary doesn't. Unresolved why — needs either a
fresh chain rebuild (to test if binary is somehow stale) or a real i386-asm.c
fix. NB active tcc binary mtime (05-30 06:09) postdates the asm.h commits.

Two fix paths (both weighty):
  (A) Fix tcc + rebuild chain. build.sh does rm -rf target (WIPES gcc-10
      progress). Re-running steps 22..44 manually risks the mes-m2 step-23
      overflow (staged source still carries the 5 fisttp entries; re-stage from
      vendor first to drop them). Correct + general if it works.
  (B) as-filter raw-byte emission for the 4 q-suffixed cvt mnemonics with a
      real ModRM/SIB/disp encoder (chain-built C). No rebuild, no overflow, but
      encoder bugs => silent gcc-10 miscompiles. Mitigate by validating every
      operand form's bytes against the host assembler (clang/as) in a test
      battery before trusting it. Operand forms seen: %xmmS,%rD (reg,reg) and
      mem,%xmm (e.g. -8(%rbp)).
Recommendation: (B) — lowest blast radius, fully autonomous, validatable.
