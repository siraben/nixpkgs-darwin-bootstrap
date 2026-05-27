args:
with args;
stdenv.mkDerivation {
  pname = "darwin-minimal-bootstrap-phase3-m0-amd64";
  version = "0-unstable-2026-05-07";

  dontUnpack = true;
  dontStrip = true;
  strictDeps = true;

  nativeBuildInputs = [ ];

  buildPhase = ''
    runHook preBuild

    # MACHO-amd64-lowdata.hex2 is a deterministic Mach-O header — the
    # constants (TEXT_SIZE, DATA_VMADDR, LINKEDIT layout, etc.) don't
    # depend on any input.  Use the static committed snapshot in
    # tree.
    cp ${root + "/tools/templates/MACHO-amd64-lowdata.hex2"} MACHO-amd64-lowdata.hex2

    # Use the committed pre-ported Darwin source.  Maintainer
    # regenerates via scripts/stage0/regen-preported.sh whenever
    # stage0Sources is bumped; build-time has no awk/perl/python.
    cp ${root + "/M2libc/amd64/M0_AMD64_darwin_body.hex2"} M0_AMD64_darwin_body.hex2

    ${phase2-catm}/bin/catm-darwin M0-darwin.hex2 \
      MACHO-amd64-lowdata.hex2 \
      M0_AMD64_darwin_body.hex2
    ${phase2-hex2}/bin/hex2-darwin M0-darwin.hex2 M0-darwin

    # linkedit-offset is a static constant: text_size + data_size
    # = 0x800000 + 0x2000000 = 0x2800000 = 41943040.
    linkeditOffset=41943040
    dd if=/dev/zero of=M0-darwin bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x M0-darwin

    source ${darwin.signingUtils}
    sign M0-darwin

    cat > smoke.M1 <<'M1'
    :foo
    "AB"
    '43 00'
    M1
    cat > expected <<'HEX2'
    :foo
    414200
    43 00
    HEX2
    ./M0-darwin smoke.M1 smoke.hex2
    cmp expected smoke.hex2

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 M0-darwin $out/bin/M0-darwin
    install -Dm644 M0-darwin.hex2 $out/share/darwin-bootstrap/M0-darwin.hex2
    install -Dm644 M0_AMD64_darwin_body.hex2 $out/share/darwin-bootstrap/M0_AMD64_darwin_body.hex2
    install -Dm644 MACHO-amd64-lowdata.hex2 $out/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2
    runHook postInstall
  '';

  meta = {
    description = "Runnable signed Darwin Mach-O phase-3 AMD64 M0";
    platforms = [ "x86_64-darwin" ];
  };
}
