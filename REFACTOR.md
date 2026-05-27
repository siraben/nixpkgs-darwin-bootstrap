# Refactor: nixpkgs minimal-bootstrap style

Goal: collapse the current ~64 `phases/phaseN-*.nix` files into ~30-35
semantic packages mirroring `~/Git/nixpkgs/pkgs/os-specific/linux/minimal-bootstrap`.

## Target layout

```
default.nix                            — top-level scope via lib.makeScope
flake.nix
sources.nix                            — tarball pins
platforms.nix                          — Darwin platform metadata
gnu-hello.nix                          — final test
checks.nix                             — chain validation tests

stage0-posix/
  default.nix                          — scope binding all stage0 derivations
  hex0.nix                             — hex0 binary from hex0/hex0-amd64-darwin.hex0
  hex1.nix                             — hex1-darwin from hex0/sources/hex1_*.hex0
  hex2.nix                             — hex2-darwin from hex0/sources/hex2_*.hex0
  catm.nix                             — phase2-catm
  m0.nix                               — phase3-m0
  cc-arch.nix                          — phase4-cc-arch
  m2-planet.nix                        — phase5-m2
  blood-elf.nix                        — phase6-blood-macho-0
  mescc-tools-boot.nix                 — phases 7+8 (M1-0, hex2-1) AND 9+10 (M1, hex2)
  kaem.nix                             — phase11-kaem
  bootstrap-sources.nix                — minimal-bootstrap-sources binding

mescc-tools/                           — Darwin-specific MescC helpers
  default.nix                          — scope
  macho-patcher-early.nix              — phase11e (M0-only, breaks cycle)
  macho-patcher.nix                    — phase26g (M1-based, byte-identical)
  elf64-to-m1.nix                      — phase26b
  m1-to-hex2.nix                       — phase11b (M2-Planet C)
  hex2-data-relocs.nix                 — phase11c (M2-Planet C)
  cc-arch-helper.nix                   — phase11d (M2-Planet C)

mes/
  default.nix                          — scope, source fetch, m2 build
  source.nix                           — phase13-mes-source
  m2.nix                               — phase16-mes-m2

mescc-libc/                            — consolidates phases 17-22
  default.nix

tinycc/
  default.nix                          — scope
  mescc.nix                            — phases 23+24+25 (mescc-link, self-compile, self-object)
  self-host.nix                        — phases 30+31+32+33 (self-host candidate, boot1)
  boot2.nix                            — phases 35+36 (boot2)
  boot3.nix                            — phases 37+38 (boot3)
  darwin-cc.nix                        — phase34 (the working TCC for downstream)

gnumake/   default.nix                 — phase39
gnupatch/  default.nix                 — phase40
coreutils/ default.nix                 — phase41

bootstrap-deps/                        — bootstrap GMP/MPFR/MPC/ISL
  default.nix                          — scope
  gmp.nix                              — phase26c
  mpfr.nix                             — phase26d
  mpc.nix                              — phase26e
  isl.nix                              — phase26f

gcc-4.6/
  default.nix                          — scope, source, all-gcc, libgcc, bootstrap, cxx
  source.nix                           — phase26 source
  all-gcc.nix                          — phase35
  libgcc.nix                           — phase36
  bootstrap.nix                        — phase37
  cxx.nix                              — phase44

gcc-10/
  default.nix                          — phase42 source + phase45 build

gcc-latest/
  default.nix                          — phase43 source + phase46 build + phase47 strict

apple-darwin/                          — Darwin host bits packaged
  default.nix                          — scope
  apple-sdk.nix                        — pinned MacOSX.sdk
  cctools.nix                          — pinned cctools
  sigtool.nix                          — codesign wrapper

scripts/                               — KEEP (maintainer regen scripts + awk port helpers)
hex0/                                  — KEEP (hex0 source files)
M2libc/                                — KEEP (committed M2libc + Darwin variants)
tools/                                 — KEEP (M1 macro-asm sources + macho-patcher-m0.M1)
bootstrap/                             — KEEP (M2-Planet C sources)
patches/                               — KEEP (existing patches)
mes-darwin/                            — KEEP (mes Darwin override)
hello/                                 — KEEP (raw-syscall-hello source)
docs/                                  — KEEP
```

## Probes (delete or move to checks.nix)

These are validation-only and not load-bearing for the final chain:
- phase14-mes-m2-probe       → checks.nix or delete
- phase15-mes-macho-link-probe → checks.nix or delete
- phase17-mescc-macho-probe   → checks.nix
- phase18-mescc-libc-mini-probe → checks.nix
- phase19-tinycc-mescc-m1-probe → checks.nix
- phase20-mescc-libmescc-probe → checks.nix
- phase21-mescc-libc-probe    → tinycc/mescc.nix dep (load-bearing)
- phase22-mescc-libc-tcc-probe → checks.nix
- phase24-tinycc-compile-probe → checks.nix
- phase25-tinycc-self-object-probe → checks.nix
- phase27-tinycc-elf-to-macho-probe → checks.nix
- phase28-tinycc-self-m1-probe → checks.nix
- phase29-tinycc-sysv-libc-probe → checks.nix
- phase31-tinycc-self-compile-probe → checks.nix
- phase32-tinycc-boot1-object-probe → checks.nix
- phase35-tinycc-boot2-object-probe → checks.nix
- phase37-tinycc-boot3-object-probe → checks.nix
- tinyccBootstrappableSrc, tinyccMesSrc → into tinycc/sources

## Migration order

Smallest-blast-radius first:
1. **stage0-posix/** (phases 1-11) — DONE (commit 7ee5640)
2. **mescc-tools/** (11b, 11c, 11d, 11e, 26b, 26g) — DONE
3. **mes/** (12, 13, 14, 15, 16) — DONE (probes 14/15 turned out to be load-bearing build steps; renamed without "probe")
4. **mescc-libc/** (17-22) — DONE
5. **tinycc/** (23-25, 27-38, plus tinyccSelf* helpers) — DONE
6. **gnumake/, gnupatch/, coreutils/** (39, 40, 41) — DONE
7. **bootstrap-deps/** (26c-f) — DONE
8. **gcc-4.6/** (26, 35-37, 44) — DONE
9. **gcc-10/** (42, 45) — DONE
10. **gcc-latest/** (43, 46, 47) — DONE
11. **default.nix** rewrite with `lib.makeScope` — NEXT
12. **flake.nix** update exposes new semantic names — NEXT
13. **checks.nix** absorb purely-validation probes — NEXT
14. Rename phaseN-* variables to semantic names + update cross-refs — FINAL
15. Verify gnu-hello-hash-comparison ends at `5019a64510837fae43fc7238b506ec11011542432c792b4ab7683db2e7ff2f73`

## Naming convention

- Drop `phase<N>-` prefix.  Each package gets the upstream name it
  builds (`hex0`, `hex2`, `M2-Planet`, etc.) or a Darwin-specific name
  (`mescc-tools`, `darwin-tools`).
- Sub-attributes inside a scope replace the `<N>` numbering (e.g.
  `tinycc.mescc`, `tinycc.darwin-cc`).
- Probes that survive become attrs in `checks.<system>` (per the
  nixpkgs idiom).
