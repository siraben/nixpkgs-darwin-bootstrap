## Early stage0-faithful build of macho-patcher.M1 — uses ONLY M0 +
## phase2-hex2, no M2-Planet involved.  This is the cycle-breaker that
## unlocks replacing scripts/stage0/phase5-amd64-m2.pl in phases 5-10.
##
## How it works:
##   1. Use tools/macho-patcher-m0.M1 — the committed M0-friendly form of
##      tools/macho-patcher.M1 (canonical source uses M1-only `!0xXX`/
##      `%0xNNN` shortcuts; the M0-form expands them to BYTE_XX macros
##      from amd64_byte_defs.M1).  Maintainer regenerates the M0-form
##      via scripts/stage0/regen-preported.sh whenever macho-patcher.M1
##      changes.  Build-time has no awk/perl/python here.
##   2. Concatenate amd64_defs.M1 + amd64_byte_defs.M1 + M0-form via
##      phase2-catm, run phase3-m0 to expand DEFINEs into hex2 token
##      stream.
##   3. Link via phase2-hex2 against M2libc/amd64/MACHO-amd64.hex2
##      template, pad to linkedit offset, install unsigned.
##
## Verified: the resulting binary is byte-identical to the regular
## phase26g-macho-patcher build (which uses phase9-m1 + phase10-hex2,
## requires phase5-m2 → phase4-cc-arch — the cycle this phase avoids).
{
  mkDarwin,
  perl,
  phase10-hex2,
  phase11e-macho-patcher-early,
  phase2-catm,
  phase2-hex2,
  phase26g-macho-patcher,
  phase3-m0,
  phase4-cc-arch,
  phase5-m2,
  phase9-m1,
  root,
  source,
  ...
}:
mkDarwin {
  pname = "phase11e-macho-patcher-early";
  buildPhase = ''
    runHook preBuild

    ## Use the committed M0-form of macho-patcher (canonical source
    ## tools/macho-patcher.M1 uses M1-only `!0xXX`/`%0xNNN` shortcuts
    ## that M0 doesn't parse; the M0-form expands them to BYTE_XX
    ## macros from amd64_byte_defs.M1).  Maintainer regenerates via
    ## scripts/stage0/regen-preported.sh whenever macho-patcher.M1
    ## changes; build-time has no awk/perl/python here.

    ${phase2-catm}/bin/catm-darwin combined.M0 \
      ${root + "/M2libc/amd64/amd64_defs.M1"} \
      ${root + "/M2libc/amd64/amd64_byte_defs.M1"} \
      ${root + "/tools/macho-patcher-m0.M1"}

    ${phase3-m0}/bin/M0-darwin combined.M0 combined.hex2

    ## phase2-hex2-darwin takes positional args only (no -f, no
    ## --base-address) — pre-concatenate template + body with catm.
    ## MACHO-amd64.hex2 already encodes base=0x1000000 inline; no
    ## flag needed.  Verified byte-identical to phase26g output
    ## (which uses phase10-hex2 -f -f --base-address 0x1000000).
    ${phase2-catm}/bin/catm-darwin final.hex2 \
      ${root + "/M2libc/amd64/MACHO-amd64.hex2"} \
      combined.hex2

    ${phase2-hex2}/bin/hex2-darwin final.hex2 macho-patcher

    linkeditOffset="$((0x800000 + 0x2000000))"
    dd if=/dev/zero of=macho-patcher bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
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
    description = "Darwin Mach-O macho-patcher (m2-segments mode), assembled via M0+phase2-hex2 — bypasses phase5-m2 dependency cycle";
  };
}
