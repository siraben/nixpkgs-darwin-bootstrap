## Early stage0-faithful build of macho-patcher.M1 — uses ONLY M0 +
## phase2-hex2, no M2-Planet involved.  This is the cycle-breaker that
## unlocks replacing scripts/stage0/phase5-amd64-m2.pl in phases 5-10.
##
## How it works:
##   1. Transform tools/macho-patcher.M1's M1-specific raw-byte syntax
##      into M0-friendly macro references:
##        !0xXX             → BYTE_XX
##        %0xNNN            → BYTE_BB BYTE_AA BYTE_NN BYTE_00  (LE bytes)
##      (perl one-liner.  M0 only supports DEFINE-name → bytes; the
##      `!`/`%0xNNN` syntactic shorthands are M1 extensions.)
##   2. Concatenate amd64_defs.M1 + amd64_byte_defs.M1 + transformed
##      source via phase2-catm, run phase3-m0 to expand DEFINEs into
##      hex2 token stream.
##   3. Link via phase2-hex2 against M2libc/amd64/MACHO-amd64.hex2
##      template, pad to linkedit offset, install unsigned.
##
## Verified: the resulting binary is byte-identical to the regular
## phase26g-macho-patcher build (which uses phase9-m1 + phase10-hex2,
## requires phase5-m2 → phase4-cc-arch — the cycle this phase avoids).
args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase11e-macho-patcher-early-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ perl ];

        buildPhase = ''
          runHook preBuild

          ## Transform M1 → M0 source: !0xXX → BYTE_XX, %0xNNN → 4 BYTE_*.
          perl -pe '
            s/!0x([0-9a-fA-F])([0-9a-fA-F])/sprintf("BYTE_%s%s", uc($1), uc($2))/ge;
            s{%0x([0-9a-fA-F]+)}{
              my $v = hex($1);
              sprintf("BYTE_%02X BYTE_%02X BYTE_%02X BYTE_%02X",
                $v & 0xFF, ($v >> 8) & 0xFF, ($v >> 16) & 0xFF, ($v >> 24) & 0xFF)
            }ge;
          ' ${root + "/tools/macho-patcher.M1"} > macho-patcher-m0.M1

          ${phase2-catm}/bin/catm-darwin combined.M0 \
            ${root + "/M2libc/amd64/amd64_defs.M1"} \
            ${root + "/M2libc/amd64/amd64_byte_defs.M1"} \
            macho-patcher-m0.M1

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
          install -Dm644 macho-patcher-m0.M1 $out/share/darwin-bootstrap/macho-patcher-m0.M1
          install -Dm644 combined.M0 $out/share/darwin-bootstrap/combined.M0
          install -Dm644 combined.hex2 $out/share/darwin-bootstrap/combined.hex2
          runHook postInstall
        '';

        meta = {
          description = "Darwin Mach-O macho-patcher (m2-segments mode), assembled via M0+phase2-hex2 — bypasses phase5-m2 dependency cycle";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null
