args:
with args;
stdenv.mkDerivation {
  pname = "darwin-minimal-bootstrap-phase4-cc-arch-amd64";
  version = "0-unstable-2026-05-07";

  dontUnpack = true;
  dontStrip = true;
  strictDeps = true;

  nativeBuildInputs = [ ];

  ## phase4-amd64-cc-arch.pl's patch mode replaced by
  ## phase11e-macho-patcher-early (m2-segments mode).  The
  ## pre-ported cc_arch-0-darwin.hex2 source has `:ELF_data`
  ## injected by the port-cc-arch awk just before `:prim_types`,
  ## so m2-segments finds the static-block start by the same
  ## label-scan logic it uses for phase5-m2.  Verified byte-
  ## identical to the prior perl patch output.
  buildPhase = ''
    runHook preBuild

    # Use the committed pre-ported Darwin source (cc_amd64.M1 →
    # M0 expand → port + :ELF_data injection).  Maintainer
    # regenerates via scripts/stage0/regen-preported.sh whenever
    # stage0Sources is bumped; build-time has no awk/perl/python.
    cp ${root + "/M2libc/amd64/cc_arch-0-darwin.hex2"} cc_arch-0.hex2
    ${phase2-catm}/bin/catm-darwin cc_arch.hex2 \
      ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      cc_arch-0.hex2
    ${phase2-hex2}/bin/hex2-darwin cc_arch.hex2 cc_arch-darwin
    ${phase11e-macho-patcher-early}/bin/macho-patcher m2-segments \
      cc_arch-0.hex2 cc_arch-darwin

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=cc_arch-darwin bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x cc_arch-darwin

    source ${darwin.signingUtils}
    sign cc_arch-darwin

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
    description = "Signed Darwin Mach-O phase-4 AMD64 cc_arch";
    platforms = [ "x86_64-darwin" ];
  };
}
