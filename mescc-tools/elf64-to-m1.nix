## elf64-to-m1 — seed-built Darwin Mach-O ELF→M1 converter.
##
## The old chain ran M1 (amd64_defs.M1 + tools/elf64-to-m1.M1) -> hex2
## (MACHO-amd64.hex2 template, base 0x1000000) -> dd pad to 0x2800000.
## elf64-to-m1 is unsigned (no codesign step), so the produced binary is
## exactly the 0x2800000 bytes.  Capture those bytes as a single .hex0
## source and let hex0-raw re-emit them: byte-identical output, no stdenv
## in the trust path.
##
## Source regenerator (when tools/elf64-to-m1.M1 or the MACHO template
## changes): scripts/stage0/regen-elf64-to-m1-seed.sh.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  elf64-to-m1-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "elf64-to-m1-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/elf64-to-m1/elf64-to-m1_AMD64_darwin_final.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-dkquASOV5jS0wsyMNzOJ4sMX9+t1AobCmIg2GV0VNm4=";
      }
    else
      null;
in

mkDarwin {
  pname = "elf64-to-m1";
  version = "0-unstable-2026-06-20";

  buildPhase = ''
    runHook preBuild
    install -m755 ${elf64-to-m1-raw} elf64-to-m1
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 elf64-to-m1 $out/bin/elf64-to-m1
    install -Dm644 ${root + "/hex0/sources/elf64-to-m1/elf64-to-m1_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/elf64-to-m1_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit elf64-to-m1-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O elf64-to-m1 converter (no stdenv in trust path)";
  };
}
