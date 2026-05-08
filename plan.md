# Darwin Bootstrap Plan

## Current runnable chain

- [x] Standalone `nixpkgs-darwin-bootstrap` repo with flake outputs.
- [x] amd64 Darwin `hex1` from stage0 `AMD64/hex1_AMD64.hex0`.
- [x] amd64 Darwin `hex2-0` from stage0 `AMD64/hex2_AMD64.hex1`.
- [x] amd64 Darwin `catm` from stage0 `AMD64/catm_AMD64.hex2`.
- [x] amd64 Darwin `M0` from stage0 `AMD64/M0_AMD64.hex2`.
- [x] amd64 Darwin `cc_arch` assembles and signs as a Mach-O candidate.

## Immediate blocker

- [x] Fix `M0-darwin` output fidelity for strings and raw string tokens.
- [x] Fix `cc_arch-darwin` runtime fidelity for M2-Planet input.
  - Static cc_arch data is copied into `__DATA` and RIP-relative references are redirected there.
  - cc_arch heap allocation starts after the copied static region instead of overwriting it.
  - The concatenated Darwin `M2-0.c` compiles to `M2-0.M1`.

## Next chain tasks

- [x] Package amd64 Darwin `cc_arch`.
  - Build `cc_arch-0.hex2` with `M0-darwin`.
  - Concatenate Mach-O low-data header and `cc_arch-0.hex2` with `catm-darwin`.
  - Assemble with `hex2-darwin`, pad to `__LINKEDIT`, sign, and smoke-test.
- [x] Package amd64 Darwin `M2` candidate.
  - Concatenate Darwin M2libc bootstrap C and M2-Planet C sources with `catm-darwin`.
  - Compile to M1 with `cc_arch-darwin`.
  - Prefix Darwin M2libc defs/core, assemble with `M0-darwin`, link with `hex2-darwin`, relocate static data into `__DATA`, sign, and smoke-test startup.
- [x] Fix `M2-darwin` option/file runtime.
  - Preserve Darwin `envp` in the startup frame so generated `main` locals land at the offsets M2 expects.
  - Encode `FILE*` descriptors as `fd + 1` so fd 0 is not confused with `NULL`.
  - `M2-darwin --help` and `M2-darwin -f trivial.c -o trivial.M1` now work.
- [x] Build MesCC tools under the Darwin chain.
  - [x] Build `blood-macho-0` from `M2-darwin` and smoke-test footer generation.
  - [x] Build `M1-0` from `M2-darwin` and smoke-test M1 to hex2 conversion.
  - [x] Add amd64 Darwin full M2libc syscall/core layer for MesCC tools.
  - [x] Build `hex2-1` from `M2-darwin` and `M1-0`.
  - [x] Build full `M1` from `M2-darwin`, `M1-0`, and `hex2-1`.
  - [x] Build full `hex2` from `M2-darwin`, full `M1`, and `hex2-1`.
  - [x] Build `kaem` from `M2-darwin`, full `M1`, and full `hex2`.
  - [x] Build full `M2-Planet` from the Darwin MesCC toolchain.
- [ ] Bootstrap GNU Mes Scheme from Darwin MesCC/M2 outputs.
  - [x] Confirm the required ordering from Nixpkgs minimal-bootstrap.
    - Linux minimal-bootstrap builds `mes-m2`, Mes libraries, and the Mes Scheme interpreter before TinyCC.
    - TinyCC is compiled by MesCC through `mes --no-auto-compile -e main mescc.scm --`, not directly by M2-Planet.
  - [ ] Add a Darwin Mes source-prep phase.
    - [x] Start from GNU Mes `0.27.1`, matching Nixpkgs minimal-bootstrap.
    - [x] Generate `include/mes/config.h` for amd64 Darwin sizes and Mes version.
    - Replace Linux include/module assumptions with Darwin paths before running Mes kaem scripts.
  - [ ] Port Mes libc and MesCC support to Darwin.
    - Add Darwin syscall numbers, `crt1`, `setjmp`/`longjmp`, `kernel-stat`, signal, and file API shims needed by Mes.
    - Produce Darwin `libc-mini`, `libmescc`, `libc`, and `libc+tcc` archives from the existing signed `M1`/`hex2` chain.
    - [x] Build `libc-mini.M1` with Darwin MesCC syscall shims and run a signed `puts` smoke binary.
    - [x] Build `libmescc.M1` with Darwin `syscall-internal.c` and verify `__raise` resolves.
      - [x] Add and pass `phase20-mescc-libmescc-probe`.
    - [x] Build broad `libc.M1` by replacing Linux syscall translation units with Darwin shims.
      - [x] Add and pass `phase21-mescc-libc-probe`.
    - [x] Build `libc+tcc.M1` and add/stub the extra file APIs needed by bootstrappable TCC.
      - [x] Add and pass `phase22-mescc-libc-tcc-probe`.
    - [ ] Re-link Mes itself as a signed Mach-O using MesCC-generated Mes objects plus Darwin libc.
  - [ ] Build and sign `mes-m2`.
    - [x] Probe the Mes bootstrap script through its initial `M2-Planet` compile to `mes.M1`.
    - [x] Probe the post-M2 Mach-O link path through Darwin `M1` and `hex2`.
      - The signed Mach-O `mes-m2` now boots Mes Scheme with `MES_PREFIX`/`GUILE_LOAD_PATH` and evaluates a smoke-test expression.
    - [x] Package `mes-m2` with a substituted Darwin `mescc.scm` and NYACC load path.
      - `mes-m2` now drives `mescc.scm -S` far enough to compile a trivial C translation unit to M1.
    - [x] Link and run a signed Mach-O from MesCC-generated M1.
      - A MesCC-compiled trivial C `main` links with a Darwin MesCC `crt1.M1`, signs, and exits cleanly.
    - Run the Mes bootstrap kaem script through `phase11-kaem`.
    - Link with the Mach-O template, pad `__LINKEDIT`, sign, and smoke-test `mes-m2 --version`.
  - [ ] Rebuild full Mes Scheme on Darwin.
    - Compile Mes sources using `mes-m2` plus Darwin Mes libraries.
    - Install `mes`, `mescc.scm`, Mes modules, headers, and libraries as a Darwin bootstrap output.
    - Smoke-test `mes --version` and a tiny `mescc.scm -S` compile.
