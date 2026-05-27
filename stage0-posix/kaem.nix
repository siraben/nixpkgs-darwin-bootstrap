{
  darwin,
  mkDarwin,
  phase10-hex2,
  phase11-kaem,
  phase26g-macho-patcher,
  phase3-m0,
  phase5-m2,
  phase9-m1,
  root,
  source,
  stage0Sources,
  ...
}:
mkDarwin {
  pname = "phase11-kaem";
  buildPhase = ''
    runHook preBuild

    ${phase5-m2}/bin/M2-darwin \
      --architecture amd64 \
      -f ${stage0Sources}/M2libc/sys/types.h \
      -f ${stage0Sources}/M2libc/stddef.h \
      -f ${stage0Sources}/M2libc/sys/utsname.h \
      -f ${root + "/M2libc/amd64/Darwin/unistd.c"} \
      -f ${root + "/M2libc/amd64/Darwin/fcntl.c"} \
      -f ${stage0Sources}/M2libc/fcntl.c \
      -f ${stage0Sources}/M2libc/ctype.c \
      -f ${stage0Sources}/M2libc/stdlib.c \
      -f ${stage0Sources}/M2libc/string.c \
      -f ${stage0Sources}/M2libc/stdarg.h \
      -f ${stage0Sources}/M2libc/stdio.h \
      -f ${stage0Sources}/M2libc/stdio.c \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${stage0Sources}/mescc-tools/Kaem/kaem.h \
      -f ${stage0Sources}/mescc-tools/Kaem/variable.c \
      -f ${stage0Sources}/mescc-tools/Kaem/kaem_globals.c \
      -f ${stage0Sources}/mescc-tools/Kaem/kaem.c \
      -o kaem.M1

    ${phase9-m1}/bin/M1 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f kaem.M1 \
      -o kaem.hex2

    if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' kaem.hex2; then
      echo "kaem hex2 contains untranslated M1 tokens" >&2
      exit 1
    fi

    ${phase10-hex2}/bin/hex2 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f kaem.hex2 \
      -o kaem
    ${phase26g-macho-patcher}/bin/macho-patcher m2-segments kaem.hex2 kaem

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=kaem bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x kaem

    source ${darwin.signingUtils}
    sign kaem

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./kaem --help > help.stdout 2> help.stderr
    cat help.stdout help.stderr > help.combined
    grep -q 'Usage:' help.combined

    cat > smoke.kaem <<'KAEM'
    echo hello
    KAEM
    output="$(./kaem --init-mode -f smoke.kaem)"
    test "$output" = "hello"
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 kaem $out/bin/kaem
    install -Dm644 kaem.M1 $out/share/darwin-bootstrap/kaem.M1
    install -Dm644 kaem.hex2 $out/share/darwin-bootstrap/kaem.hex2
    runHook postInstall
  '';

  meta = {
    description = "Signed Darwin Mach-O phase-11 AMD64 kaem shell";
  };
}
