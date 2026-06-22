## macho-patcher-early — Darwin macho-patcher, built live from source.
##
## The cycle-breaker: builds the macho-patcher (m2-segments mode) using ONLY
## M0 + the seed-built hex2, no M2-Planet, so it exists before cc-arch/M2.
##   1. catm concatenates the committed M1 sources amd64_defs.M1 +
##      amd64_byte_defs.M1 + the M0-friendly tools/macho-patcher-m0.M1.
##   2. M0 expands them into a hex2 token stream.
##   3. catm prepends the committed MACHO-amd64.hex2 template; the seed-built
##      hex2 links it; dd pads to the LINKEDIT offset.  Runs unsigned.
## All translation is done by chain-built tools (catm, M0, hex2); stdenv only
## orchestrates.  No committed binary dump.
##
## The M0-form of macho-patcher is regenerated from tools/macho-patcher.M1 by
## the maintainer via scripts/stage0/regen-macho-patcher-seed.sh; build-time
## has no awk/perl/python.
{
  mkDarwin,
  catm,
  m0,
  hex2-0,
  root,
  ...
}:

mkDarwin {
  pname = "macho-patcher-early";
  version = "0-unstable-2026-05-27";

  buildPhase = ''
    runHook preBuild

    ${catm}/bin/catm-darwin combined.M0 \
      ${root + "/M2libc/amd64/amd64_defs.M1"} \
      ${root + "/M2libc/amd64/amd64_byte_defs.M1"} \
      ${root + "/tools/macho-patcher-m0.M1"}

    ${m0}/bin/M0-darwin combined.M0 combined.hex2

    ## hex2 here takes positional args only; MACHO-amd64.hex2 already encodes
    ## base=0x1000000 inline, so pre-concatenate template + body with catm.
    ${catm}/bin/catm-darwin final.hex2 \
      ${root + "/M2libc/amd64/MACHO-amd64.hex2"} \
      combined.hex2

    ${hex2-0}/bin/hex2-darwin final.hex2 macho-patcher

    dd if=/dev/zero of=macho-patcher bs=1 count=1 seek="$((0x2800000 - 1))" conv=notrunc
    chmod +x macho-patcher

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 macho-patcher $out/bin/macho-patcher
    install -Dm644 combined.M0 $out/share/darwin-bootstrap/combined.M0
    install -Dm644 combined.hex2 $out/share/darwin-bootstrap/combined.hex2
    runHook postInstall
  '';

  meta = {
    description = "Darwin Mach-O macho-patcher (m2-segments), assembled via M0 + chain hex2 — breaks the M2-Planet dependency cycle";
  };
}
