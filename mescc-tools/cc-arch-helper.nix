## cc-arch-helper — seed-built Darwin Mach-O phase-4 cc-arch port+patch helper.
##
## The old chain ran M2-Planet (bootstrap/phase4-amd64-cc-arch.c) -> M1 -> hex2
## (MACHO-amd64-lowdata.hex2 template, base 0x600000) -> macho-patcher
## m2-segments -> dd pad to 0x2800000 -> ad-hoc codesign.  The helper is
## signed, so the final binary exceeds 0x2800000 by its codesign trailer.
## Capture the full signed binary as a single .hex0 source and let hex0-raw
## re-emit it: byte-identical output, no stdenv in the trust path.  The binary
## is installed under its historical name phase4-cc-arch-helper.
##
## Source regenerator (when bootstrap/phase4-amd64-cc-arch.c or the MACHO
## template changes): scripts/stage0/regen-cc-arch-helper-seed.sh.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  cc-arch-helper-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "cc-arch-helper-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/cc-arch-helper/cc-arch-helper_AMD64_darwin_final.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-XFdOfST+oUfFwSo9i4mb30D85zAFQH/t1tMs0kO4qgo=";
      }
    else
      null;
in

mkDarwin {
  pname = "cc-arch-helper";
  version = "0-unstable-2026-06-20";

  buildPhase = ''
    runHook preBuild
    install -m755 ${cc-arch-helper-raw} phase4-cc-arch-helper
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 phase4-cc-arch-helper $out/bin/phase4-cc-arch-helper
    install -Dm644 ${root + "/hex0/sources/cc-arch-helper/cc-arch-helper_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/cc-arch-helper_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit cc-arch-helper-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O phase-4 cc-arch port+patch helper (no stdenv in trust path)";
  };
}