- [ ] Bootstrap TCC from Darwin Mes Scheme/MesCC outputs.
  - [x] Identify the smallest bootstrappable TCC fork inputs.
    - Nixpkgs uses Jan Nieuwenhuizen's `tinycc` fork at `ea3900f6d5e71776c5cfabcabee317652e3a19ee` for the MesCC-oriented TCC seed.
  - [x] Verify that the fork is not directly M2-Planet-compilable.
    - The probe is a negative check only: M2-Planet reaches non-M2 C constructs in the vendored fork before code generation.
  - [x] Vendor the bootstrappable TinyCC fork in `vendor/tinycc-bootstrappable`.
  - [x] Add a reproducible M2-Planet probe for the vendored fork.
    - Current pristine-fork probe reaches `elf.h:88`; the failure confirms this is not a direct M2-Planet input.
  - [x] Compile `tinycc-boot-mes` with Darwin MesCC.
    - Use Mes `libc+tcc`, Darwin include paths, and `CONFIG_TCCBOOT`/`TCC_MES_LIBC`.
    - Replace Linux ELF interpreter/library paths with Darwin Mach-O/linker settings.
    - Link, pad, sign, and smoke-test `tcc -version`.
    - [x] First emit `tinycc-boot-mes.M1` with `mes-m2 --no-auto-compile -e main mescc.scm -- -S`.
      - [x] Add and pass `phase19-tinycc-mescc-m1-probe` using a derived MesCC-patched TinyCC source.
      - [x] Increase the Darwin Mes heap and run MesCC with the same large stack/arena sizing used by the MesCC wrapper path.
      - [x] Rewrite Mes' M2-built assertion reporter to avoid eager `&&` dereferences so bootstrap failures print useful diagnostics.
      - [ ] Investigate remaining MesCC type warnings emitted while producing `tcc.M1`.
    - [x] Link `tinycc-boot-mes.M1` with Darwin `libc+tcc.M1` into a signed Mach-O.
      - [x] Build a Darwin `libmescc.M1` archive checkpoint.
      - [x] Build a broad Darwin `libc.M1` archive checkpoint.
        - [x] Add and pass `phase21-mescc-libc-probe`.
      - [x] Build a Darwin `libc+tcc.M1` archive checkpoint.
        - [x] Add and pass `phase22-mescc-libc-tcc-probe`.
      - [x] Add `phase23-tinycc-mescc-link-probe` to link, pad, sign, and run `tcc -version`.
      - [x] Preserve Darwin `argc`/`argv`/`envp` on the MesCC stack frame through `crt1-libc.M1`.
      - [x] Patch phase5 static-data relocation for RIP-relative `%rdi`/`%rsi` forms used by TinyCC globals.
      - [x] Remove the temporary early `tcc.c` version-return shortcut; `tcc -version` now runs through `tcc_new` and argument parsing.
    - [x] Patch or gate TinyCC's ELF-only paths until `tcc -version` runs before enabling self-hosting.
  - [ ] Run TinyCC self-advance stages.
    - [x] Add a `phase24` smoke stage that exercises real preprocessing and object generation.
      - MesCC-built TinyCC now preprocesses a C file and emits an x86_64 ELF relocatable object.
    - [x] Debug TinyCC self-compilation with Mes includes before enabling boot0.
      - Avoid the copied-`__DATA` function-pointer trap by replacing switch-case `qsort` with a direct insertion sort in the TinyCC Mes patch.
      - Add `phase25-tinycc-self-object-probe` to compile TinyCC itself to an x86_64 ELF relocatable object.
    - [x] Add a narrow ELF relocatable to signed Mach-O checkpoint for TinyCC output.
      - `phase27-tinycc-elf-to-macho-probe` compiles a C object with the MesCC-built TinyCC, converts the ELF relocatable to M1, links a signed Mach-O, and verifies exit status 42.
    - [x] Convert the full self-compiled TinyCC ELF relocatable to M1.
      - `phase28-tinycc-self-m1-probe` translates `tcc.o` into M1/hex2 while preserving unresolved SysV libc references for the next link stage.
    - [x] Prove multi-object SysV ABI linking for TinyCC output.
      - `phase29-tinycc-sysv-libc-probe` compiles both a caller and a seed `strlen` implementation with bootstrapped TinyCC, converts both ELF relocatables to M1, links a signed Mach-O, and verifies exit status 9.
    - [x] Link the self-compiled TinyCC object with a seed SysV Darwin libc candidate.
      - `phase30-tinycc-self-link-candidate` produces a signed `tcc-self-candidate`; source-guided data relocation and SysV stack alignment make `tcc-self-candidate -version` run successfully.
    - [x] Prove the self-host candidate can compile and link a C smoke object.
      - `phase31-tinycc-self-compile-probe` compiles `hello.c` with `tcc-self-candidate`, converts the resulting ELF relocatable to M1, links a signed Mach-O, and verifies exit status 42.
    - [x] Compile TinyCC again with the self-host candidate.
      - `phase32-tinycc-boot1-object-probe` uses `tcc-self-candidate` to compile the patched TinyCC source into a new x86_64 ELF relocatable `tcc-boot1.o`.
    - [x] Link a TinyCC boot1 binary candidate.
      - `phase33-tinycc-boot1-link-candidate` links `tcc-boot1.o` into a signed Mach-O; the candidate runs but does not yet pass `-version`, so `phase30` remains the current usable self-hosted TinyCC.
    - [x] Add a TinyCC-backed Darwin `cc` wrapper.
      - `phase34-tinycc-darwin-cc` wraps `tcc-self-candidate`, the ELF-to-M1 bridge, the seed SysV libc, and Mach-O signing to build runnable Darwin executables from simple C inputs.
      - The wrapper now supports `-E`, materializes quote-include headers for GCC-style build directories, and carries a minimal bootstrap header set.
    - [ ] Add the ELF/Mach-O link boundary needed to turn the self-compiled TinyCC object into a runnable compiler.
    - Build `tinycc-boot0`, `tinycc-boot1`, `tinycc-boot2`, `tinycc-boot3`, and final `tinycc-bootstrappable`.
    - Rebuild `libtcc1.a` at each required feature level.
  - [ ] Port TinyCC output to signed Mach-O/Darwin.
    - Replace ELF object/executable emission and Linux runtime assumptions.
    - Build and run a signed Mach-O TCC that compiles a hello-world Mach-O.
