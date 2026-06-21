## catm — seed-built Darwin Mach-O catm.
##
## Concatenation of `MACHO-amd64-catm-header.hex2` + the ported
## `catm_AMD64_darwin_body.hex2` lives in
## `hex0/sources/catm/catm_AMD64_darwin_combined.hex2`, padded to
## data_end=0x900000.  hex2 (pure seed-built) acts as
## `derivation.builder`.
{
  hostPlatform,
  mkDarwin,
  hex2-0,
  root,
  ...
}:

let
  catm-raw =
    if hostPlatform.isx86_64 then
      derivation {
        name = "catm-raw";
        system = "x86_64-darwin";
        builder = hex2-0.hex2-raw;
        args = [
          (root + "/hex0/sources/catm/catm_AMD64_darwin_combined.hex2")
          (placeholder "out")
        ];
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-Hy8fvz+rxfecnBzPYF/bMLH5qcuzkvKM+6g/XPoRKLk=";
      }
    else
      null;
in

mkDarwin {
  pname = "catm";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild
    install -m755 ${catm-raw} catm-darwin
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    printf foo > a
    printf bar > b
    printf foobar > expected
    ./catm-darwin output a b
    cmp expected output
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 catm-darwin $out/bin/catm-darwin
    install -Dm644 ${root + "/hex0/sources/catm/catm_AMD64_darwin_combined.hex2"} \
      $out/share/darwin-bootstrap/catm_AMD64_darwin_combined.hex2
    runHook postInstall
  '';

  passthru = { inherit catm-raw; };

  meta = {
    description = "Seed-built Darwin Mach-O phase-2 AMD64 catm (no stdenv in trust path)";
    platforms = [ "x86_64-darwin" ];
  };
}
