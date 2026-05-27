# Darwin bootstrap, no Nix

A pure-shell, no-Nix, no-bootstrap-tools driver for the Darwin Mach-O
bootstrap chain.  Models live-bootstrap-bake's structure:

> `hex0 → hex1 → hex2 → catm → M0 → macho-patcher → cc-arch → M2 →
>  blood-elf → M1-0 → hex2-1 → M1 → hex2-linker → kaem → mes-m2 →
>  tinycc → bash → gcc-4.6 → gcc-10 → gcc-latest`

## Layout

```
bake/
├── seed/
│   └── hex0-amd64-darwin              # 4 KB Mach-O trust anchor
├── sources/                           # auditable text sources
│   ├── *.hex0 / *.hex2                # hand-rolled stage0 source (symlinks)
│   └── stage0-posix/                  # vendored from oriansj/stage0-posix-1.9.1
│       ├── M2-Planet/                 #   cc.c + cc_*.c (~250 KB)
│       ├── M2libc/                    #   bootstrappable, fcntl, ctype, etc.
│       └── mescc-tools/               #   blood-elf, M1-macro, hex2*, Kaem/
├── steps/                             # ordered shell scripts
│   ├── 01-hex0.sh ... 14-kaem.sh
├── target/                            # outputs (gitignored)
│   └── bin/
└── build.sh                           # driver
```

## Status (phases 1-11 of the Darwin chain)

| # | Step | Binary | Built by |
|---|---|---|---|
| 01 | 01-hex0.sh | hex0 | seed (self-host) |
| 02 | 02-hex1.sh | hex1-darwin | hex0 |
| 03 | 03-hex2.sh | hex2-darwin | hex0 |
| 04 | 04-catm.sh | catm-darwin | hex2 |
| 05 | 05-m0.sh | M0-darwin | hex2 |
| 06 | 06-macho-patcher-early.sh | macho-patcher | hex2 |
| 07 | 07-cc-arch.sh | cc_arch-darwin | hex0 (final form) |
| 08 | 08-m2.sh | M2-darwin | catm + cc_arch + M0 + hex2 + patcher |
| 09 | 09-blood-elf-macho.sh | blood-macho-0 | M2 + catm + M0 + hex2 + patcher |
| 10 | 10-m1-0.sh | M1-0 | M2 + catm + M0 + hex2 + patcher |
| 11 | 11-hex2-1.sh | hex2-1 | M2 + M1-0 + catm + hex2 + patcher |
| 12 | 12-m1.sh | M1 | M2 + M1-0 + hex2-1 + patcher |
| 13 | 13-hex2-linker.sh | hex2 (final) | M2 + M1 + hex2-1 + patcher |
| 14 | 14-kaem.sh | kaem | M2 + M1 + hex2 + patcher |

All 14 produce working Mach-O binaries with `--help` output matching
the Nix-built versions; functional outputs for the same inputs match
byte-for-byte where verified.

## Trust anchors

1. `seed/hex0-amd64-darwin` (4096 bytes) — the one opaque binary blob.
2. `sources/*.hex0` and `*.hex2` — hand-rolled, auditable.
3. `sources/stage0-posix/` — vendored snapshot of upstream
   oriansj/stage0-posix-1.9.1 sources (hash
   `UNoyb2teqH26VM7YoOcazyqZ0AlDae045aWc31ZHFdw=`).
4. `/bin/sh`, `/bin/cmp`, `/bin/cp`, `/usr/bin/dd`, `/usr/bin/grep` —
   Apple-signed system utilities (no nixpkgs, no Homebrew).
5. Darwin kernel + `/usr/lib/dyld`.

Once `kaem` is built (step 14), `build.sh` could be rewritten as a
kaem script and `/bin/sh` would no longer be in the orchestration
trust path.  That's a near-term cleanup.

## Running

```sh
./build.sh
```

Builds all 14 phases into `target/bin/`.  Takes ~30 minutes on a
2023 MacBook Pro, dominated by hex0 chewing through 80+ MB of zero
padding in early phases and M2 compiling C sources in later phases.

## Next phases (not yet implemented)

- mes-m2 (phase 16) — bigger build, ~10-20 MB output
- mescc-libc (phases 17-22) — .M1 archives
- tinycc bootstrap chain (phases 23-38) — multiple boot stages
- gnumake, gnupatch, coreutils (phases 39-41)
- gcc-4.6 (phases 35-37, 44)
- gcc-10 (phase 45)
- gcc-latest (phases 46, 47)
- Final: gnu-hello-hash-comparison reproduces `5019a64...db2e7ff2f73`
