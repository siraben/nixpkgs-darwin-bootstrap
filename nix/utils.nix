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
  ##     bootstrap to fail loudly on missing inputs — a silent fallback
  ##     to leaked host tools would go unnoticed)
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
        ## dontUnpack defaults to true (most stage0 derivations have no
        ## src — they cp from committed hex0/hex2 sources).  When a
        ## caller passes `src = ...;`, the default is false so stdenv's
        ## unpackPhase runs normally.
        dontUnpack = !(attrs ? src);
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
