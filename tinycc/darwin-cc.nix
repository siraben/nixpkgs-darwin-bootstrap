{
  cctools,
  darwin,
  hex2,
  m1-to-hex2,
  m1-split,
  synth-inject,
  elf64-to-m1,
  m0,
  tinycc-self-link-candidate,
  tinycc-darwin-cc,
  tinycc-boot3-link-candidate,
  root,
  runCommand,
  stdenv,
  ...
}:
runCommand "tinycc-darwin-cc" { } ''
  mkdir -p $out/bin $out/include/tcc-darwin-bootstrap/sys $out/share/darwin-bootstrap

  cp -R ${root + "/bootstrap/headers/tcc-darwin-bootstrap"}/. \
    $out/include/tcc-darwin-bootstrap/

  ${tinycc-self-link-candidate}/bin/tcc-self-candidate -c \
    ${root + "/bootstrap/tinycc-sysv-libc.c"} \
    -o tinycc-sysv-libc.o \
    > tinycc-sysv-libc.stdout \
    2> tinycc-sysv-libc.stderr
  ${elf64-to-m1}/bin/elf64-to-m1 --prefix tinycc_sysv_libc_ \
    tinycc-sysv-libc.o \
    tinycc-sysv-libc.M1

  cp ${root + "/scripts/tinycc/crt1-tcc-sysv.M1"} crt1-tcc-sysv.M1

  ## Two Mach-O layout templates derived from MACHO-amd64-lowdata.hex2
  ## (7 segment-field substitutions each), committed under M2libc/amd64/.
  ## tcc-darwin-cc tries the SMALL layout first (fast, minimal text
  ## padding) and falls back to LARGE only when a binary's text overruns
  ## it (e.g. gcc-4.6 cc1plus).  The committed copies must stay in sync
  ## with the m0 template: verified by line count and shared lines here.
  lowdata=${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2
  for tpl in ${root + "/M2libc/amd64/MACHO-amd64-smalldata.hex2"} ${root + "/M2libc/amd64/MACHO-amd64-largedata.hex2"}; do
    test "$(wc -l < "$tpl")" = "$(wc -l < "$lowdata")"
    test "$(sed -n 1p "$tpl")" = "$(sed -n 1p "$lowdata")"
    test "$(sed -n 30p "$tpl")" = "$(sed -n 30p "$lowdata")"
  done
  cp ${root + "/M2libc/amd64/MACHO-amd64-smalldata.hex2"} $out/share/darwin-bootstrap/MACHO-amd64-smalldata.hex2
  cp ${root + "/M2libc/amd64/MACHO-amd64-largedata.hex2"} $out/share/darwin-bootstrap/MACHO-amd64-largedata.hex2

  cp crt1-tcc-sysv.M1 tinycc-sysv-libc.M1 $out/share/darwin-bootstrap/

  cp ${root + "/scripts/tinycc/tcc-darwin-cc.sh"} $out/bin/tcc-darwin-cc
  chmod u+w $out/bin/tcc-darwin-cc

  substituteInPlace $out/bin/tcc-darwin-cc \
    --replace-fail @SHELL@ ${stdenv.shell} \
    --replace-fail @TCC@ ${tinycc-boot3-link-candidate}/bin/tcc-boot3-candidate \
    --replace-fail @AR@ ${cctools}/bin/ar \
    --replace-fail @INCLUDE@ $out/include/tcc-darwin-bootstrap \
    --replace-fail @ELF_TO_M1@ ${elf64-to-m1}/bin/elf64-to-m1 \
    --replace-fail @M1_TO_HEX2@ ${m1-to-hex2}/bin/m1-to-hex2 \
    --replace-fail @HEX2@ ${hex2}/bin/hex2 \
    --replace-fail @MACHO@ $out/share/darwin-bootstrap/MACHO-amd64-largedata.hex2 \
    --replace-fail @CRT1@ $out/share/darwin-bootstrap/crt1-tcc-sysv.M1 \
    --replace-fail @SYSCALLS@ ${root + "/bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1"} \
    --replace-fail @LIBC_M1@ $out/share/darwin-bootstrap/tinycc-sysv-libc.M1 \
    --replace-fail @M1_SPLIT@ ${m1-split}/bin/m1-split \
    --replace-fail @SYNTH_INJECT_BIN@ ${synth-inject}/bin/synth-inject \
    --replace-fail @SIGNING@ ${darwin.signingUtils}
  chmod +x $out/bin/tcc-darwin-cc

  ## m1-split + synth-inject are M2-Planet-built (mescc-tools/) and exist
  ## before this wrapper's first link; the wrapper has no awk path.
  ${m1-split}/bin/m1-split --code \
    < ${root + "/mescc-tools/fixtures/m1-split-smoke.M1"} > split-code.out
  cmp split-code.out ${root + "/mescc-tools/fixtures/m1-split-smoke.code.expected"}
  ${synth-inject}/bin/synth-inject \
    ${root + "/mescc-tools/fixtures/synth-inject-smoke.M1"} > synth-c.out
  cmp synth-c.out ${root + "/mescc-tools/fixtures/synth-inject-smoke.expected"}
  cp split-code.out synth-c.out $out/share/darwin-bootstrap/

  cp ${root + "/scripts/tinycc/selftest/hello.c"} hello.c
  $out/bin/tcc-darwin-cc hello.c -o hello
  set +e
  ./hello
  status="$?"
  set -e
  test "$status" = 42

  cp ${root + "/scripts/tinycc/selftest/data-reloc.c"} data-reloc.c
  $out/bin/tcc-darwin-cc data-reloc.c -o data-reloc
  ./data-reloc

  cp ${root + "/scripts/tinycc/selftest/function-reloc.c"} function-reloc.c
  $out/bin/tcc-darwin-cc function-reloc.c -o function-reloc
  ./function-reloc

  cp ${root + "/scripts/tinycc/selftest/string-reloc.c"} string-reloc.c
  $out/bin/tcc-darwin-cc string-reloc.c -o string-reloc
  test "$(./string-reloc)" = FIRSTSECOND

  $out/bin/tcc-darwin-cc -c hello.c -o hello.o
  test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

  cp tinycc-sysv-libc.o tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
    hello.c hello data-reloc.c data-reloc function-reloc.c function-reloc \
    string-reloc.c string-reloc hello.o \
    $out/share/darwin-bootstrap/
''
