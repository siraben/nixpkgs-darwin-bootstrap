## hex0 built from a tiny pre-committed Mach-O seed.
##
## This mirrors nixpkgs minimal-bootstrap's stage0-posix/hex0.nix: instead
## of using stdenv.mkDerivation + clang + bash, we use a 4 KB Mach-O
## hex0-seed binary as the *builder itself*.  Nix invokes it directly with
## the hex0 source path and $out; no stdenv, no bash, no clang.
##
## The output is a raw Mach-O file (not a directory).  Downstream phases
## that have used `${hex0}/bin/hex0` will need to learn to use `${hex0}`.
##
## Verified: the seed was produced by the current stdenv-based hex0 build,
## and (./hex0 hex0-amd64-darwin.hex0) == seed by construction (the chain
## already enforces `cmp hex0 hex0-self`).  outputHash pins the result.
{
  hostPlatform,
  root,
  ...
}:

let
  seed = root + "/hex0/seed/hex0-amd64-darwin";
  hex0Source = root + "/hex0/hex0-amd64-darwin.hex0";
in

if hostPlatform.isx86_64 then
  derivation {
    name = "hex0";
    system = "x86_64-darwin";
    builder = seed;
    args = [
      hex0Source
      (placeholder "out")
    ];

    ## Fixed-output: pins the hex0 bytes the chain trusts.  If the seed,
    ## source, or hex0 itself drift, this hash will need updating and the
    ## drift will be visible.  Until the first build computes the real
    ## hash, leave this on a fake value to force a recompute.
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-HPEKGGeQG+NhM+CL6HIOVSBnmb6oXbPEpOXo4ftqyGk=";
  }
else
  null
