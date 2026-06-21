## hex2-data-relocs — seed-built Darwin Mach-O hex2 data-relocation patcher.
##
## The old chain ran M2-Planet (bootstrap/hex2-data-relocs.c) -> M1 -> hex2
## (MACHO-amd64-lowdata.hex2 template, base 0x600000) -> macho-patcher
## m2-segments -> dd pad to 0x2800000 -> ad-hoc codesign.  hex2-data-relocs is
## signed, so the final binary exceeds 0x2800000 by its codesign trailer.
## Capture the full signed binary as a single .hex0 source and let hex0-raw
## re-emit it: byte-identical output, no stdenv in the trust path.
##
## Source regenerator (when bootstrap/hex2-data-relocs.c or the MACHO template
## changes): scripts/stage0/regen-hex2-data-relocs-seed.sh.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  hex2-data-relocs-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "hex2-data-relocs-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/hex2-data-relocs/hex2-data-relocs_AMD64_darwin_final.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-W9rLcHYTcH4VTyX6JkmPt2xA9ohgyVXCRAjaSdAm/O8=";
      }
    else
      null;
in

mkDarwin {
  pname = "hex2-data-relocs";
  version = "0-unstable-2026-06-20";

  buildPhase = ''
    runHook preBuild
    install -m755 ${hex2-data-relocs-raw} hex2-data-relocs
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hex2-data-relocs $out/bin/hex2-data-relocs
    install -Dm644 ${root + "/hex0/sources/hex2-data-relocs/hex2-data-relocs_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/hex2-data-relocs_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit hex2-data-relocs-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O hex2-data-relocs patcher (no stdenv in trust path)";
  };
}
