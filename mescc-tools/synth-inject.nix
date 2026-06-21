## synth-inject — seed-built cross-object synth-label injector.
##
## The old chain ran M2-Planet (bootstrap/synth-inject.c) -> M1 -> hex2
## (MACHO-amd64-lowdata.hex2 template, base 0x600000) -> macho-patcher
## m2-segments -> dd pad to 0x2800000 -> ad-hoc codesign.  synth-inject is
## signed, so the final binary exceeds 0x2800000 by its codesign trailer.
## Capture the full signed binary as a single .hex0 source and let hex0-raw
## re-emit it: byte-identical output, no stdenv in the trust path.  The smoke
## checkPhase still runs against the re-emitted binary.
##
## Source regenerator (when bootstrap/synth-inject.c or the MACHO template
## changes): scripts/stage0/regen-synth-inject-seed.sh.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  synth-inject-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "synth-inject-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/synth-inject/synth-inject_AMD64_darwin_final.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-hw1C/q1uJpuMzyN2SeIQfX8ZAr5rjFgiU8/DEdg9yOA=";
      }
    else
      null;
in

mkDarwin {
  pname = "synth-inject";
  version = "0-unstable-2026-06-20";

  buildPhase = ''
    runHook preBuild
    install -m755 ${synth-inject-raw} synth-inject
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./synth-inject ${root + "/mescc-tools/fixtures/synth-inject-smoke.M1"} > smoke.out
    cmp smoke.out ${root + "/mescc-tools/fixtures/synth-inject-smoke.expected"}
    ## no-op path: a stream with no undefined synth refs passes through
    ./synth-inject ${root + "/mescc-tools/fixtures/synth-inject-noop.M1"} > noop.out
    cmp noop.out ${root + "/mescc-tools/fixtures/synth-inject-noop.expected"}
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 synth-inject $out/bin/synth-inject
    install -Dm644 ${root + "/hex0/sources/synth-inject/synth-inject_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/synth-inject_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit synth-inject-raw; };

  meta = {
    description = "Seed-built cross-object synth-label injector for the tcc link path (no stdenv in trust path)";
  };
}
