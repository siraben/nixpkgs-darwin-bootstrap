## m0 — Darwin Mach-O M0 macro assembler, built live from source.
##
## catm prepends the committed Mach-O header template
## (nix/tools/templates/MACHO-amd64-lowdata.hex2) to the committed M0 body
## (nix/M2libc/amd64/M0_AMD64_darwin_body.hex2), the seed-built hex2 assembles
## it, then dd pads to the LINKEDIT offset.  Runs unsigned in the Nix
## sandbox on x86_64 (verified empirically).  All translation is done by
## chain-built tools (catm, hex2); stdenv only orchestrates (cp/dd/install).
## No committed binary dump.
##
## The M0 body is regenerated from upstream stage0Sources by the maintainer
## via nix/scripts/stage0/regen-preported.sh; build-time has no awk/perl/python.
{
  mkDarwin,
  catm,
  hex2-0,
  root,
  ...
}:

mkDarwin {
  pname = "m0";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild

    cp ${root + "/tools/templates/MACHO-amd64-lowdata.hex2"} MACHO-amd64-lowdata.hex2
    cp ${root + "/M2libc/amd64/M0_AMD64_darwin_body.hex2"} M0_AMD64_darwin_body.hex2

    ${catm}/bin/catm-darwin M0-darwin.hex2 \
      MACHO-amd64-lowdata.hex2 \
      M0_AMD64_darwin_body.hex2
    ${hex2-0}/bin/hex2-darwin M0-darwin.hex2 M0-darwin

    ## linkedit offset = text_size + data_size = 0x800000 + 0x2000000 = 0x2800000.
    dd if=/dev/zero of=M0-darwin bs=1 count=1 seek="$((0x2800000 - 1))" conv=notrunc
    chmod +x M0-darwin

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
    install -Dm644 M0-darwin.hex2 $out/share/darwin-bootstrap/M0-darwin.hex2
    install -Dm644 M0_AMD64_darwin_body.hex2 $out/share/darwin-bootstrap/M0_AMD64_darwin_body.hex2
    ## Downstream phases (cc-arch, blood-elf-macho, M1, hex2-1, M2, tinycc/*)
    ## read the MACHO template from $out/share to catm in front of their .hex2
    ## bodies, so keep it shipped here.
    install -Dm644 MACHO-amd64-lowdata.hex2 \
      $out/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2
    runHook postInstall
  '';

  meta = {
    description = "Darwin Mach-O M0 assembler, built from committed M0 body via catm + chain hex2";
  };
}
