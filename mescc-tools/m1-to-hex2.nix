## m1-to-hex2 — seed-built Darwin Mach-O M1->hex2 translator.
##
## The old chain ran M2-Planet (bootstrap/m1-to-hex2.c) -> M1 -> hex2
## (MACHO-amd64-lowdata.hex2 template, base 0x600000) -> macho-patcher
## m2-segments -> dd pad to 0x2800000 -> ad-hoc codesign.  m1-to-hex2 is
## signed, so the final binary exceeds 0x2800000 by its codesign trailer.
## Capture the full signed binary as a single .hex0 source and let hex0-raw
## re-emit it: byte-identical output, no stdenv in the trust path.  The smoke
## checkPhase still runs against the re-emitted binary.
##
## Source regenerator (when bootstrap/m1-to-hex2.c or the MACHO template
## changes): scripts/stage0/regen-m1-to-hex2-seed.sh.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  m1-to-hex2-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "m1-to-hex2-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/m1-to-hex2/m1-to-hex2_AMD64_darwin_final.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-5I25Njd6lDp8cdxFJJIcJi4TjzerS+boIs1wJ84n/Ds=";
      }
    else
      null;
in

mkDarwin {
  pname = "m1-to-hex2";
  version = "0-unstable-2026-06-20";

  buildPhase = ''
    runHook preBuild
    install -m755 ${m1-to-hex2-raw} m1-to-hex2
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cp ${root + "/mescc-tools/fixtures/m1-to-hex2-smoke.M1"} smoke.M1
    ./m1-to-hex2 --architecture amd64 --little-endian \
      --base-address 0x600400 -f smoke.M1 -o smoke.hex2
    grep -q ':foo' smoke.hex2
    grep -q ':bar' smoke.hex2
    grep -q '48 31 C0' smoke.hex2
    grep -q '^90$' smoke.hex2
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 m1-to-hex2 $out/bin/m1-to-hex2
    install -Dm644 ${root + "/hex0/sources/m1-to-hex2/m1-to-hex2_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/m1-to-hex2_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit m1-to-hex2-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O m1-to-hex2 translator (no stdenv in trust path)";
  };
}
