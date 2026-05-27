args:
with args;
stdenv.mkDerivation {
  pname = "darwin-minimal-bootstrap-phase11c-hex2-data-relocs-amd64";
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
      -f ${stage0Sources}/M2libc/ctype.c \
      -f ${stage0Sources}/M2libc/stdlib.c \
      -f ${stage0Sources}/M2libc/string.c \
      -f ${stage0Sources}/M2libc/stdarg.h \
      -f ${stage0Sources}/M2libc/stdio.h \
      -f ${stage0Sources}/M2libc/stdio.c \
      -f ${stage0Sources}/M2libc/bootstrappable.c \
      -f ${root + "/bootstrap/hex2-data-relocs.c"} \
      -o hex2-data-relocs.M1

    ${phase9-m1}/bin/M1 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f hex2-data-relocs.M1 \
      -o hex2-data-relocs.hex2

    ${phase10-hex2}/bin/hex2 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f hex2-data-relocs.hex2 \
      -o hex2-data-relocs
    ${phase26g-macho-patcher}/bin/macho-patcher m2-segments hex2-data-relocs.hex2 hex2-data-relocs

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=hex2-data-relocs bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x hex2-data-relocs

    source ${darwin.signingUtils}
    sign hex2-data-relocs

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hex2-data-relocs $out/bin/hex2-data-relocs
    runHook postInstall
  '';

  meta = {
    description = "Stage0-faithful Darwin Mach-O hex2-data-relocs patcher (M2-Planet C build)";
    platforms = [ "x86_64-darwin" ];
  };
}
