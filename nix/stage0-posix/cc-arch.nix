## cc-arch — Darwin Mach-O cc_arch, built live from source.
##
## catm prepends the committed MACHO header template (shipped in m0's share)
## to the committed cc_arch body (nix/M2libc/amd64/cc_arch-0-darwin.hex2), the
## seed-built hex2 assembles it, macho-patcher-early applies the m2-segments
## vmsize fixup in place, then dd pads to the LINKEDIT offset.  Runs unsigned
## in the Nix sandbox on x86_64.  All translation is done by chain-built
## tools (catm, hex2, macho-patcher-early); stdenv only orchestrates.  No
## committed binary dump.
##
## The cc_arch body is regenerated from upstream stage0Sources by the
## maintainer via nix/scripts/stage0/regen-preported.sh; build-time has no
## awk/perl/python.
{
  mkDarwin,
  catm,
  hex2-0,
  m0,
  macho-patcher-early,
  root,
  ...
}:

mkDarwin {
  pname = "cc-arch";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild

    cp ${root + "/M2libc/amd64/cc_arch-0-darwin.hex2"} cc_arch-0.hex2

    ${catm}/bin/catm-darwin cc_arch.hex2 \
      ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      cc_arch-0.hex2
    ${hex2-0}/bin/hex2-darwin cc_arch.hex2 cc_arch-darwin
    ${macho-patcher-early}/bin/macho-patcher m2-segments \
      cc_arch-0.hex2 cc_arch-darwin

    ## linkedit offset = text_size + data_size = 0x800000 + 0x2000000 = 0x2800000.
    dd if=/dev/zero of=cc_arch-darwin bs=1 count=1 seek="$((0x2800000 - 1))" conv=notrunc
    chmod +x cc_arch-darwin

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 cc_arch-darwin $out/bin/cc_arch-darwin
    install -Dm644 cc_arch.hex2 $out/share/darwin-bootstrap/cc_arch.hex2
    install -Dm644 cc_arch-0.hex2 $out/share/darwin-bootstrap/cc_arch-0.hex2
    runHook postInstall
  '';

  meta = {
    description = "Darwin Mach-O cc_arch, built from committed body via catm + chain hex2 + macho-patcher-early";
  };
}
