{
  darwin,
  mkDarwin,
  phase11e-macho-patcher-early,
  phase3-m0,
  phase5-m2,
  phase7-m1-0,
  phase8-hex2-1,
  phase9-m1,
  root,
  source,
  stage0Sources,
  ...
}:
mkDarwin {
  pname = "phase9-m1";
  buildPhase = ''
    runHook preBuild

    ${phase5-m2}/bin/M2-darwin \
      --architecture amd64 \
      -f ${stage0Sources}/M2libc/sys/types.h \
      -f ${stage0Sources}/M2libc/stddef.h \
      -f ${stage0Sources}/M2libc/sys/utsname.h \
      -f ${root + "/M2libc/amd64/Darwin/fcntl.c"} \
      -f ${stage0Sources}/M2libc/fcntl.c \
      -f ${root + "/M2libc/amd64/Darwin/unistd.c"} \
      -f ${stage0Sources}/M2libc/stdarg.h \
      -f ${stage0Sources}/M2libc/string.c \
      -f ${stage0Sources}/M2libc/ctype.c \
      -f ${stage0Sources}/M2libc/stdlib.c \
      -f ${stage0Sources}/M2libc/stdio.h \
      -f ${stage0Sources}/M2libc/stdio.c \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${stage0Sources}/mescc-tools/stringify.c \
      -f ${stage0Sources}/mescc-tools/M1-macro.c \
      -o M1-macro-1.M1

    ${phase7-m1-0}/bin/M1-0 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f M1-macro-1.M1 \
      -o M1-macro-1.hex2

    if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-macro-1.hex2; then
      echo "M1 hex2 contains untranslated M1 tokens" >&2
      exit 1
    fi

    ${phase8-hex2-1}/bin/hex2-1 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f M1-macro-1.hex2 \
      -o M1
    ${phase11e-macho-patcher-early}/bin/macho-patcher m2-segments M1-macro-1.hex2 M1

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=M1 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x M1

    source ${darwin.signingUtils}
    sign M1

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./M1 --help > help.stdout 2> help.stderr
    cat help.stdout help.stderr > help.combined
    grep -q 'Usage:' help.combined

    cp ${root + "/stage0-posix/fixtures/M1-mini.M1"} mini.M1
    ./M1 --architecture amd64 --little-endian -f mini.M1 -o mini.hex2
    grep -q ':foo' mini.hex2
    grep -q 'C3' mini.hex2
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 M1 $out/bin/M1
    install -Dm644 M1-macro-1.M1 $out/share/darwin-bootstrap/M1-macro-1.M1
    install -Dm644 M1-macro-1.hex2 $out/share/darwin-bootstrap/M1-macro-1.hex2
    runHook postInstall
  '';

  meta = {
    description = "Signed Darwin Mach-O phase-9 AMD64 M1 macro assembler";
  };
}
