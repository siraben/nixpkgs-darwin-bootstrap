args:
with args;
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase4-cc-arch-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ perl ];

        ## NOTE: phase11d-cc-arch-helper is the M2-Planet C version of
        ## scripts/stage0/phase4-amd64-cc-arch.pl and is byte-identical
        ## to the perl on real cc_arch-0-linux.hex2 + cc_arch-darwin
        ## inputs (verified, see bootstrap/phase4-amd64-cc-arch.c).  It
        ## CAN'T be used here though: phase11d → phase5-m2 → phase4-
        ## cc-arch → phase11d would be a Nix-eval cycle.  Breaking the
        ## cycle needs either pre-porting cc_arch-0.hex2 into the tree
        ## (60KB committed) or rewriting the helper in hex0/M0-only so
        ## it can be assembled before phase5-m2 exists.
        buildPhase = ''
          runHook preBuild

          # Use the committed pre-ported Darwin source (cc_amd64.M1 →
          # M0 expand → port).  Maintainer regenerates via
          # scripts/stage0/regen-preported.sh whenever stage0Sources is
          # bumped; build-time has no awk/perl/python for port step.
          cp ${root + "/M2libc/amd64/cc_arch-0-darwin.hex2"} cc_arch-0.hex2
          ${phase2-catm}/bin/catm-darwin cc_arch.hex2 \
            ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            cc_arch-0.hex2
          ${phase2-hex2}/bin/hex2-darwin cc_arch.hex2 cc_arch-darwin
          perl ${root + "/scripts/stage0/phase4-amd64-cc-arch.pl"} patch cc_arch-0.hex2 cc_arch-darwin

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=cc_arch-darwin bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x cc_arch-darwin

          source ${darwin.signingUtils}
          sign cc_arch-darwin

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 cc_arch-darwin $out/bin/cc_arch-darwin
          install -Dm644 cc_arch.hex2 $out/share/darwin-bootstrap/cc_arch.hex2
          install -Dm644 cc_arch-0.hex2 $out/share/darwin-bootstrap/cc_arch-0.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-4 AMD64 cc_arch";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null
