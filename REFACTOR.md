# Refactor: nixpkgs minimal-bootstrap style — COMPLETE

The chain was collapsed from ~64 `phaseN-*.nix` files into semantic
per-package directories mirroring
`~/Git/nixpkgs/pkgs/os-specific/linux/minimal-bootstrap`: `stage0-posix/`,
`mescc-tools/`, `mes/`, `mescc-libc/`, `tinycc/`, `gnumake/`, `gnupatch/`,
`coreutils/`, `bootstrap-deps/`, `gcc-4.6/`, `gcc-10/`, `gcc-latest/`, plus a
top-level `cctools/`.  Phase numbers were dropped from public attribute and
script names (a few internal `tinycc/boot2-*`/`boot3-*` derivation `name`
strings and `scripts/impure/*` dev helpers still carry `phaseNN`, but these
are not flake-output attrs); validation-only probes became `checks.<system>`
attrs; the shared `utils.nix:mkDarwin` helper bakes in the common
`mkDerivation` defaults.

## Open / deferred

- `lib.makeScope newScope`.  The package `.nix` files already use explicit
  callPackage-style `{a, b, c, ...}:` headers via `callPhase` in
  `packages.nix`.  What remains is the scope plumbing: moving from the
  hand-rolled `phaseDefs` rec set to `lib.makeScope newScope` and tightening
  the trailing `...` / arg filtering.  Cosmetic — the current structure is
  functionally equivalent.

## Naming convention

- No `phase<N>-` prefix: each package takes the upstream name it builds
  (`hex0`, `hex2`, `M2-Planet`, …) or a Darwin-specific name.
- Sub-attributes inside a scope replace the `<N>` numbering
  (e.g. `tinycc.mescc`, `tinycc.darwin-cc`).
- Surviving probes are attrs in `checks.<system>`.

## Maintainer scripts

- `scripts/refactor/` — one-shot layout-refactor tools
  (`drop-isx86-wrapper.py`, `extract-smoke.py`), kept for future passes.
- `scripts/stage0/regen-*.sh` — regenerate the committed seed sources
  (`hex0/sources/**/*.hex0`) and the pre-ported `M2libc`/`macho-patcher`
  artifacts through the chain.

The current gnu-hello baseline is
`0854f4ab9cf255a37ddfb6251198164e6f14f3606239c963d2530f77e257f90a`, enforced
by `gnu-hello-hash-comparison`.
