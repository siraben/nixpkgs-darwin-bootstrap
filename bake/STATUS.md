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
→ gcc-4.6 source + patches → all-gcc (BLOCKED — see below)
```

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