- [ ] Bootstrap toward GCC 4.6 on Darwin.
  - [ ] Establish the TCC-hosted C toolchain boundary: preprocessor, assembler input, object output, and runnable host tools.
  - [x] Add a `phase26-gcc46-source` source checkpoint with GCC 4.6.4 plus GMP 4.3.2, MPFR 2.4.2, and MPC 0.8.1.
  - [x] Add a patched GCC 4.6 Darwin bootstrap source.
    - `gcc46-darwin-bootstrap-src` applies `patches/gcc46-darwin-bootstrap.patch`, currently stubbing libiberty regex and legacy C++ demangling paths that the MesCC-built TinyCC cannot compile yet.
  - [ ] Advance `make all-gcc` past libiberty.
    - Current boundary: GCC and libiberty configure succeed for `x86_64-apple-darwin`; libiberty now compiles through `lrealpath.c` and stops while compiling `make-relative-prefix.c`.
  - [ ] Add bootstrap prerequisites in order: binutils/cctools-equivalent assembler+linker path, make/shell assumptions, GMP/MPFR/MPC as required.
  - [ ] Build GCC 4.6 stage1 with the bootstrapped C compiler, then iterate to a self-hosted stage2/stage3.
  - [ ] Keep each successful boundary as a Nix phase and a git checkpoint.

## aarch64 follow-up

- [ ] Revisit aarch64 after the amd64 Darwin chain is stable.
  - Replace the low-address ELF-era writable data assumptions.
  - Use high-base Mach-O templates and Darwin `LC_MAIN` argv throughout.

## Running log

- 2026-05-08: Switched `plan.md` progress tracking to append-only log entries; keep the checklist as a roadmap and record each new bootstrap boundary here instead of rewriting prior TODO text.
- 2026-05-08: Added proper GCC 4.6 bootstrap patch hunks for libiberty `fnmatch.c`, `getopt.c`, `hex.c`, and `make-relative-prefix.c`; latest run reached GCC subconfigure after passing the prior libiberty compile boundary.
- 2026-05-08: Validated the `make-relative-prefix.c` bootstrap stub in `make all-gcc`; libiberty now compiles through `make-relative-prefix.c` and stops while compiling `make-temp-file.c`.
