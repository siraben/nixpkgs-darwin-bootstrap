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

Build/check examples:

```sh
nix build .#hex0
nix build .#checks.aarch64-darwin.macho-template-hello-runs
nix flake check
```

The next hard porting item is phase 1: upstream `hex1_AArch64.hex0` assumes the
ELF bootstrap image/data model with writable storage around `0x600000`. Darwin
Mach-O execution and arm64 signing require a different mapped/writable data plan
before `hex1 -> hex2 -> catm -> M0 -> cc_arch -> M2-Planet -> MesCC -> TCC` can
advance honestly.
