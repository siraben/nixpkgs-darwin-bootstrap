{
  darwin,
  mkDarwin,
  macho-patcher-early,
  catm,
  hex2-0,
  m0,
  m2,
  blood-macho-0,
  root,
  source,
  stage0Sources,
  ...
}:
mkDarwin {
  pname = "blood-macho-0";
  buildPhase = ''
    runHook preBuild

    ${m2}/bin/M2-darwin \
      --architecture amd64 \
      -f ${root + "/M2libc/amd64/Darwin/bootstrap.c"} \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${stage0Sources}/mescc-tools/stringify.c \
      -f ${stage0Sources}/mescc-tools/blood-elf.c \
      --bootstrap-mode \
      -o blood-macho-0.M1
    ${catm}/bin/catm-darwin blood-macho-0-0.M1 \
      ${root + "/M2libc/amd64/amd64_defs.M1"} \
      ${root + "/M2libc/amd64/libc-core-Darwin.M1"} \
      blood-macho-0.M1
    ${m0}/bin/M0-darwin blood-macho-0-0.M1 blood-macho-0.hex2

    if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' blood-macho-0.hex2; then
      echo "blood-macho-0 hex2 contains untranslated M1 tokens" >&2
      exit 1
    fi

    ${catm}/bin/catm-darwin blood-macho-0-0.hex2 \
      ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      blood-macho-0.hex2
    ${hex2-0}/bin/hex2-darwin blood-macho-0-0.hex2 blood-macho-0
    ${macho-patcher-early}/bin/macho-patcher m2-segments blood-macho-0.hex2 blood-macho-0

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=blood-macho-0 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x blood-macho-0

    source ${darwin.signingUtils}
    sign blood-macho-0

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    cp ${root + "/stage0-posix/fixtures/blood-elf-macho-mini.M1"} mini.M1
    ./blood-macho-0 --64 --little-endian -f mini.M1 -o footer.M1
    grep -q ':ELF_section_headers' footer.M1
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 blood-macho-0 $out/bin/blood-macho-0
    install -Dm644 blood-macho-0.M1 $out/share/darwin-bootstrap/blood-macho-0.M1
    install -Dm644 blood-macho-0.hex2 $out/share/darwin-bootstrap/blood-macho-0.hex2
    runHook postInstall
  '';

  meta = {
    description = "Signed Darwin Mach-O phase-6 AMD64 blood footer generator";
  };
}
