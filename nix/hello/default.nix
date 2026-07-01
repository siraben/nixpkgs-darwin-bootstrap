## Darwin raw-syscall hello binaries — smallest end-to-end smoke test
## of the Mach-O toolchain.  Builds a tiny assembly source through the
## host toolchain ($CC) to confirm we can produce a runnable Mach-O
## binary that exits 0 and prints "hello darwin" via raw write/exit
## syscalls (no libSystem).
##
## Two outputs:
##   raw-syscall-hello          — default, ad-hoc signed by ld
##   raw-syscall-hello-unsigned — `-Wl,-no_adhoc_codesign`, used by
##                                the xcode-signing-bridge check to
##                                verify our re-signing path
##
## The src parameter resolves to `hello/raw-syscall-${arch}.s` per
## packages.nix.
{
  lib,
  stdenv,
  supportedSystems,
  source,
  tests,
  ...
}:
{
  raw-syscall-hello = stdenv.mkDerivation {
    pname = "raw-syscall-hello";
    version = "0-unstable-2026-05-07";

    dontUnpack = true;
    strictDeps = true;

    buildPhase = ''
      runHook preBuild
      $CC ${source} -o raw-syscall-hello
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 raw-syscall-hello $out/bin/raw-syscall-hello
      runHook postInstall
    '';

    meta = {
      description = "Darwin raw-syscall Mach-O smoke binary for minimal bootstrap experiments";
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = supportedSystems;
    };

    passthru.tests = tests;
  };

  raw-syscall-hello-unsigned = stdenv.mkDerivation {
    pname = "raw-syscall-hello-unsigned";
    version = "0-unstable-2026-05-07";

    dontUnpack = true;
    strictDeps = true;

    buildPhase = ''
      runHook preBuild
      $CC ${source} -Wl,-no_adhoc_codesign -o raw-syscall-hello
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 raw-syscall-hello $out/bin/raw-syscall-hello
      runHook postInstall
    '';

    meta = {
      description = "Unsigned Darwin raw-syscall Mach-O smoke binary for signing bootstrap experiments";
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = supportedSystems;
    };
  };
}
