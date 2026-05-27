args:
with args;
mkDarwin {
  pname = "phase2-hex2";
  buildPhase = ''
    runHook preBuild

    ## Assemble the committed hand-rolled hex0 source for the
    ## Darwin-ported hex2 linker.  See hex0/sources/hex2_AMD64_darwin.hex0
    ## for sections (Mach-O header with __DATA size 0x1000000,
    ## ported body with disps baked in).  Build-time: no perl/awk.
    ${hex0}/bin/hex0 \
      ${root + "/hex0/sources/hex2_AMD64_darwin.hex0"} \
      hex2-darwin

    ## Pad to LINKEDIT offset (file offset 0x1800000 = 25165824).
    dd if=/dev/zero of=hex2-darwin bs=1 count=1 seek=25165823 conv=notrunc
    chmod +x hex2-darwin

    source ${darwin.signingUtils}
    sign hex2-darwin

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cat > labels.hex2 <<'HEX2'
    :hello
    48 69 0a
    HEX2
    printf 'Hi\n' > expected
    ./hex2-darwin labels.hex2 labels-output
    cmp expected labels-output

    cat > pointer.hex2 <<'HEX2'
    :s
    %s
    HEX2
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

  meta = {
    description = "Runnable signed Darwin Mach-O phase-2 AMD64 hex2";
  };
}
