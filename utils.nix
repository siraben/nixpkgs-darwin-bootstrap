## Shared helpers for the Darwin minimal-bootstrap derivations.  See
## packages.nix for the orchestrator that injects these into every
## phase via the `phaseContext // phaseDefs` attrset.

{ stdenv, lib }:
rec {
  ## mkDarwin: wrapper around stdenv.mkDerivation that bakes in the
  ## conventions shared by every Darwin bootstrap derivation:
  ##   - version pinned to the repo-wide bootstrap snapshot (override
  ##     by passing `version = ...;` explicitly)
  ##   - dontUnpack/dontStrip/strictDeps default to true (we never have
  ##     an src, never want stripping on signed binaries, and want the
  ##     bootstrap to fail loudly on missing inputs rather than fall
  ##     back to leaked host tools)
  ##   - meta.platforms defaults to x86_64-darwin (only stage0-posix/
  ##     hex1.nix's aarch64 candidate overrides)
  ##
  ## Callers pass any other stdenv.mkDerivation attrs through; this
  ## just supplies sensible defaults.  Equivalent to nixpkgs's per-
  ## stdenv-variant helpers (e.g. `mkBootstrapDerivation`).
  mkDarwin =
    attrs@{ pname, ... }:
    stdenv.mkDerivation (
      {
        version = "0-unstable-2026-05-07";
        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;
      }
      // attrs
      // {
        meta = (attrs.meta or { }) // {
          platforms = (attrs.meta or { }).platforms or [ "x86_64-darwin" ];
        };
      }
    );
}
