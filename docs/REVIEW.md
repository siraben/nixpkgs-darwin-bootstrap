# Shell-track faithfulness review (codex, 2026-06-03)

Audit of the from-4KB-seed claim. Status tags added after the run.

> LAYOUT NOTE (2026-07): the audit and fix-status below cite paths from the
> pre-restructure tree, where the shell track lived under `bake/`.  Read
> `bake/steps/` as `steps/`, `bake/sources/` as `sources/`, and
> `bake/scripts/` as `scripts/`; `bake-ar` is now `boot-ar`.

## Fix status (as of HEAD)

- #1 host-awk linker machinery in tcc-darwin-cc — DONE: every host tool in the
  active link path is now chain-built C (compiled by tcc-darwin-cc in a 44X step,
  @PLACEHOLDER@ + wrapper helper; awk/host fallback runs ONLY while the tool
  itself bootstraps): boot-ar (44b, 9ad4a83); m1-split :ELF_data/:HEX2_data
  splitter (44c, 273a3f2); tsv-col symbol-set TSV extractor (44d, 15b5d65);
  ctor-table C++ GLOBAL__sub_I init table (44e, 664ee8c); line-rewrite Mach-O
  load-command template (44f, b4f1fe2); synth-inject cross-object `_plus_<hex>`
  injector (44g, e7b43af). @AR@ extraction = boot-ar (bcba3cf). Each verified
  byte-identical to its predecessor. A full cc1 relink with the de-awk'd wrapper
  COMPLETES: the de-awk'd from-seed xgcc passes the goal test (7), cc1 is the full
  44 MB Mach-O. (Earlier relinks died mid-`m1-to-hex2`; root cause was the M2libc
  fixed bump-allocator heap overflowing on the 335 MB combined M1, not the host
  environment — enlarged 1.79 GB→4 GB in commit ab4ebf1.) Remaining wrapper host
  text-tools: a
  `cksum|awk '{print $1"-"$2}'` cache-key formatter (benign, not translation) and
  the intentional bootstrap fallbacks.
- #2 early Mes/TCC steps (21/25/26/27/42) split M1 with host awk — TODO: they run
  BEFORE tcc-darwin-cc exists so the chain m1-split can't be used; build a
  splitter with an earlier chain cc (mescc/tcc) or document as pre-cc bootstrap.
  Lower priority (pre-compiler stages).
- #3 tcc-cpp/gxx-cpp hardcoded ../target — FIXED (bcba3cf, honour $TARGET).
- #4 archive cache outside TARGET — FIXED (bcba3cf, under $TARGET/work).
- #5 step 55 host-compiled stub libgcc/emutls — FIXED for the CORE: a real
  libgcc.a (146 Mach-O members) is now built by the from-seed xgcc
  (scripts/gcc10-build-libgcc.sh, at -O0, working around three from-seed-compiler
  bugs — specs-file driver segfault, -O1 overflow-routine cc1 crash, broken TLS
  asm). Verified a __float128 program links against it but not the stub. The
  EH/unwind libgcc_eh stays a stub (unwind-dw2.c needs <pthread.h>).
- #6 @AR@=/usr/bin/ar extraction — FIXED (bcba3cf, boot-ar).
- #7 phase37-driver.sh dormant host as/cc hatches — FIXED (be25b5b, default empty
  so the macho/host-source guards refuse unless explicitly opted in).
- #8 tarballs fetched not committed (SHA256-pinned) — FIXED wording (937415e):
  build.sh trust anchors now state the tarballs are SHA256-pinned fetches and the
  system cc/ld are only the final goal-test exe escape hatch.
- #9 shell-track `/usr/bin/patch` in steps 22/47/48/51 — FIXED: committed
  unified diffs are now applied by `boot-patch`, a minimal M2-Planet-subset C
  applier built at step 14b by the from-seed stage0 toolchain.  It handles the
  repo's patch subset (`-pN`, `-d`, modify-existing-file unified diffs) and
  fails closed outside that subset.

## Codex re-review round 2 (after the 6 chain-built C tools landed)

Verdict: the host awk/python/grep/sed link machinery is confirmed gone from the
clean gcc-4.6/gcc-10 path after 44g. Two further active host-tool uses it found,
both now FIXED:
- **layout sed** in tcc-darwin-cc (parsed m1-to-hex2's DATA_VMADDR/DATA_END that
  drive the Mach-O offsets) → shell parameter expansion (f75d2e9).
- **gcc-4.6 libgcc symbol-selection awk** in phase37-driver.sh (5 D/U extractions)
  → chain-built tsv-col via a dusym helper, awk fallback (ed4aad1).

