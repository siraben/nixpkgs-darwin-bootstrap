args:
with args;
stdenv.mkDerivation {
  pname = "darwin-minimal-bootstrap-phase12-m2-planet-amd64";
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
      -f ${stage0Sources}/M2libc/string.c \
      -f ${stage0Sources}/M2libc/stdarg.h \
      -f ${stage0Sources}/M2libc/stdio.h \
      -f ${stage0Sources}/M2libc/stdio.c \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${stage0Sources}/M2-Planet/cc.h \
      -f ${stage0Sources}/M2-Planet/cc_globals.c \
      -f ${stage0Sources}/M2-Planet/cc_reader.c \
      -f ${stage0Sources}/M2-Planet/cc_strings.c \
      -f ${stage0Sources}/M2-Planet/cc_types.c \
      -f ${stage0Sources}/M2-Planet/cc_emit.c \
      -f ${stage0Sources}/M2-Planet/cc_core.c \
      -f ${stage0Sources}/M2-Planet/cc_macro.c \
      -f ${stage0Sources}/M2-Planet/cc.c \
      -o M2-Planet.M1

    ${phase9-m1}/bin/M1 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f M2-Planet.M1 \
      -o M2-Planet.hex2

    if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M2-Planet.hex2; then
      echo "M2-Planet hex2 contains untranslated M1 tokens" >&2
      exit 1
    fi

    ${phase10-hex2}/bin/hex2 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f M2-Planet.hex2 \
      -o M2-Planet
    ${phase26g-macho-patcher}/bin/macho-patcher m2-segments M2-Planet.hex2 M2-Planet

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=M2-Planet bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x M2-Planet

    source ${darwin.signingUtils}
    sign M2-Planet

    ./M2-Planet --help > help.stdout 2> help.stderr
    grep -q 'Usage: M2-Planet' help.stdout

    cat > trivial.c <<'C'
    int main(){return 0;}
    C
    ./M2-Planet -f trivial.c -o trivial.M1
    grep -q ':FUNCTION_main' trivial.M1

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 M2-Planet $out/bin/M2-Planet
    install -Dm644 M2-Planet.M1 $out/share/darwin-bootstrap/M2-Planet.M1
    install -Dm644 M2-Planet.hex2 $out/share/darwin-bootstrap/M2-Planet.hex2
    runHook postInstall
  '';

  meta = {
    description = "Signed Darwin Mach-O phase-12 AMD64 full M2-Planet";
    platforms = [ "x86_64-darwin" ];
  };
}
