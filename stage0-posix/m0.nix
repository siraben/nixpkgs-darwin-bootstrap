## phase3-m0 — seed-built Darwin Mach-O M0 assembler.
##
## Built by feeding the pre-concatenated, pre-padded hex2 source
## (`hex0/sources/m0/M0_AMD64_darwin_combined.hex2`) directly to the
## seed-built hex2 binary used as `derivation.builder`.  No catm, no
## dd, no codesign: padding and concatenation are baked into the
## source.
{
  hostPlatform,
  mkDarwin,
  phase2-hex2,
  root,
  ...
}:

let
  m0-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "phase3-m0-raw";
        system = "x86_64-darwin";
        builder = phase2-hex2.hex2-raw;
        args = [
          (root + "/hex0/sources/m0/M0_AMD64_darwin_combined.hex2")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-0000000000000000000000000000000000000000000=";
      }
    else
      null;
in

mkDarwin {
  pname = "phase3-m0";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild
    install -m755 ${m0-raw} M0-darwin
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cp ${root + "/stage0-posix/fixtures/m0-smoke.M1"} smoke.M1
    cp ${root + "/stage0-posix/fixtures/m0-expected"} expected
    ./M0-darwin smoke.M1 smoke.hex2
    cmp expected smoke.hex2
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 M0-darwin $out/bin/M0-darwin
    install -Dm644 ${root + "/hex0/sources/m0/M0_AMD64_darwin_combined.hex2"} \
      $out/share/darwin-bootstrap/M0_AMD64_darwin_combined.hex2
    runHook postInstall
  '';

  passthru = { inherit m0-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O phase-3 AMD64 M0 (no clang in trust path)";
  };
}