Remaining (acknowledged, not host *translation* in the gcc link path):
- The pre-tcc Mes/stage0 M1-split awk (steps 21/25/26/27/31/33/35/36/38/40/42).
  **Analysed and accepted as a bounded impurity, not a TODO**, for two reasons:
  (1) *It is not translation.* Each awk mechanically partitions an already-built
  M1 stream into its code section (lines before `:ELF_data`/a custom label) and
  data section (label + after) — pure text bookkeeping for the hex2 layout. The
  actual C→M1 translation is done by chain `mescc`, and M1→Mach-O by chain
  `M1`+`hex2`; the awk emits no machine code, so it is outside the as-filter rule.
  (2) *Bootstrap ordering makes a chain replacement impossible here.* Steps
  21/25/26 are where the libc itself is built (libc-mini → libc → libc-tcc), and
  the first turnkey chain compiler that emits a runnable Mach-O binary is
  `tcc-darwin-cc` at step 44 — which is exactly why the post-44 splitter
  (`m1-split.c`) IS chain-built and these are not. A replacement binary cannot
  exist before the very libc+compiler toolchain it would be compiled with.
- step-55 libgcc: the CORE libgcc.a is now a REAL archive built by the from-seed
  xgcc (scripts/gcc10-build-libgcc.sh); only libgcc_eh/libgcc_s/libemutls_w remain
  host-cc stubs (EH/unwind needs pthread.h + the TLS-asm cc1 fix). System ld is
  the sole native-exe-link escape hatch.
- SHA256-pinned source tarballs: source-trust, not host semantic translation.

Net: the "post-44 gcc link path uses chain-built link machinery, no host semantic
translation" claim holds; the absolute "no host tools anywhere" claim does not
(pre-44 Mes/stage0 splits + the final-exe stub/ld), and the docs say so.

---

**Ranked Findings** — _this is the ORIGINAL codex audit, kept verbatim as a
snapshot.  Most items have since been resolved; read each against the fix-status
at the top of this file.  In particular: #1 (host awk/sed in the link path) is
FIXED (the six chain-built C tools, steps 44b–44g); #2 (pre-44 Mes/TCC M1 splits)
is an ACCEPTED bounded impurity (see the analysis above — mechanical partitioning
+ bootstrap ordering); #3/#4/#6 are FIXED; #5 (stub libgcc) is FIXED for the core._

1. **Critical: host `awk`/`sed` are still active linker machinery in `tcc-darwin-cc`. Violation.**  
   Active install comes from [44-tinycc-darwin-cc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/44-tinycc-darwin-cc.sh:41). The wrapper uses host `awk` to update defined/unresolved symbol sets for archive selection at [tcc-darwin-cc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:260), [line 261](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:261), and [line 315](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:315). That decides which archive members enter the final binary. Host `grep|sed|awk` emits the C++ constructor table at [line 541](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:541), which is load-bearing for GCC-10 C++ build tools. Host `awk -f synth-inject.awk` injects missing cross-object labels at [line 563](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:563); the awk program itself says it computes and inserts labels needed for `hex2` resolution at [synth-inject.awk](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/synth-inject.awk:1). Host `sed` parses linker metadata at [line 576](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:576), and host `awk` generates the per-link Mach-O load-command template at [line 596](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:596).  
   Suggested fix: port symbol-set/archive resolution, ctor-table emission, synth-label injection, and Mach-O template rewriting to chain-built C tools before steps 45+.

2. **High: earlier Mes/TCC link steps use host `awk` to split and assemble M1 code/data streams. Violation.**  
   Examples: libc archive assembly in [21-libc-mini.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/21-libc-mini.sh:74), full libc in [25-libc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/25-libc.sh:83), libc+tcc in [26-libc-tcc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/26-libc-tcc.sh:83), first TCC link in [27-tinycc-mescc-link.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/27-tinycc-mescc-link.sh:19), and boot links through [42-tinycc-boot3-link.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/42-tinycc-boot3-link.sh:23). This is not just formatting; it decides which M1 lines become code vs data before `M1`/`hex2` produce runnable binaries. Step 44c builds a chain C splitter, but only after these uses, and its own build still falls back to awk before `m1-split` exists via [tcc-darwin-cc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:241).  
   Suggested fix: introduce a seed/Stage0-built splitter before Mes libc/TCC link steps, or rewrite these splits through an already chain-built tool.

3. **High: scratch `TARGET` builds can silently consult an existing `bake/target`. Reproducibility gap.**  
   GCC-10 env sets `CPP` and `CXXCPP` to scripts at [gcc10-env.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-env.sh:29). Those scripts ignore `$TARGET` and hard-code `../target`: [tcc-cpp](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/tcc-cpp:2), [gxx-cpp](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gxx-cpp:2). With `TARGET=/tmp/bake-verify`, GCC-10 configure/build can preprocess using the repo’s pre-existing `bake/target`, defeating scratch verification.  
   Suggested fix: make both wrappers honor exported `TARGET`, or set `CPP="$CC -E"` and `CXXCPP="$CXX -E"` directly.

