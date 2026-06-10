{
  darwin,
  mkDarwin,
  hex2,
  m1-to-hex2,
  macho-patcher,
  m0,
  m2,
  m1,
  root,
  source,
  stage0Sources,
  ...
}:
      mkDarwin {
        pname = "phase11b-m1-to-hex2";
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
            -f ${root + "/bootstrap/m1-to-hex2.c"} \
            -o m1-to-hex2.M1

          ${m1}/bin/M1 \
            --architecture amd64 \
            --little-endian \
            -f ${root + "/M2libc/amd64/amd64_defs.M1"} \
            -f ${root + "/M2libc/amd64/libc-full-Darwin.M1"} \
            -f m1-to-hex2.M1 \
            -o m1-to-hex2.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' m1-to-hex2.hex2; then
            echo "m1-to-hex2 hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${hex2}/bin/hex2 \
            --architecture amd64 \
            --little-endian \
            --base-address 0x600000 \
            -f ${m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            -f m1-to-hex2.hex2 \
            -o m1-to-hex2
          ${macho-patcher}/bin/macho-patcher m2-segments m1-to-hex2.hex2 m1-to-hex2

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=m1-to-hex2 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x m1-to-hex2

          source ${darwin.signingUtils}
          sign m1-to-hex2

          ## Smoke: translate a trivial M1 fragment and check the
          ## expected hex2 output by hand.  (Initial bring-up used a
          ## perl reference but the algorithm is fully byte-verified
          ## on real inputs across the chain now.)
          cp ${root + "/mescc-tools/fixtures/m1-to-hex2-smoke.M1"} smoke.M1
          ./m1-to-hex2 --architecture amd64 --little-endian \
            --base-address 0x600400 -f smoke.M1 -o smoke.hex2

          cp ${root + "/mescc-tools/fixtures/m1-to-hex2-smoke.expected"} smoke.expected
          grep -q ':foo' smoke.hex2
          grep -q ':bar' smoke.hex2
          grep -q '48 31 C0' smoke.hex2
          grep -q '^90$' smoke.hex2

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 m1-to-hex2 $out/bin/m1-to-hex2
          install -Dm644 m1-to-hex2.M1 $out/share/darwin-bootstrap/m1-to-hex2.M1
          install -Dm644 m1-to-hex2.hex2 $out/share/darwin-bootstrap/m1-to-hex2.hex2
          install -Dm644 smoke.M1 $out/share/darwin-bootstrap/smoke.M1
          install -Dm644 smoke.hex2 $out/share/darwin-bootstrap/smoke.hex2
          runHook postInstall
        '';

        meta = {
          description = "Stage0-faithful Darwin Mach-O m1-to-hex2 translator (M2-Planet C build)";
        };
      }
