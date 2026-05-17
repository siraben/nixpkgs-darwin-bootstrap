args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase3-m0-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          python3 ${root + "/tools/phase3-amd64-m0.py"} ${stage0Sources} .
          ${phase2-catm}/bin/catm-darwin M0-darwin.hex2 \
            MACHO-amd64-lowdata.hex2 \
            M0_AMD64_darwin_body.hex2
          ${phase2-hex2}/bin/hex2-darwin M0-darwin.hex2 M0-darwin

          linkeditOffset="$(cat linkedit-offset)"
          dd if=/dev/zero of=M0-darwin bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x M0-darwin

          source ${darwin.signingUtils}
          sign M0-darwin

          cat > smoke.M1 <<'M1'
          :foo
          "AB"
          '43 00'
          M1
          cat > expected <<'HEX2'
          :foo
          414200
          43 00
          HEX2
          ./M0-darwin smoke.M1 smoke.hex2
          cmp expected smoke.hex2

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 M0-darwin $out/bin/M0-darwin
          install -Dm644 M0-darwin.hex2 $out/share/darwin-bootstrap/M0-darwin.hex2
          install -Dm644 M0_AMD64_darwin_body.hex2 $out/share/darwin-bootstrap/M0_AMD64_darwin_body.hex2
          install -Dm644 MACHO-amd64-lowdata.hex2 $out/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2
          runHook postInstall
        '';

        meta = {
          description = "Runnable signed Darwin Mach-O phase-3 AMD64 M0";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null
