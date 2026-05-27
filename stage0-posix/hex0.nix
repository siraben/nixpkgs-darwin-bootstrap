## hex0 — the Darwin-bootstrap seed assembler.
##
## The smallest tool in the chain.  Builds from hand-written hex0
## source (hex0/hex0-amd64-darwin.hex0 + a 100-line C materializer
## that bootstraps it via $CC).  Once compiled, hex0 self-hosts: it
## re-assembles itself from its own .hex0 source and the build verifies
## byte-identity (`cmp hex0 hex0-self`).
##
## Notes:
##   - Not wrapped by mkDarwin because it's the only stage0 phase that
##     needs an actual src (hex0/ directory) and stdenv's unpackPhase.
##   - passthru.tests reaches into the top-level tests scope via the
##     `tests` argument to expose `nix build .#hex0.tests.converts-hex`.
{
  lib,
  stdenv,
  supportedSystems,
  tests,
}:
stdenv.mkDerivation {
  pname = "hex0";
  version = "0-unstable-2026-05-17";

  src = ../hex0;
  strictDeps = true;
  dontStrip = true;

  buildPhase = ''
    runHook preBuild
    $CC $CFLAGS -o hex0-materializer hex0.c
    ./hex0-materializer hex0-amd64-darwin.hex0 hex0
    chmod +x hex0

    ./hex0 hex0-amd64-darwin.hex0 hex0-self
    cmp hex0 hex0-self

    cat > smoke.hex0 <<'HEX'
      # whitespace, comments, and mixed-case nybbles are intentional
      48 65 6c 6c 6F 0a ; Hello newline
    HEX
    ./hex0 smoke.hex0 smoke.out
    printf 'Hello\n' > smoke.expected
    cmp smoke.expected smoke.out
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 hex0 $out/bin/hex0
    install -Dm644 hex0-amd64-darwin.hex0 $out/share/darwin-bootstrap/hex0-amd64-darwin.hex0
    install -Dm644 hex0-amd64-darwin.S    $out/share/darwin-bootstrap/hex0-amd64-darwin.S
    install -Dm644 README.md              $out/share/darwin-bootstrap/README.hex0.md
    runHook postInstall
  '';

  meta = {
    description = "Darwin hex0 assembler for minimal bootstrap experiments";
    teams = [ lib.teams.minimal-bootstrap ];
    platforms = supportedSystems;
  };

  passthru.tests = {
    converts-hex = tests.hex0-converts-hex;
  };
}
