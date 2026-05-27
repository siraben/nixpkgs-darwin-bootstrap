args:
with args;
stdenv.mkDerivation {
  pname = "phase10-hex2";
  version = "0-unstable-2026-05-07";

  dontUnpack = true;
  dontStrip = true;
  strictDeps = true;
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
      -f ${root + "/M2libc/amd64/Darwin/sys/stat.c"} \
      -f ${stage0Sources}/M2libc/ctype.c \
      -f ${stage0Sources}/M2libc/stdlib.c \
      -f ${stage0Sources}/M2libc/stdarg.h \
      -f ${stage0Sources}/M2libc/stdio.h \
      -f ${stage0Sources}/M2libc/stdio.c \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${stage0Sources}/mescc-tools/hex2.h \
      -f ${stage0Sources}/mescc-tools/hex2_linker.c \
      -f ${stage0Sources}/mescc-tools/hex2_word.c \
      -f ${stage0Sources}/mescc-tools/hex2.c \
      -o hex2_linker-2.M1

    ${phase9-m1}/bin/M1 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f hex2_linker-2.M1 \
      -o hex2_linker-2.hex2

    if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' hex2_linker-2.hex2; then
      echo "hex2 hex2 contains untranslated M1 tokens" >&2
      exit 1
    fi

    ${phase8-hex2-1}/bin/hex2-1 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f hex2_linker-2.hex2 \
      -o hex2
    ${phase11e-macho-patcher-early}/bin/macho-patcher m2-segments hex2_linker-2.hex2 hex2

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=hex2 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x hex2

    source ${darwin.signingUtils}
    sign hex2

    ./hex2 --help > help.stdout 2> help.stderr
    cat help.stdout help.stderr > help.combined
    grep -q 'Usage:' help.combined

    cat > mini.hex2 <<'HEX2'
    :FUNCTION_main
    48 C7 C0 00 00 00 00
    C3
    :ELF_data
    HEX2
    ./hex2 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f mini.hex2 \
      -o mini
    test -s mini

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hex2 $out/bin/hex2
    install -Dm644 hex2_linker-2.M1 $out/share/darwin-bootstrap/hex2_linker-2.M1
    install -Dm644 hex2_linker-2.hex2 $out/share/darwin-bootstrap/hex2_linker-2.hex2
    runHook postInstall
  '';

  meta = {
    description = "Signed Darwin Mach-O phase-10 AMD64 full hex2 linker";
    platforms = [ "x86_64-darwin" ];
  };
}
