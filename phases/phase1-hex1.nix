args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase1-hex1-amd64";
        version = "0-unstable-2026-05-07.1";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ perl ];

        buildPhase = ''
          runHook preBuild

          perl ${root + "/scripts/stage0/phase1-amd64-hex1.pl"} \
            ${stage0Sources} \
            ${hex0}/bin/hex0 \
            .

          source ${darwin.signingUtils}
          sign hex1-darwin

          cat > input.hex1 <<'HEX1'
          48 69 0a
          HEX1
          printf 'Hi\n' > expected
          ./hex1-darwin input.hex1 output
          cmp expected output

          cat > labels.hex1 <<'HEX1'
          :s
          48 69 0a
          HEX1
          ./hex1-darwin labels.hex1 labels-output
          cmp expected labels-output

          cat > pointer.hex1 <<'HEX1'
          :s
          %s
          HEX1
          printf '\xfc\xff\xff\xff' > pointer-expected
          ./hex1-darwin pointer.hex1 pointer-output
          cmp pointer-expected pointer-output

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 hex1-darwin $out/bin/hex1-darwin
          install -Dm644 hex1_AMD64_darwin_body.hex0 $out/share/darwin-bootstrap/hex1_AMD64_darwin_body.hex0
          runHook postInstall
        '';

        meta = {
          description = "Runnable signed Darwin Mach-O phase-1 AMD64 hex1";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else if hostPlatform.isAarch64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase1-hex1";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        strictDeps = true;

        nativeBuildInputs = [ perl ];

        buildPhase = ''
          runHook preBuild

          awk 'seen { print } /^#:ELF_text/ { seen = 1 }' \
            ${stage0Sources}/AArch64/hex1_AArch64.hex0 > hex1-body.hex0

          bash ${root + "/scripts/stage0/phase1-aarch64-hex1-darwin.sh"}

          grep -v '^:' ${root + "/M2libc"}/aarch64/MACHO-aarch64.hex2 > hex1-darwin.hex0
          cat hex1-body.hex0 >> hex1-darwin.hex0

          ${hex0}/bin/hex0 hex1-darwin.hex0 hex1-darwin

          currentSize="$(wc -c < hex1-darwin | tr -d ' ')"
          if [ "$currentSize" -gt 16777216 ]; then
            echo "phase1 hex1 candidate exceeds reserved __TEXT before __LINKEDIT" >&2
            exit 1
          fi

          dd if=/dev/zero of=hex1-darwin bs=1 count=1 seek=16777215 conv=notrunc
          chmod +x hex1-darwin

          source ${darwin.signingUtils}
          sign hex1-darwin

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 hex1-darwin $out/bin/hex1-darwin
          install -Dm644 hex1-darwin.hex0 $out/share/darwin-bootstrap/hex1_AArch64_darwin.hex0
          install -Dm644 hex1-body.hex0 $out/share/darwin-bootstrap/hex1_AArch64_darwin_body.hex0
          cat > $out/share/darwin-bootstrap/README <<'EOF'
          This is the signed Darwin phase-1 hex1 candidate generated from
          upstream AArch64/hex1_AArch64.hex0 with syscall, LC_MAIN argv, and
          Mach-O header adaptations. It builds and signs, but is not promoted to
          the trusted chain until its ELF-era writable data model is fully
          replaced.
          EOF
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-1 hex1 candidate";
          platforms = [ "aarch64-darwin" ];
        };
      }
    else
      null
