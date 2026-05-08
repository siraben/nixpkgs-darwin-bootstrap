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
- [ ] Build MesCC tools under the Darwin chain.
  - Build `blood-macho-0` or port `blood-elf` output handling to Mach-O.
  - Build `M1-0`, `hex2-1`, full `M1`, full `hex2`, and `kaem`.
- [ ] Bootstrap TCC from Darwin MesCC/M2 outputs.
  - Identify the smallest bootstrappable TCC fork inputs.
  - Add Darwin M2libc/TCC syscall and linker assumptions.
  - Build and run a signed Mach-O TCC that compiles a hello-world Mach-O.

## aarch64 follow-up

- [ ] Revisit aarch64 after the amd64 Darwin chain is stable.
  - Replace the low-address ELF-era writable data assumptions.
  - Use high-base Mach-O templates and Darwin `LC_MAIN` argv throughout.
