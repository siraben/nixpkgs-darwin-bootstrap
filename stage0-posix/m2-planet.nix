args:
with args;
mkDarwin {
  pname = "phase5-m2";
  buildPhase = ''
    runHook preBuild

    ${phase2-catm}/bin/catm-darwin M2-0.c \
      ${root + "/M2libc/amd64/Darwin/bootstrap.c"} \
      ${stage0Sources}/M2-Planet/cc.h \
      ${stage0Sources}/M2libc/bootstrappable.c \
      ${stage0Sources}/M2-Planet/cc_globals.c \
      ${stage0Sources}/M2-Planet/cc_reader.c \
      ${stage0Sources}/M2-Planet/cc_strings.c \
      ${stage0Sources}/M2-Planet/cc_types.c \
      ${stage0Sources}/M2-Planet/cc_emit.c \
      ${stage0Sources}/M2-Planet/cc_core.c \
      ${stage0Sources}/M2-Planet/cc_macro.c \
      ${stage0Sources}/M2-Planet/cc.c
    ${phase4-cc-arch}/bin/cc_arch-darwin M2-0.c M2-0.M1
    ${phase2-catm}/bin/catm-darwin M2-0-0.M1 \
      ${root + "/M2libc/amd64/amd64_defs.M1"} \
      ${root + "/M2libc/amd64/libc-core-Darwin.M1"} \
      M2-0.M1
    ${phase3-m0}/bin/M0-darwin M2-0-0.M1 M2-0.hex2

    if grep -q 'sub_rdi\|lea_r9\|DWORD\|DEFINE' M2-0.hex2; then
      echo "M2 hex2 contains untranslated M1 tokens" >&2
      exit 1
    fi

    ${phase2-catm}/bin/catm-darwin M2-0-0.hex2 \
      ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
      M2-0.hex2
    ${phase2-hex2}/bin/hex2-darwin M2-0-0.hex2 M2-darwin
    ${phase11e-macho-patcher-early}/bin/macho-patcher m2-segments M2-0.hex2 M2-darwin

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=M2-darwin bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
    chmod +x M2-darwin

    source ${darwin.signingUtils}
    sign M2-darwin

    set +e
    ./M2-darwin > no-input.stdout 2> no-input.stderr
    status="$?"
    set -e
    test "$status" -eq 1
    grep -q 'Either no input files were given or they were empty' no-input.stderr

    ./M2-darwin --help > help.stdout 2> help.stderr
    grep -q 'Usage: M2-Planet' help.stdout

    cat > trivial.c <<'C'
    int main(){return 0;}
    C
    ./M2-darwin -f trivial.c -o trivial.M1
    grep -q ':FUNCTION_main' trivial.M1

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 M2-darwin $out/bin/M2-darwin
    install -Dm644 M2-0.M1 $out/share/darwin-bootstrap/M2-0.M1
    install -Dm644 M2-0.hex2 $out/share/darwin-bootstrap/M2-0.hex2
    runHook postInstall
  '';

  meta = {
    description = "Signed Darwin Mach-O phase-5 AMD64 M2-Planet candidate";
  };
}
