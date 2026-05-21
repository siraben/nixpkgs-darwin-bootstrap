args:
with args;
{
  hex0-converts-hex = runCommand "darwin-minimal-bootstrap-hex0-converts-hex" { } ''
    cat > input.hex0 <<'HEX'
      68 65 6c 6c 6f 0a ; hello newline
    HEX
    ${hex0}/bin/hex0 input.hex0 output
    test "$(cat output)" = "hello"
    ${hex0}/bin/hex0 ${hex0}/share/darwin-bootstrap/hex0-amd64-darwin.hex0 hex0-self
    cmp ${hex0}/bin/hex0 hex0-self
    mkdir $out
  '';

  raw-syscall-hello-runs = runCommand "darwin-minimal-bootstrap-raw-syscall-hello-runs" { } ''
    output="$(${raw-syscall-hello}/bin/raw-syscall-hello)"
    test "$output" = "hello darwin"
    mkdir $out
  '';

  xcode-signing-bridge = runCommand "darwin-minimal-bootstrap-xcode-signing-bridge" { } ''
    source ${darwin.signingUtils}

    cp ${raw-syscall-hello-unsigned}/bin/raw-syscall-hello ./raw-syscall-hello
    chmod +w ./raw-syscall-hello
    sign ./raw-syscall-hello

    output="$(./raw-syscall-hello)"
    test "$output" = "hello darwin"
    mkdir $out
  '';

  m2libc-darwin-smoke = m2libcDarwinSmoke;

  macho-template-hello-runs = machoTemplateHelloRuns;

  stage0-posix-phase-graph = runCommand "darwin-minimal-bootstrap-stage0-posix-phase-graph" { } ''
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
