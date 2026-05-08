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
- [ ] Bootstrap TCC from Darwin MesCC/M2 outputs.
  - [x] Identify the smallest bootstrappable TCC fork inputs.
    - Nixpkgs uses Jan Nieuwenhuizen's `tinycc` fork at `ea3900f6d5e71776c5cfabcabee317652e3a19ee` for the MesCC-oriented TCC seed.
  - [x] Verify that the fork is not directly M2-Planet-compilable.
    - `M2-Planet` stops immediately in `tcc.c` on non-M2 C constructs, before code generation.
  - [x] Vendor the bootstrappable TinyCC fork in `vendor/tinycc-bootstrappable`.
  - [x] Add a reproducible M2-Planet probe for the vendored fork.
    - Current probe reaches deep into `tccpp.c`; the remaining blocker is switch/label syntax still outside M2-Planet's accepted subset.
  - [ ] Add a Darwin Mes compiler path or another C99-capable pre-TCC compiler.
  - [ ] Port the TCC backend/runtime from ELF/Linux assumptions to signed Mach-O/Darwin.
  - Build and run a signed Mach-O TCC that compiles a hello-world Mach-O.

## aarch64 follow-up

- [ ] Revisit aarch64 after the amd64 Darwin chain is stable.
  - Replace the low-address ELF-era writable data assumptions.
  - Use high-base Mach-O templates and Darwin `LC_MAIN` argv throughout.
