## m1-split — seed-built M1 code/data section splitter.
##
## The old chain ran M2-Planet (bootstrap/m1-split.c) -> M1 -> hex2
## (MACHO-amd64-lowdata.hex2 template, base 0x600000) -> macho-patcher
## m2-segments -> dd pad to 0x2800000 -> ad-hoc codesign.  m1-split is
## signed, so the final binary exceeds 0x2800000 by its codesign trailer.
## Capture the full signed binary as a single .hex0 source and let hex0-raw
## re-emit it: byte-identical output, no stdenv in the trust path.  The
## smoke checkPhase still runs against the re-emitted binary.
##
## Source regenerator (when bootstrap/m1-split.c or the MACHO template
## changes): scripts/stage0/regen-m1-split-seed.sh.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  m1-split-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "m1-split-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/m1-split/m1-split_AMD64_darwin_final.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-4LzuCZl/XsVvCMsyhd2+QjjN5QfW5Ht/ad69whZwA/s=";
      }
    else
      null;
in

mkDarwin {
  pname = "m1-split";
  version = "0-unstable-2026-06-20";

  buildPhase = ''
    runHook preBuild
    install -m755 ${m1-split-raw} m1-split
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./m1-split --code < ${root + "/mescc-tools/fixtures/m1-split-smoke.M1"} > smoke.code
    cmp smoke.code ${root + "/mescc-tools/fixtures/m1-split-smoke.code.expected"}
    ./m1-split --data < ${root + "/mescc-tools/fixtures/m1-split-smoke.M1"} > smoke.data
    cmp smoke.data ${root + "/mescc-tools/fixtures/m1-split-smoke.data.expected"}
    ./m1-split --data < ${root + "/mescc-tools/fixtures/m1-split-smoke-noeol.M1"} > smoke.noeol
    cmp smoke.noeol ${root + "/mescc-tools/fixtures/m1-split-smoke-noeol.data.expected"}
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 m1-split $out/bin/m1-split
    install -Dm644 ${root + "/hex0/sources/m1-split/m1-split_AMD64_darwin_final.hex0"} \
      $out/share/darwin-bootstrap/m1-split_AMD64_darwin_final.hex0
    runHook postInstall
  '';

  passthru = { inherit m1-split-raw; };

  meta = {
    description = "Seed-built M1 code/data splitter for the tcc link path (no stdenv in trust path)";
  };
}
