{
  darwin,
  mkDarwin,
  macho-patcher-early,
  catm,
  hex2-0,
  m0,
  m2,
  m1-0,
  root,
  source,
  stage0Sources,
  ...
}:
mkDarwin {
  pname = "phase7-m1-0";
  buildPhase = ''
    runHook preBuild

    ${m2}/bin/M2-darwin \
      --architecture amd64 \
      -f ${root + "/M2libc/amd64/Darwin/bootstrap.c"} \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${stage0Sources}/mescc-tools/stringify.c \
      -f ${stage0Sources}/mescc-tools/M1-macro.c \
      --bootstrap-mode \
      -o M1-macro-0.M1
    ${catm}/bin/catm-darwin M1-0-0.M1 \
      ${root + "/M2libc/amd64/amd64_defs.M1"} \
      ${root + "/M2libc/amd64/libc-core-Darwin.M1"} \
      M1-macro-0.M1
    ${m0}/bin/M0-darwin M1-0-0.M1 M1-0.hex2

    if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-0.hex2; then
      echo "M1-0 hex2 contains untranslated M1 tokens" >&2
      exit 1
    fi

    ${catm}/bin/catm-darwin M1-0-0.hex2 \
      ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      M1-0.hex2
    ${hex2-0}/bin/hex2-darwin M1-0-0.hex2 M1-0
    ${macho-patcher-early}/bin/macho-patcher m2-segments M1-0.hex2 M1-0

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=M1-0 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x M1-0

    source ${darwin.signingUtils}
    sign M1-0

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./M1-0 --help > help.stdout 2> help.stderr
    grep -q 'Usage:' help.stderr

    cp ${root + "/stage0-posix/fixtures/M1-0-mini.M1"} mini.M1
    ./M1-0 --architecture amd64 --little-endian -f mini.M1 -o mini.hex2
    grep -q ':foo' mini.hex2
    grep -q 'C3' mini.hex2
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 M1-0 $out/bin/M1-0
    install -Dm644 M1-macro-0.M1 $out/share/darwin-bootstrap/M1-macro-0.M1
    install -Dm644 M1-0.hex2 $out/share/darwin-bootstrap/M1-0.hex2
    runHook postInstall
  '';

  meta = {
    description = "Signed Darwin Mach-O phase-7 AMD64 M1 macro assembler";
  };
}