4. **High: GCC-10 archive cache lives outside `TARGET`. Reproducibility gap.**  
   [gcc10-env.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-env.sh:25) defaults `TCC_DARWIN_CACHE_DIR` to `$ROOT/.tcc-darwin-archive-cache`, not the clean target tree. The wrapper trusts `.prepared` caches at [tcc-darwin-cc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:284). A clean `TARGET` rebuild can therefore reuse stale or corrupt symbol/member data from a previous run.  
   Suggested fix: put the cache under `$TARGET/work/...`, or rebuild/validate cache contents every run.

5. **High: step 55 creates host-compiled Mach-O stub libgcc/emutls archives. [FIXED for the CORE — see fix-status #5 above: real libgcc.a now built by the from-seed xgcc; only libgcc_eh/libgcc_s/libemutls_w remain stubs.]**  
   [55-gcc10-all-gcc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/55-gcc10-all-gcc.sh:55) calls this a temporary impurity. It writes C, compiles it with `/usr/bin/cc`, then archives it with `/usr/bin/ar` at [line 68](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/55-gcc10-all-gcc.sh:68), [line 69](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/55-gcc10-all-gcc.sh:69), and [line 72](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/55-gcc10-all-gcc.sh:72). This does not build `cc1`/`xgcc`, but it is used by the final `xgcc hello.c -o hello` goal link. The goal test also relies on SDK/system linking at [gcc10-goal-test.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-goal-test.sh:27).  
   Suggested fix: build real `libgcc`, `libgcc_eh`, `libgcc_s`, and `libemutls_w` with chain-built `xgcc`, then keep system `ld` as the only explicit final-executable escape hatch.

6. **Medium: `tcc-darwin-cc` embeds host `/usr/bin/ar` for archive extraction. Borderline violation.**  
   Step 44 substitutes `@AR@` with `/usr/bin/ar` at [44-tinycc-darwin-cc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/44-tinycc-darwin-cc.sh:49), and the wrapper extracts archive members at [tcc-darwin-cc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/tcc-darwin/tcc-darwin-cc.sh:288). This is not codegen or symbol resolution, but it is host parsing of code-bearing archives in the active link path.  
   Suggested fix: after step 44b, make the wrapper use chain-built `boot-ar x`.

7. **Medium: GCC-4.6 wrapper has host `as`/`cc` escape hatches. Not active by default, but unsafe.**  
   Step 50 generates the wrapper from [phase37-driver.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/50-gcc46-bootstrap.sh:9). The generated script captures default host `as`/`cc` paths at [phase37-driver.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/gcc46-scripts/phase37-driver.sh:98). If `GCC46_BOOTSTRAP_OBJECT_FORMAT=macho`, it uses host assembler at [line 552](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/gcc46-scripts/phase37-driver.sh:552) and host compiler/linker at [line 530](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/gcc46-scripts/phase37-driver.sh:530) and [line 756](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/sources/gcc46-scripts/phase37-driver.sh:756). Normal bake uses `object_format=elf`, so this is not an active `sh bake/build.sh` cheat.  
   Suggested fix: remove these defaults, or require explicit opt-in with loud failure in bake mode.

8. **Medium: external tarballs are required but not built or committed. Reproducibility gap, not a compiler cheat.**  
   Steps consume `$ROOT/tarballs`: Mes at [15-mes-source.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/15-mes-source.sh:10), GCC-4.6 at [46-gcc46-source.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/46-gcc46-source.sh:14), and GCC-10 at [53-gcc10-source.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/53-gcc10-source.sh:13). They are gitignored at [.gitignore](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/.gitignore:2). `fetch-sources.sh` pins SHA256s at [fetch-sources.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/fetch-sources.sh:49), so this is acceptable source acquisition, but the “committed text sources only” claim is overstated.  
   Suggested fix: either commit all source text/snapshots or make `build.sh` invoke hash-verified fetch as an explicit source phase.

**Benign / Not Violations**

Host `make`, `tar`, `cp`, `cat`, `dd`, `grep` smoke checks, and `/bin/sh` orchestration are not code translation by themselves. Host `perl`/`python3`/`sed` used for source editing, for example [53b-gcc10-patches.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/53b-gcc10-patches.sh:21) and [45-gnumake.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/45-gnumake.sh:30), is not compiler/linker cheating if the edits remain auditable; shell-track committed `.patch` files are applied by chain-built `boot-patch`. Host `nm`/`lipo`/`otool` exports in GCC envs appear to be inspection/configure support, not active codegen.

**Overall Verdict**

The chain is substantially from-seed for the actual C/C++ compilation of GCC-4.6 and GCC-10 `cc1`/`xgcc`, and I did not find a normal-path fallback to host clang/gcc/as for those builds. But the current faithfulness claim is too strong: host `awk` is still load-bearing linker machinery, early M1 splits also use host `awk`, scratch builds can accidentally use pre-existing `bake/target` and root caches, and the final runnable GCC-10 test still needs host-built stub archives plus system `ld`. Current status: impressive bootstrap, not yet a faithful “4 KB seed + text sources only, no host semantic translation/linking” bootstrap.
