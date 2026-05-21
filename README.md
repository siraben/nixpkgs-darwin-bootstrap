# nixpkgs-darwin-bootstrap

Standalone Darwin minimal-bootstrap experiments for reproducing the Linux
`minimal-bootstrap` stage0/M2-Planet/MesCC path as a Darwin Mach-O chain.

## Current state

The active, runnable bootstrap path is `x86_64-darwin`/amd64. The Nixified
chain reaches a strict self-hosted modern GCC handoff whose GCC source version
is matched to nixpkgs `gcc_latest.version` (`15.2.0` with the current lock).

The implemented amd64 chain is:

1. Raw Darwin/Mach-O seeds: syscall hello probes, a hand-assembled `hex0`, Mach-O
   `hex2` templates using `LC_MAIN`, `/usr/lib/dyld`, and `libSystem`.
2. Stage0 tools: signed `hex1`, `hex2`, `catm`, `M0`, `cc_arch`, `M2`,
   `blood-macho`, `M1`, full `hex2`, `kaem`, and full `M2-Planet`.
3. Mes/TinyCC probes: Darwin MesCC library probes, TinyCC MesCC/M1/link probes,
   and `phase34-tinycc-darwin-cc` as the C compiler boundary for GCC work.
4. GCC 4.6: `phase35`/`phase36` build the C frontend and libgcc boundary;
   `phase44-gcc46-cxx-bootstrap` packages a GCC 4.6.4 C/C++ handoff with
   `libgcc`, `libstdc++`, Mach-O assembler/linker wrappers, and smoke tests.
5. Modern GCC: `phase45-gcc10-bootstrap` builds a compiler-only GCC 10.4.0
   handoff; `phase46-gcc-latest-bootstrap` builds the nixpkgs-matched
   `gcc_latest`; `phase47-gcc-latest-strict-bootstrap` rebuilds that same GCC
   with the wrapper host shortcuts disabled.
6. Package proof: GNU Hello 2.12.2 builds and runs with the phase46 handoff,
   the strict phase47 handoff, and a nixpkgs `gcc_latest` reference; the
   `gnu-hello-hash-comparison` output records the hashes and equality checks.

## Known impurity boundaries

- The Darwin executable path intentionally links against the platform
  `libSystem`/dyld ABI and ad-hoc signs generated Mach-O binaries through
  nixpkgs `darwin.signingUtils`.
- GCC phases still use the local Command Line Tools SDK at
  `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk` and Apple `/usr/bin`
  assembler/linker/compiler tools at selected bootstrap boundaries.
- Phase44, phase45, and phase46 use host compiler/linker shortcuts for bootstrap-host
  GCC sources, generated sources, support libraries, and configure probes.
  Phase47 is the stricter replay with `GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0`,
  but it is still a compiler-only handoff, not a complete Darwin `stdenv.cc`.
- `phase39-gnumake` exists and passes a recipe-execution smoke test, but the
  GCC and GNU Hello formalizations still use nixpkgs `gnumake`. A direct
  phase39 GNU Hello build currently segfaults while evaluating Automake's
  generated makefiles, so this is not yet a promoted bootstrap make boundary.
- The modern GCC packages carry a staged, patched bootstrap sysroot and wrapper
  metadata sufficient for the current proofs; they are not yet a full nixpkgs
  compiler/runtime/bintools closure.

## Key commands

On an `x86_64-darwin` builder:

```sh
nix build .#hex0
nix build .#phase12-m2-planet
nix build .#phase44-gcc46-cxx-bootstrap
nix build .#phase45-gcc10-bootstrap
nix build .#phase46-gcc-latest-bootstrap
nix build .#phase47-gcc-latest-strict-bootstrap
nix build .#gnu-hello-hash-comparison
nix flake check
```

From another Darwin host, select the amd64 package set explicitly when needed:

```sh
nix build .#packages.x86_64-darwin.phase47-gcc-latest-strict-bootstrap
nix build .#packages.x86_64-darwin.gnu-hello-hash-comparison
```

## aarch64 status

`aarch64-darwin` has raw syscall smoke coverage, Darwin M2libc checks, a
runnable Mach-O template hello check, and a signed phase-1 `hex1` candidate.
It is not promoted to the trusted bootstrap chain yet: the upstream
`AArch64/hex1_AArch64.hex0` path still needs its ELF-era writable-data model
reworked for high-base Mach-O/`LC_MAIN` Darwin execution.
