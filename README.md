# nixpkgs-darwin-bootstrap

Standalone Darwin minimal-bootstrap experiments for reproducing the Linux
`minimal-bootstrap` stage0/M2-Planet/MesCC path as a Darwin Mach-O chain.

The current implementation has:

- Darwin raw-syscall smoke binaries for `aarch64-darwin` and `x86_64-darwin`.
- A C-built `hex0` seed for local experimentation while handwritten Mach-O seed bytes are being ported.
- Darwin M2libc syscall/startup snippets for aarch64 and amd64.
- Dynamic Mach-O `hex2` executable templates with `LC_MAIN`, `/usr/lib/dyld`, and `/usr/lib/libSystem.B.dylib`.
- An explicit signing bridge that uses nixpkgs `darwin.signingUtils` (`sigtool` plus `codesign_allocate`) to ad-hoc sign generated executables.
- A Darwin copy of the mescc-tools boot phase graph, kept structurally aligned with the Linux chain.
- A signed aarch64 phase-1 `hex1` candidate generated from upstream `AArch64/hex1_AArch64.hex0` with Mach-O, Darwin syscall, `LC_MAIN` argv, and anonymous mmap scratch-space adaptations.

Build/check examples:

```sh
nix build .#hex0
nix build .#phase1-hex1
nix build .#checks.aarch64-darwin.macho-template-hello-runs
nix flake check
```

The current phase-1 `hex1` candidate builds and signs, but is not yet promoted
to the trusted chain: upstream `hex1_AArch64.hex0` still embeds the ELF-era
single-image writable data assumptions too deeply. That data model must be
fully replaced before `hex1 -> hex2 -> catm -> M0 -> cc_arch -> M2-Planet ->
MesCC -> TCC` can advance honestly.
