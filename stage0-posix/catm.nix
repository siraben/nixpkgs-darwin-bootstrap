args:
with args;
mkDarwin {
  pname = "phase2-catm";

  buildPhase = ''
    runHook preBuild

    # Use the committed pre-ported Darwin source.  Maintainer
    # regenerates via scripts/stage0/regen-preported.sh whenever
    # stage0Sources is bumped; build-time has no awk/perl/python.
    cp ${root + "/M2libc/amd64/catm_AMD64_darwin_body.hex2"} catm_AMD64_darwin_body.hex2

    # Assemble header + body separately via phase2-hex2, then cat them
    # and pad to data_end / linkedit_offset.  Mirrors what the removed
    # tools/phase2-amd64-catm.py did (write_bytes(header + body) + pad).
    ${phase2-hex2}/bin/hex2-darwin \
      ${root + "/tools/templates/MACHO-amd64-catm-header.hex2"} \
      header.bin
    ${phase2-hex2}/bin/hex2-darwin catm_AMD64_darwin_body.hex2 body.bin
    cat header.bin body.bin > catm-darwin

    # Pad to data_end = text_size + data_size = 0x800000 + 0x100000 = 0x900000
    # Then to linkedit_offset = same = 0x900000 (catm has small data_size)
    dataEnd=9437184    # 0x900000
    currentSize=$(stat -f%z catm-darwin 2>/dev/null || stat -c%s catm-darwin)
    if [ "$currentSize" -lt "$dataEnd" ]; then
      dd if=/dev/zero of=catm-darwin bs=1 count="$((dataEnd - currentSize))" \
        seek="$currentSize" conv=notrunc 2>/dev/null
    fi
    chmod +x catm-darwin

    source ${darwin.signingUtils}
    sign catm-darwin

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
    description = "Runnable signed Darwin Mach-O phase-2 AMD64 catm";
    platforms = [ "x86_64-darwin" ];
  };
}
