args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase2-hex2-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ perl ];

        buildPhase = ''
          runHook preBuild

          perl ${root + "/scripts/stage0/phase2-amd64-hex2.pl"} \
            ${stage0Sources} \
            ${phase1-hex1}/bin/hex1-darwin \
            .

          source ${darwin.signingUtils}
          sign hex2-darwin

          cat > labels.hex2 <<'HEX2'
          :hello
          48 69 0a
          HEX2
          printf 'Hi\n' > expected
          ./hex2-darwin labels.hex2 labels-output
          cmp expected labels-output

          cat > pointer.hex2 <<'HEX2'
          :s
          %s
          HEX2
          printf '\xfc\xff\xff\xff' > pointer-expected
          ./hex2-darwin pointer.hex2 pointer-output
          cmp pointer-expected pointer-output

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 hex2-darwin $out/bin/hex2-darwin
          install -Dm644 hex2_AMD64_darwin_body.hex1 $out/share/darwin-bootstrap/hex2_AMD64_darwin_body.hex1
          runHook postInstall
        '';

        meta = {
          description = "Runnable signed Darwin Mach-O phase-2 AMD64 hex2";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null
