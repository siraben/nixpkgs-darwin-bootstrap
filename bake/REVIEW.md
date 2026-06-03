# bake bootstrap — faithfulness review (automated)

Generated 2026-06-02 by `codex exec review` (gpt-5.5, read-only) against the
bake/ no-Nix chain. Captures where the bootstrap still relies on host tooling
or hand-run steps. Tracked here so the cleanup work is auditable; see the
task list and project memory for status on each item.

Reviewed read-only. The biggest issue is not host clang/gcc in the committed `bake/build.sh` path, but host scripting tools acting as real link/translation machinery.

**Critical Findings**

1. **Host `awk` is part of the active linker path. Severity: Critical.**  
   The active `tcc-darwin-cc` source is symlinked to [scripts/tinycc/tcc-darwin-cc-bash3.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/scripts/tinycc/tcc-darwin-cc-bash3.sh:246). It uses host `awk` to compute symbol sets, select archive members, split M1 code/data streams, build C++ constructor tables, inject synthetic labels, and generate per-link Mach-O templates: lines 246-247, 301-302, 321-322, 503-518, 527-528, 541-542, 573-584. This is semantically significant code production, not glue. Step 44 installs this wrapper into the chain via [bake/steps/44-tinycc-darwin-cc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/44-tinycc-darwin-cc.sh:37) and placeholder substitution at lines 45-61, then GNU Make/GCC builds use it. This is the main “bootstrap cheats here” finding.

2. **Host Python implements the archive tool used for GCC objects. Severity: High.**  
   [bake/scripts/bake-ar](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/bake-ar:5) execs `/usr/bin/python3`; [bake/scripts/bake-ar.py](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/bake-ar.py:46) writes object-bearing archives and [bake/scripts/bake-ranlib](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/bake-ranlib:1) is a no-op. This is used by GCC builds at [bake/steps/48-gcc46-all-gcc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/48-gcc46-all-gcc.sh:36), [bake/steps/49-gcc46-libgcc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/49-gcc46-libgcc.sh:15), and [bake/steps/51-gcc46-cxx-all-gcc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/51-gcc46-cxx-all-gcc.sh:34). It is not compiling C, but it is producing code-carrying artifacts in the chain.

3. **GCC-10 success is not captured in committed ordered steps. Severity: Critical reproducibility gap.**  
   [bake/build.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/build.sh:47) only runs `bake/steps/*.sh`. Committed tracked steps stop at `53b-gcc10-patches.sh`; step 53 only stages tarballs [bake/steps/53-gcc10-source.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/53-gcc10-source.sh:13), and 53b only patches source [bake/steps/53b-gcc10-patches.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/53b-gcc10-patches.sh:21). The actual build is in helper scripts: [bake/scripts/gcc10-resume-make.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-resume-make.sh:90), [bake/scripts/gcc10-link-cc1.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-link-cc1.sh:28), and [bake/scripts/gcc10-relink-xgcc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-relink-xgcc.sh:34). There is an untracked `bake/steps/54-gcc10-configure.sh`, but it only configures and is not committed.

4. **GCC-10 runtime/link proof depends on manual host SDK and empty stubs. Severity: High.**  
   `STATUS.md` says validation requires `SDKROOT=$(xcrun --show-sdk-path)` at [bake/STATUS.md](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/STATUS.md:28), and empty `lib{gcc,gcc_eh,gcc_s,emutls_w}.a` stubs at [bake/STATUS.md](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/STATUS.md:75). I found no ordered step creating those stubs or building real target libgcc. That makes the claimed `xgcc hello.c` result manual and impure.

**High / Medium Findings**

5. **Host Perl/Python source patching is pervasive. Severity: Medium to High.**  
   Mes patching uses host Perl in [bake/scripts/phase13-patch-assert-fail.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/phase13-patch-assert-fail.sh:11). GNU Make source surgery uses host Perl in [bake/steps/45-gnumake.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/45-gnumake.sh:30) and [scripts/gnumake/phase39-patch-job.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/scripts/gnumake/phase39-patch-job.sh:9). GCC-10 source patching uses host Python at [bake/steps/53b-gcc10-patches.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/53b-gcc10-patches.sh:21). These are codified, but they are still semantic source transformations by host interpreters.

6. **External tarballs are an additional trust anchor. Severity: Medium.**  
   [bake/scripts/fetch-sources.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/fetch-sources.sh:33) downloads Mes, NYACC, Make, GCC, GMP/MPFR/MPC/ISL with SHA checks. SHA-pinned source tarballs are defensible, but they contradict a strict “only committed seed + auditable text sources” reading unless tarballs are committed or mirrored. Build steps require them, e.g. [bake/steps/46-gcc46-source.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/46-gcc46-source.sh:14) and [bake/steps/53-gcc10-source.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/53-gcc10-source.sh:15).

7. **Dormant host compiler escape hatches exist. Severity: High if enabled.**  
   [scripts/gcc46/phase37-driver.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/scripts/gcc46/phase37-driver.sh:98) defaults host `as/cc` paths and can compile with host cc when env switches are set at lines 442-536; Mach-O object mode uses host `as` at lines 547-552 and host cc link mode at lines 706-709. Not active in normal bake env, but it should be quarantined or loudly refused.

**Correctness / Faithfulness Workarounds**

8. **GNU Make is heavily behavior-patched. Severity: Medium.**  
   [bake/steps/45-gnumake.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/45-gnumake.sh:36) removes include/lib search paths, disables signal/core/loadavg behavior, replaces `getcwd` with `"."`, skips makefile remaking, maps `alloca=malloc`, and injects many `HAVE_*` defines at lines 36-109. Some are bootstrap impurities, but this Make is not normal GNU Make.

9. **GCC-10 source patches change compiler behavior. Severity: Medium.**  
   [bake/steps/53b-gcc10-patches.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/steps/53b-gcc10-patches.sh:45) forces `__FUNCTION__/__func__`, and lines 65-77 shrink/disable PCH alignment assertions. The comments justify them, but they are compiler-source changes.

10. **Silent/fragile failure modes. Severity: Medium.**  
   `tcc-darwin-cc-bash3.sh` skips missing `-l` libraries with only a warning [scripts/tinycc/tcc-darwin-cc-bash3.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/scripts/tinycc/tcc-darwin-cc-bash3.sh:225), ignores synth-inject failure by simply not moving the output at lines 541-543, and can hang forever on stale lock dirs at lines 151-168 and 271-288. GCC-10 helper scripts call plain `make`, not `$TARGET/bin/make`, at [bake/scripts/gcc10-resume-make.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-resume-make.sh:90) and [bake/scripts/gcc10-relink-xgcc.sh](/Users/siraben/Git/nixpkgs-darwin-bootstrap/bake/scripts/gcc10-relink-xgcc.sh:34), so their result depends on caller PATH.

Bottom line: the early seed-to-tcc story is mostly explicit, but the current GCC path still cheats via host `awk`/Python link tooling, and GCC-10 is not yet a committed, ordered, reproducible bake milestone.