# Darwin bootstrap, no Nix

A pure-shell, no-Nix, no-bootstrap-tools driver for the Darwin Mach-O
bootstrap chain.  Models live-bootstrap-bake's structure:

> `hex0 → hex1 → hex2 → catm → M0 → macho-patcher-early → cc-arch → M2 → ... → bash → gcc-4.6 → gcc-10 → gcc-latest`

## Layout

```
bake/
├── seed/
│   └── hex0-amd64-darwin              # 4 KB Mach-O trust anchor
├── sources/                           # auditable hex0/hex2 text sources
│   ├── hex0-amd64-darwin.hex0
│   ├── hex1_AMD64_darwin.hex0         # 33 MB ASCII (mostly zeros)
│   ├── hex2_AMD64_darwin.hex0         # 50 MB ASCII (mostly zeros)
│   ├── catm_AMD64_darwin_combined.hex2
│   ├── M0_AMD64_darwin_combined.hex2
│   ├── macho-patcher_AMD64_darwin_combined.hex2
│   └── cc_arch_AMD64_darwin_final.hex0
├── steps/                             # one script per phase
│   ├── 01-hex0.sh                     # cmp seed-output to seed (self-host)
│   ├── 02-hex1.sh
│   ├── 03-hex2.sh
│   ├── 04-catm.sh
│   ├── 05-m0.sh
│   ├── 06-macho-patcher-early.sh
│   └── 07-cc-arch.sh
├── target/                            # outputs accumulate here
│   ├── bin/                           # phase binaries
│   └── share/                         # auxiliary files (templates etc.)
└── build.sh                           # top-level driver
```

## Trust anchors

1. `seed/hex0-amd64-darwin` — 4096 bytes, committed.  Was produced
   historically by clang from `hex0/hex0.c`, but is now used directly
   as bytes and verified self-hosting (it re-assembles itself from
   `sources/hex0-amd64-darwin.hex0` and the result is byte-identical).
2. `sources/*` — auditable text.
3. `/usr/bin/sh` and friends from the system (Apple-signed).
4. The Darwin kernel + `/usr/lib/dyld`.

NOTHING from nixpkgs, NOTHING from `bootstrap-tools.tar.xz`, NO clang
or stdenv anywhere in the build path.

## Running

```sh
./build.sh
```

The driver iterates `steps/*.sh` alphabetically.  Each step takes
inputs from `target/` (and `sources/`) and writes outputs to
`target/bin/` or `target/share/`.

After completion, `target/bin/hex0`, `target/bin/hex1-darwin`, ...,
`target/bin/cc_arch-darwin` exist.

## Status

| Phase | Step file | Status |
|---|---|---|
| hex0 | `01-hex0.sh` | working |
| hex1 | `02-hex1.sh` | working |
| hex2 | `03-hex2.sh` | working |
| catm | `04-catm.sh` | working |
| M0 | `05-m0.sh` | working |
| macho-patcher-early | `06-macho-patcher-early.sh` | working |
| cc-arch | `07-cc-arch.sh` | working |
| M2 / blood-elf / M1 / ... / kaem | (todo) | not yet |
| mes-m2 / mescc-libc / tinycc | (todo) | not yet |
| gnumake / gcc-4.6 / gcc-10 / gcc-latest | (todo) | not yet |
