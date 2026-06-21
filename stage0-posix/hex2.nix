## hex2 — seed-built Darwin Mach-O hex2 linker.
##
## Built purely by hex0 acting as `derivation.builder`.  Padding to the
## LINKEDIT vmaddr (0x1800000) is baked directly into
## hex0/sources/hex2_AMD64_darwin.hex0, so no post-process dd is needed
## and the output runs unsigned in the Nix sandbox on x86_64.
{
  hex0,
  hostPlatform,
  mkDarwin,
  root,
  ...
}:

let
  hex2-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "hex2-raw";
        system = "x86_64-darwin";
        builder = hex0.hex0-raw;
        args = [
          (root + "/hex0/sources/hex2_AMD64_darwin.hex0")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-uRpXlPsIo5ONkwyBAKMOv1tamZYuOCwcYZypykDD9Ec=";
      }
    else
      null;
in

mkDarwin {
  pname = "hex2-0";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild
    install -m755 ${hex2-raw} hex2-darwin
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cp ${root + "/stage0-posix/fixtures/hex2-labels.hex2"} labels.hex2
    printf 'Hi\n' > expected
    ./hex2-darwin labels.hex2 labels-output
    cmp expected labels-output

    cp ${root + "/stage0-posix/fixtures/hex2-pointer.hex2"} pointer.hex2
    printf '\xfc\xff\xff\xff' > pointer-expected
    ./hex2-darwin pointer.hex2 pointer-output
    cmp pointer-expected pointer-output
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hex2-darwin $out/bin/hex2-darwin
    install -Dm644 ${root + "/hex0/sources/hex2_AMD64_darwin.hex0"} \
      $out/share/darwin-bootstrap/hex2_AMD64_darwin.hex0
    runHook postInstall
  '';

  passthru = { inherit hex2-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O phase-2 AMD64 hex2 (no stdenv in trust path)";
  };
}
