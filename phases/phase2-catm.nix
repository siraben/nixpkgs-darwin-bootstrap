args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase2-catm-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          python3 ${root + "/tools/phase2-amd64-catm.py"} \
            ${stage0Sources} \
            ${phase2-hex2}/bin/hex2-darwin \
            .

          source ${darwin.signingUtils}
          sign catm-darwin

          printf foo > a
          printf bar > b
          printf foobar > expected
          ./catm-darwin output a b
          cmp expected output

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 catm-darwin $out/bin/catm-darwin
          install -Dm644 catm_AMD64_darwin_body.hex2 $out/share/darwin-bootstrap/catm_AMD64_darwin_body.hex2
          runHook postInstall
        '';

        meta = {
          description = "Runnable signed Darwin Mach-O phase-2 AMD64 catm";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null
