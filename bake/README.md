# Darwin bootstrap, no Nix

A pure-shell, no-Nix, no-bootstrap-tools driver for the Darwin (x86-64 Mach-O,
run under Rosetta 2 on Apple Silicon) bootstrap chain.  Modelled on
live-bootstrap's structure, it rebuilds the whole toolchain from a single 4 KB
committed seed:

```
hex0 → hex1 → hex2 → catm → M0 → macho-patcher → cc_arch → M2-Planet
  → blood-elf → M1 → hex2 (linker) → kaem
  → mes → mescc-libc → tinycc → tcc-darwin-cc   (native Darwin C compiler)
  → GNU Make
  → gcc-4.6 (incl. C++ / libstdc++)
  → gcc-10  →  cc1 + xgcc that compile & run C
```

`sh build.sh` runs the ordered `steps/*.sh` end to end.  A clean from-seed run
into a scratch tree reaches a working gcc-10 `cc1` + `xgcc`;
`scripts/gcc10-goal-test.sh` compiles and runs a C program through the from-seed
`xgcc` and checks it returns 7.

## Layout

```
bake/
├── seed/hex0-amd64-darwin    # 4 KB Mach-O trust anchor (symlink to ../../hex0/seed/)
├── sources/                  # auditable text sources
│   ├── stage0-posix/         #   vendored oriansj/stage0-posix-1.9.1
│   ├── tcc-darwin/           #   the tcc-darwin-cc link wrapper (template) + headers
│   ├── tools/                #   chain-built C helpers: bake-ar.c, m1-split.c,
│   │                         #     tsv-col.c, ctor-table.c, line-rewrite.c,
│   │                         #     synth-inject.c, elf64-to-m1.M1
│   ├── gcc10-darwin/, gcc46-*/, gnumake/, ...
│   └── tools/elf64-to-m1.M1  #   hand-written ELF→M1 converter
├── steps/                    # ordered build scripts: 01-hex0 … 55-gcc10-all-gcc
│                             #   (44b–44g build the chain-built C link tools)
├── scripts/                  # gcc10-env.sh, gcc10-link-cc1.sh, goal test, bake-ar shim
├── tarballs/                 # upstream mes/gcc tarballs (gitignored, SHA-256 pinned)
├── target/                   # build outputs (gitignored)
└── build.sh                  # driver (supports TARGET=, BAKE_START_FROM=, BAKE_STOP_AFTER=)
```

## The chain-built link path (no host awk)

`tcc-darwin-cc` (the native Darwin C compiler/linker wrapper) drives a
tcc → as-filter → ELF→M1 → M1 → hex2 pipeline.  Every host tool that once did
semantically-significant work in that pipeline has been ported to C compiled by
`tcc-darwin-cc` itself (built in steps 44b–44g, each verified byte-identical to
the tool it replaced):

| Tool | Step | Replaces |
|---|---|---|
| `bake-ar` | 44b | host python3 `ar` (stores ELF members verbatim) |
| `m1-split` | 44c | awk `:ELF_data`/`:HEX2_data` code/data splitter |
| `tsv-col` | 44d | awk D/U symbol-set extractor (archive resolution) |
| `ctor-table` | 44e | grep\|sed\|awk C++ `_GLOBAL__sub_I` init-table emitter |
| `line-rewrite` | 44f | awk Mach-O load-command template rewriter |
| `synth-inject` | 44g | awk cross-object `:<sym>_plus_<hex>` label injector |

See [`REVIEW.md`](REVIEW.md) for the codex faithfulness audit and the full
fix-status.

## Trust anchors

1. `seed/hex0-amd64-darwin` (4096 bytes) — the one opaque binary blob.
2. `sources/*` — committed, auditable text: stage0-posix, the hand-written
   tools, the link wrapper, patches, and step scripts.
3. `tarballs/*` — upstream mes / gcc-4.6 / gcc-10 release tarballs, *not*
   committed: fetched by `scripts/fetch-sources.sh` against pinned SHA-256s.
4. `/bin/sh` + POSIX utilities (Apple-signed): `sh`, `make`, `tar`, `cp`, `cmp`,
   `dd`, `grep`.
5. The system **assembler and linker** (`/usr/bin/as`, `/usr/bin/ld`, and
   `/usr/bin/ar`/`ranlib` for archives) for the *gcc-10 target* codegen path: the
   from-seed `xgcc` emits `.s` and hands it to `/usr/bin/as`, and links via
   `/usr/bin/ld`.  The bake chain builds the gcc-10 binaries themselves with its
   own `tcc-darwin-cc → as-filter → hex2` Mach-O pipeline (no host as/ld), but the
   resulting `xgcc` was configured with the platform `as`/`ld` as its target tools
   — so every `xgcc` compile/link (the goal test, and the real `libgcc`) leans on
   them.  Replacing these needs an in-chain Mach-O assembler + executable linker
   (the chain has neither yet); this is the honest current escape hatch.
6. Darwin kernel + `/usr/lib/dyld`.

## Running

```sh
sh build.sh                                   # full chain into bake/target
TARGET=/tmp/verify sh build.sh                # into a scratch tree
TARGET=/tmp/verify sh scripts/gcc10-goal-test.sh   # check xgcc compiles+runs C → 7
```

The gcc-10 phase is long: `cc1plus` runs x86-64 under Rosetta 2.  The final cc1
link is the single largest operation (a ~335 MB combined M1); the chain link
tools' M2libc heap is sized (4 GB) to hold it.

## Status & remaining impurities

[`STATUS.md`](STATUS.md) has the detailed log and the list of repro bugs fixed
to make the manual build reproduce from scratch.  Acknowledged remaining
impurities (documented, outside the gcc link translation path):

- the from-seed `xgcc`'s use of the system `as`/`ld` for target codegen, and the
  remaining EH/unwind `libgcc_eh` stub (its `unwind-dw2.c` needs `<pthread.h>`,
  absent from the chain sysroot).  The **core** `libgcc.a` (arithmetic /
  soft-float) is now a real archive built by the from-seed `xgcc`
  (`scripts/gcc10-build-libgcc.sh`), not a stub;
- the pre-`tcc-darwin-cc` Mes/stage0 M1 section-split helpers (host awk, in the
  steps that run before the C compiler exists);
- chain libc `mkstemp` (the build runs each step with stdin `</dev/null` so
  `configure`'s `make -f -` probe fails fast instead of hanging).
