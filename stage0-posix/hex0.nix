## hex0 — the Darwin-bootstrap seed assembler.
##
## The smallest tool in the chain.  Built by a 4 KB committed Mach-O
## seed (`hex0/seed/hex0-amd64-darwin`) acting as the Nix `builder`.  No
## stdenv, no clang, no bootstrap-tools is involved in producing the
## hex0 binary itself.
##
## The seed is verified self-hosting: feeding the seed back its own
## .hex0 source produces a byte-identical seed (outputHash pins this).
##
## We then wrap the raw-output hex0 derivation in a small stdenv layer
## that installs the binary at $out/bin/hex0 and ships the source
## under $out/share/darwin-bootstrap so existing downstream phases that
## use `${hex0}/bin/hex0` and `${hex0}/share/...` keep resolving.  The
## stdenv wrapper does NOT recompile hex0; it only copies bytes.
{
  hostPlatform,
  lib,
  root,
  stdenv,
  supportedSystems,
  tests,
}:

let
  ## Per-arch seed naming: the amd64 and aarch64 seeds live side by side
  ## in hex0/.  Each arch's src is filtered to its own files so adding
  ## one arch's seed leaves the other arch's derivation unchanged.
  seedArch = if hostPlatform.isx86_64 then "amd64" else "aarch64";
  otherArch = if hostPlatform.isx86_64 then "aarch64" else "amd64";

  ## --- raw seed-as-builder hex0 (no stdenv) ---
  hex0-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "hex0-raw";
        system = "x86_64-darwin";
        builder = root + "/hex0/seed/hex0-amd64-darwin";
        args = [
          (root + "/hex0/hex0-amd64-darwin.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-HPEKGGeQG+NhM+CL6HIOVSBnmb6oXbPEpOXo4ftqyGk=";
      }
    else if hostPlatform.isAarch64 then
      ## The aarch64 seed is 16 KB of Mach-O plus the mandatory ad-hoc
      ## code signature; its .hex0 source describes the signed binary
      ## byte-for-byte (the signature hashes only the pages before it).
      derivation {
        name = "hex0-raw";
        system = "aarch64-darwin";
        builder = root + "/hex0/seed/hex0-aarch64-darwin";
        args = [
          (root + "/hex0/hex0-aarch64-darwin.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-4aelXMpdU64C1SDqat3FdqJd27h8e1vI3xpHsYNxx44=";
      }
    else
      null;
in

stdenv.mkDerivation {
  pname = "hex0";
  version = "0-unstable-2026-05-27";

  src = builtins.path {
    path = ../hex0;
    name = "hex0";
    filter = path: type: !(lib.hasInfix otherArch (baseNameOf path));
  };
  strictDeps = true;
  dontStrip = true;

  buildPhase = ''
    runHook preBuild

    ## Take the seed-built hex0 verbatim (no compilation here).
    install -m755 ${hex0-raw} hex0
    ./hex0 hex0-${seedArch}-darwin.hex0 hex0-self
    cmp hex0 hex0-self

    cp ${root + "/stage0-posix/fixtures/hex0-smoke.hex0"} smoke.hex0
    ./hex0 smoke.hex0 smoke.out
    printf 'Hello\n' > smoke.expected
    cmp smoke.expected smoke.out
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hex0 $out/bin/hex0
    install -Dm644 hex0-${seedArch}-darwin.hex0 $out/share/darwin-bootstrap/hex0-${seedArch}-darwin.hex0
    install -Dm644 hex0-${seedArch}-darwin.S    $out/share/darwin-bootstrap/hex0-${seedArch}-darwin.S
    install -Dm644 README.md              $out/share/darwin-bootstrap/README.hex0.md
    runHook postInstall
  '';

  meta = {
    description = "Darwin hex0 assembler (seed-built, no clang in trust path)";
    teams = [ lib.teams.minimal-bootstrap ];
    platforms = supportedSystems;
  };

  passthru = {
    inherit hex0-raw;
    tests = {
      converts-hex = tests.hex0-converts-hex;
    };
  };
}
