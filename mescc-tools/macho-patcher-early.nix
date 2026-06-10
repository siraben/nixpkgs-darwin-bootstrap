## phase11e-macho-patcher-early — seed-built Darwin macho-patcher.
##
## The trust chain is:
##   1. hex0/sources/macho-patcher-early/macho-patcher_AMD64_darwin_combined.hex2
##      is the catm(MACHO-amd64.hex2-template, M0-output-of-catm(amd64_defs.M1,
##      amd64_byte_defs.M1, macho-patcher-m0.M1)) result, with linkedit-offset
##      (0x2800000) padding baked in.
##   2. The seed-built hex2 (phase2-hex2.hex2-raw) acts as
##      `derivation.builder` and produces the macho-patcher binary.
##
## To re-derive the seed from raw .M1 sources, run
## scripts/stage0/regen-macho-patcher-seed.sh — it runs catm+M0+catm
## through the existing stdenv chain and re-emits a byte-identical
## seed.  The chain is auditable; the seed is the *cached* result.
{
  hostPlatform,
  mkDarwin,
  hex2-0,
  root,
  ...
}:

let
  macho-patcher-early-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "phase11e-macho-patcher-early-raw";
        system = "x86_64-darwin";
        builder = hex2-0.hex2-raw;
        args = [
          (root + "/hex0/sources/macho-patcher-early/macho-patcher_AMD64_darwin_combined.hex2")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-zEc26zVuTOqImIwDeB7DcLwSVPd55KeqckLCPmP02Oo=";
      }
    else
      null;
in

mkDarwin {
  pname = "phase11e-macho-patcher-early";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild
    install -m755 ${macho-patcher-early-raw} macho-patcher
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 macho-patcher $out/bin/macho-patcher
    install -Dm644 ${root + "/hex0/sources/macho-patcher-early/macho-patcher_AMD64_darwin_combined.hex2"} \
      $out/share/darwin-bootstrap/macho-patcher_AMD64_darwin_combined.hex2
    runHook postInstall
  '';

  passthru = { inherit macho-patcher-early-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O macho-patcher (m2-segments mode), no stdenv in trust path";
  };
}
