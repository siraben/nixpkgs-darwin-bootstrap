## macho-patcher — seed-built generic Darwin Mach-O segment patcher.
##
## The old chain ran M1 (amd64_defs.M1 + tools/macho-patcher.M1) -> hex2
## (MACHO-amd64.hex2 template, base 0x1000000) -> dd pad to 0x2800000.
## macho-patcher is unsigned, so the produced binary is exactly the
## 0x2800000 bytes.  Capture those bytes as a single .hex0 source and let
## hex0-raw re-emit them: byte-identical output, no stdenv in the trust
## path.
##
## Source regenerator (when tools/macho-patcher.M1 or the MACHO template
## changes): scripts/stage0/regen-macho-patcher-seed.sh.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  macho-patcher-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "macho-patcher-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/macho-patcher/macho-patcher_AMD64_darwin_final.hex0")
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
  pname = "macho-patcher";
  version = "0-unstable-2026-06-20";

  buildPhase = ''
    runHook preBuild
    install -m755 ${macho-patcher-raw} macho-patcher
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 macho-patcher $out/bin/macho-patcher
    install -Dm644 ${root + "/hex0/sources/macho-patcher/macho-patcher_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/macho-patcher_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit macho-patcher-raw; };

  meta = {
    description = "Seed-built generic Darwin Mach-O segment patcher (no stdenv in trust path)";
  };
}
