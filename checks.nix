{
  arch,
  darwin,
  gnu-hello-hash-comparison,
  hex0,
  hostPlatform,
  lib,
  phase37-gcc46-bootstrap,
  raw-syscall-hello,
  raw-syscall-hello-unsigned,
  root,
  runCommand,
  stage0-posix,
  stage0Sources,
  stdenv,
  ...
}:
{
  hex0-converts-hex = runCommand "hex0-converts-hex" { } ''
    cp ${root + "/fixtures/checks-input.hex0"} input.hex0
    ${hex0}/bin/hex0 input.hex0 output
    test "$(cat output)" = "hello"
    ${hex0}/bin/hex0 ${hex0}/share/darwin-bootstrap/hex0-amd64-darwin.hex0 hex0-self
    cmp ${hex0}/bin/hex0 hex0-self
    mkdir $out
  '';

  raw-syscall-hello-runs = runCommand "raw-syscall-hello-runs" { } ''
    output="$(${raw-syscall-hello}/bin/raw-syscall-hello)"
    test "$output" = "hello darwin"
    mkdir $out
  '';

  xcode-signing-bridge = runCommand "xcode-signing-bridge" { } ''
    source ${darwin.signingUtils}

    cp ${raw-syscall-hello-unsigned}/bin/raw-syscall-hello ./raw-syscall-hello
    chmod +w ./raw-syscall-hello
    sign ./raw-syscall-hello

    output="$(./raw-syscall-hello)"
    test "$output" = "hello darwin"
    mkdir $out
  '';

  ## Confirm M2libc/{amd64,aarch64} are properly ported to Darwin syscalls.
  ## Pure grep-based check; fast.
  m2libc-darwin-smoke = runCommand "m2libc-darwin-smoke" { } ''
    for source in ${./M2libc + "/aarch64/Darwin/bootstrap.c"} ${./M2libc + "/aarch64/libc-core-Darwin.M1"}; do
      if grep -q 'mov_x8,' "$source"; then
        echo "$source still uses the Linux aarch64 syscall register" >&2
        exit 1
      fi
    done

    if grep -q 'ldr_x0,\[x18\]' ${./M2libc + "/aarch64/libc-core-Darwin.M1"}; then
      echo "aarch64 Darwin startup still reads argc from the Linux initial stack" >&2
      exit 1
    fi
    grep -q 'mov_x14,x0' ${./M2libc + "/aarch64/libc-core-Darwin.M1"}
    grep -q 'mov_x15,x1' ${./M2libc + "/aarch64/libc-core-Darwin.M1"}
    grep -q 'DEFINE svc_0 011000d4' ${./M2libc + "/aarch64/aarch64_defs.M1"}

    for source in ${./M2libc + "/amd64/Darwin/bootstrap.c"} ${./M2libc + "/amd64/libc-core-Darwin.M1"}; do
      if grep -q 'mov_rax, %0x3C\|mov_rax, %[0-9][^x]' "$source"; then
        echo "$source still uses an unclassified Linux syscall number" >&2
        exit 1
      fi
    done

    for token in \
      'mov_x16,1' \
      'mov_x16,3' \
      'mov_x16,4' \
      'mov_x16,5' \
      'mov_x16,6' \
      'mov_x16,17'
    do
      grep -q "DEFINE $token " ${./M2libc + "/aarch64/aarch64_defs.M1"}
    done

    for source in \
      ${./M2libc + "/aarch64/MACHO-aarch64.hex2"} \
      ${./M2libc + "/amd64/MACHO-amd64.hex2"}
    do
      grep -q ':MACHO_base' "$source"
      grep -q ':MACHO_text' "$source"
      grep -q '2f 75 73 72 2f 6c 69 62' "$source"
      grep -q '6c 69 62 53 79 73 74' "$source"
    done

    mkdir $out
  '';

  ## Build a tiny hello world via the MACHO-${arch}.hex2 template + the
  ## C hex2 linker from upstream stage0, sign it, and run it.  Verifies
  ## that our committed Mach-O templates are still well-formed Mach-O
  ## that LC_MAIN can launch.
  macho-template-hello-runs = stdenv.mkDerivation {
    name = "macho-template-hello-runs";

    dontUnpack = true;
    strictDeps = true;

    buildPhase = ''
      runHook preBuild

      $CC -I${stage0Sources} -o hex2 \
        ${stage0Sources}/M2libc/bootstrappable.c \
        ${stage0Sources}/mescc-tools/hex2_linker.c \
        ${stage0Sources}/mescc-tools/hex2_word.c \
        ${stage0Sources}/mescc-tools/hex2.c

      ${lib.optionalString hostPlatform.isAarch64 ''
        cp ${root + "/fixtures/checks-hello.hex2"} hello.hex2
        ./hex2 --architecture aarch64 --little-endian \
          --base-address 0x100000000 \
          -f ${./M2libc + "/aarch64/MACHO-aarch64.hex2"} \
          -f hello.hex2 \
          -o hello

        currentSize="$(wc -c < hello | tr -d ' ')"
        if [ "$currentSize" -gt 16777216 ]; then
          echo "Mach-O template __LINKEDIT offset is before end of text" >&2
          exit 1
        fi

        dd if=/dev/zero of=hello bs=1 count=1 seek=16777215 conv=notrunc
        chmod +x hello

        source ${darwin.signingUtils}
        sign hello

        output="$(./hello)"
        test "$output" = "hello darwin"
      ''}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir $out
      runHook postInstall
    '';
  };

  stage0-posix-phase-graph = runCommand "stage0-posix-phase-graph" { } ''
    test ${lib.escapeShellArg (toString stage0-posix.sameLengthAsLinuxMesccToolsBoot)} = 1
    test ${lib.escapeShellArg (toString (builtins.length stage0-posix.missingCriticalPath))} -eq 3
    test ${lib.escapeShellArg stage0-posix.m2libcOS} = Darwin
    test ${lib.escapeShellArg stage0-posix.executableHeader} = MACHO-${stage0-posix.m2libcArch}.hex2
    if grep -q '/linux/' ${./stage0-posix/mescc-tools-boot.nix}; then
      echo "Darwin mescc-tools-boot still references Linux M2libc paths" >&2
      exit 1
    fi
    mkdir $out
  '';
} // lib.optionalAttrs (phase37-gcc46-bootstrap != null) {
  gcc46-bootstrap-smoke = phase37-gcc46-bootstrap;
} // lib.optionalAttrs (gnu-hello-hash-comparison != null) {
  gnu-hello-hash-comparison = gnu-hello-hash-comparison;
}
