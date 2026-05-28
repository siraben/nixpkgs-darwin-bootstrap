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
