## m1-split — M1 code/data section splitter, M2-Planet-built so it exists
## before tinycc-darwin-cc's first link (no awk fallback in the chain).
{
  darwin,
  mkDarwin,
  hex2,
  macho-patcher,
  m0,
  m2,
  m1,
  root,
  stage0Sources,
  ...
}:
mkDarwin {
  pname = "m1-split";
  buildPhase = ''
    runHook preBuild

    ${m2}/bin/M2-darwin \
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
      -f ${root + "/bootstrap/m1-split.c"} \
      -o m1-split.M1

    ${m1}/bin/M1 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f m1-split.M1 \
      -o m1-split.hex2

    ${hex2}/bin/hex2 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f m1-split.hex2 \
      -o m1-split
    ${macho-patcher}/bin/macho-patcher m2-segments m1-split.hex2 m1-split

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=m1-split bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x m1-split

    source ${darwin.signingUtils}
    sign m1-split

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./m1-split --code < ${root + "/mescc-tools/fixtures/m1-split-smoke.M1"} > smoke.code
    cmp smoke.code ${root + "/mescc-tools/fixtures/m1-split-smoke.code.expected"}
    ./m1-split --data < ${root + "/mescc-tools/fixtures/m1-split-smoke.M1"} > smoke.data
    cmp smoke.data ${root + "/mescc-tools/fixtures/m1-split-smoke.data.expected"}
    ./m1-split --data < ${root + "/mescc-tools/fixtures/m1-split-smoke-noeol.M1"} > smoke.noeol
    cmp smoke.noeol ${root + "/mescc-tools/fixtures/m1-split-smoke-noeol.data.expected"}
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 m1-split $out/bin/m1-split
    install -Dm644 m1-split.M1 $out/share/darwin-bootstrap/m1-split.M1
    runHook postInstall
  '';

  meta = {
    description = "M1 code/data splitter for the tcc link path (M2-Planet C build)";
  };
}
