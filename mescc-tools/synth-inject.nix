## synth-inject — cross-object synth-label injector, M2-Planet-built so it exists
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
  pname = "synth-inject";
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
      -f ${root + "/bootstrap/synth-inject.c"} \
      -o synth-inject.M1

    ${m1}/bin/M1 \
      --architecture amd64 \
      --little-endian \
      -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
      -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
      -f synth-inject.M1 \
      -o synth-inject.hex2

    ${hex2}/bin/hex2 \
      --architecture amd64 \
      --little-endian \
      --base-address 0x600000 \
      -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      -f synth-inject.hex2 \
      -o synth-inject
    ${macho-patcher}/bin/macho-patcher m2-segments synth-inject.hex2 synth-inject

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=synth-inject bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x synth-inject

    source ${darwin.signingUtils}
    sign synth-inject

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ./synth-inject ${root + "/mescc-tools/fixtures/synth-inject-smoke.M1"} > smoke.out
    cmp smoke.out ${root + "/mescc-tools/fixtures/synth-inject-smoke.expected"}
    ## no-op path: a stream with no undefined synth refs passes through
    ./synth-inject ${root + "/mescc-tools/fixtures/synth-inject-noop.M1"} > noop.out
    cmp noop.out ${root + "/mescc-tools/fixtures/synth-inject-noop.expected"}
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 synth-inject $out/bin/synth-inject
    install -Dm644 synth-inject.M1 $out/share/darwin-bootstrap/synth-inject.M1
    runHook postInstall
  '';

  meta = {
    description = "Cross-object synth-label injector for the tcc link path (M2-Planet C build)";
  };
}
