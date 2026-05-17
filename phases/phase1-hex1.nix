args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase1-hex1-amd64";
        version = "0-unstable-2026-05-07.1";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          python3 ${root + "/tools/phase1-amd64-hex1.py"} \
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

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          awk 'seen { print } /^#:ELF_text/ { seen = 1 }' \
            ${stage0Sources}/AArch64/hex1_AArch64.hex0 > hex1-body.hex0

          python3 <<'PY'
          from pathlib import Path

          path = Path("hex1-body.hex0")
          source = path.read_text()
          replacements = [
              (
                  "E10B40F9",
                  "ef0301aa\n"
                  "000080d2\n"
                  "0102a0d2\n"
                  "620080d2\n"
                  "430082d2\n"
                  "04008092\n"
                  "050080d2\n"
                  "b01880d2\n"
                  "011000d4\n"
                  "ec0300aa\n"
                  "e10540f9",
                  1,
              ),
              ("E10F40F9", "e10940f9", 1),
              ("600C8092", "e00301aa", -1),
              ("020080D2", "010080d2\n020080d2", 1),
              ("224880D2", "21c080d2", -1),
              ("033880D2", "023880d2", -1),
              ("080780D2", "b00080d2", -1),
              ("A80B80D2", "300080d2", -1),
              ("C80780D2", "f01880d2", -1),
              ("E80780D2", "700080d2", -1),
              ("080880D2", "900080d2", -1),
              ("010000D4", "011000d4", -1),
              ("0D0CA0D2", "ed030caa", -1),
          ]

          for old, new, count in replacements:
              if count < 0:
                  source = source.replace(old, new)
              else:
                  source = source.replace(old, new, count)

          path.write_text(source)
          PY

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
