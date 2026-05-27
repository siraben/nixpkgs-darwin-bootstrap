{
  darwin,
  mkDarwin,
  phase10-hex2,
  phase11d-cc-arch-helper,
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
  pname = "phase11d-cc-arch-helper";
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
      -f ${root + "/bootstrap/phase4-amd64-cc-arch.c"} \
      -o phase4-cc-arch-helper.M1

    ${phase9-m1}/bin/M1 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f phase4-cc-arch-helper.M1 \
      -o phase4-cc-arch-helper.hex2

    ${phase10-hex2}/bin/hex2 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f phase4-cc-arch-helper.hex2 \
      -o phase4-cc-arch-helper
    ${phase26g-macho-patcher}/bin/macho-patcher m2-segments phase4-cc-arch-helper.hex2 phase4-cc-arch-helper

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=phase4-cc-arch-helper bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x phase4-cc-arch-helper

    source ${darwin.signingUtils}
    sign phase4-cc-arch-helper

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 phase4-cc-arch-helper $out/bin/phase4-cc-arch-helper
    runHook postInstall
  '';

  meta = {
    description = "Stage0-faithful Darwin Mach-O phase-4 cc-arch port+patch helper (M2-Planet C build)";
  };
}
