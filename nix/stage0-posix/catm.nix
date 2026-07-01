## catm — Darwin Mach-O file concatenator, built live from source.
##
## The seed-built hex2 assembles the committed Mach-O header template
## (nix/tools/templates/MACHO-amd64-catm-header.hex2) and the committed catm
## body (nix/M2libc/amd64/catm_AMD64_darwin_body.hex2) separately; they are
## concatenated and padded to data_end=0x900000.  Runs unsigned in the Nix
## sandbox on x86_64.  Translation is done by the chain hex2; stdenv only
## orchestrates.  No committed binary dump.
##
## The catm body is regenerated from upstream stage0Sources by the
## maintainer via nix/scripts/stage0/regen-preported.sh; build-time has no
## awk/perl/python.
{
  mkDarwin,
  hex2-0,
  root,
  ...
}:

mkDarwin {
  pname = "catm";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild

    cp ${root + "/M2libc/amd64/catm_AMD64_darwin_body.hex2"} catm_AMD64_darwin_body.hex2

    ${hex2-0}/bin/hex2-darwin \
      ${root + "/tools/templates/MACHO-amd64-catm-header.hex2"} \
      header.bin
    ${hex2-0}/bin/hex2-darwin catm_AMD64_darwin_body.hex2 body.bin
    cat header.bin body.bin > catm-darwin

    ## Pad to data_end = text_size + data_size = 0x800000 + 0x100000 = 0x900000.
    dataEnd=$((0x900000))
    currentSize=$(stat -f%z catm-darwin 2>/dev/null || stat -c%s catm-darwin)
    if [ "$currentSize" -lt "$dataEnd" ]; then
      dd if=/dev/zero of=catm-darwin bs=1 count="$((dataEnd - currentSize))" \
        seek="$currentSize" conv=notrunc 2>/dev/null
    fi
    chmod +x catm-darwin

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
    install -Dm644 catm_AMD64_darwin_body.hex2 $out/share/darwin-bootstrap/catm_AMD64_darwin_body.hex2
    runHook postInstall
  '';

  meta = {
    description = "Darwin Mach-O catm concatenator, built from committed body via chain hex2";
    platforms = [ "x86_64-darwin" ];
  };
}
