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
