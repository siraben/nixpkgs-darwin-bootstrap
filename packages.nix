{
  darwin,
  lib,
  minimal-bootstrap-sources,
  python3,
  stdenv,
  runCommand,
}:

let
  hostPlatform = stdenv.hostPlatform;

  supportedSystems = [
    "aarch64-darwin"
    "x86_64-darwin"
  ];

  arch =
    if !hostPlatform.isDarwin then
      throw "darwin-minimal-bootstrap: unsupported non-Darwin platform ${hostPlatform.config}"
    else if hostPlatform.isAarch64 then
      "aarch64"
    else if hostPlatform.isx86_64 then
      "x86_64"
    else
      throw "darwin-minimal-bootstrap: unsupported Darwin architecture ${hostPlatform.config}";

  source = ./hello + "/raw-syscall-${arch}.s";

  stage0-posix = import ./stage0-posix { inherit lib hostPlatform; };

  stage0Sources =
    minimal-bootstrap-sources.minimal-bootstrap-sources or minimal-bootstrap-sources;

  hex0 = stdenv.mkDerivation {
    pname = "darwin-minimal-bootstrap-hex0";
    version = "0-unstable-2026-05-07";

    src = ./hex0;
    strictDeps = true;

    buildPhase = ''
      runHook preBuild
      $CC $CFLAGS -o hex0 hex0.c
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 hex0 $out/bin/hex0
      runHook postInstall
    '';

    meta = {
      description = "Darwin hex0 assembler for minimal bootstrap experiments";
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = supportedSystems;
    };

    passthru.tests = {
      converts-hex = tests.hex0-converts-hex;
    };
  };

  m2libc-darwin = runCommand "darwin-minimal-bootstrap-m2libc" { } ''
    mkdir -p $out
    cp -R ${./M2libc}/. $out/
  '';

  m2libcDarwinSmoke = runCommand "darwin-minimal-bootstrap-m2libc-smoke" { } ''
    for source in ${./M2libc}/aarch64/Darwin/bootstrap.c ${./M2libc}/aarch64/libc-core-Darwin.M1; do
      if grep -q 'mov_x8,' "$source"; then
        echo "$source still uses the Linux aarch64 syscall register" >&2
        exit 1
      fi
    done

    if grep -q 'ldr_x0,\[x18\]' ${./M2libc}/aarch64/libc-core-Darwin.M1; then
      echo "aarch64 Darwin startup still reads argc from the Linux initial stack" >&2
      exit 1
    fi
    grep -q 'mov_x14,x0' ${./M2libc}/aarch64/libc-core-Darwin.M1
    grep -q 'mov_x15,x1' ${./M2libc}/aarch64/libc-core-Darwin.M1
    grep -q 'DEFINE svc_0 011000d4' ${./M2libc}/aarch64/aarch64_defs.M1

    for source in ${./M2libc}/amd64/Darwin/bootstrap.c ${./M2libc}/amd64/libc-core-Darwin.M1; do
      if grep -q 'mov_rax, %0x3C\|mov_rax, %[0-9][^x]' "$source"; then
        echo "$source still uses an unclassified Linux syscall number" >&2
        exit 1
      fi
    done

    for token in \
      'mov_x16,1' \
      'mov_x16,3' \
      'mov_x16,4' \
      'mov_x16,5' \
      'mov_x16,6' \
      'mov_x16,17'
    do
      grep -q "DEFINE $token " ${./M2libc}/aarch64/aarch64_defs.M1
    done

    for source in \
      ${./M2libc}/aarch64/MACHO-aarch64.hex2 \
      ${./M2libc}/amd64/MACHO-amd64.hex2
    do
      grep -q ':MACHO_base' "$source"
      grep -q ':MACHO_text' "$source"
      grep -q '2f 75 73 72 2f 6c 69 62' "$source"
      grep -q '6c 69 62 53 79 73 74' "$source"
    done

    mkdir $out
  '';

  machoTemplateHelloRuns = stdenv.mkDerivation {
    name = "darwin-minimal-bootstrap-macho-template-hello-runs";

    dontUnpack = true;
    strictDeps = true;

    buildPhase = ''
      runHook preBuild

      $CC -I${stage0Sources} -o hex2 \
        ${stage0Sources}/M2libc/bootstrappable.c \
        ${stage0Sources}/mescc-tools/hex2_linker.c \
        ${stage0Sources}/mescc-tools/hex2_word.c \
        ${stage0Sources}/mescc-tools/hex2.c

      ${lib.optionalString hostPlatform.isAarch64 ''
        cat > hello.hex2 <<'HEX2'
        :_start
        20 00 80 d2
        01 00 00 90
        21 b0 0b 91
        a2 01 80 d2
        90 00 80 d2
        01 10 00 d4
        00 00 80 d2
        30 00 80 d2
        01 10 00 d4
        :message
        68 65 6c 6c 6f 20 64 61 72 77 69 6e 0a
        :ELF_end
        HEX2

        ./hex2 --architecture aarch64 --little-endian \
          --base-address 0x100000000 \
          -f ${./M2libc}/aarch64/MACHO-aarch64.hex2 \
          -f hello.hex2 \
          -o hello

        currentSize="$(wc -c < hello | tr -d ' ')"
        if [ "$currentSize" -gt 16777216 ]; then
          echo "Mach-O template __LINKEDIT offset is before end of text" >&2
          exit 1
        fi

        dd if=/dev/zero of=hello bs=1 count=1 seek=16777215 conv=notrunc
        chmod +x hello

        source ${darwin.signingUtils}
        sign hello

        output="$(./hello)"
        test "$output" = "hello darwin"
      ''}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir $out
      runHook postInstall
    '';
  };

  raw-syscall-hello = stdenv.mkDerivation {
    pname = "darwin-minimal-bootstrap-raw-syscall-hello";
    version = "0-unstable-2026-05-07";

    dontUnpack = true;
    strictDeps = true;

    buildPhase = ''
      runHook preBuild
      $CC ${source} -o raw-syscall-hello
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 raw-syscall-hello $out/bin/raw-syscall-hello
      runHook postInstall
    '';

    meta = {
      description = "Darwin raw-syscall Mach-O smoke binary for minimal bootstrap experiments";
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = supportedSystems;
    };

    passthru.tests = tests;
  };

  raw-syscall-hello-unsigned = stdenv.mkDerivation {
    pname = "darwin-minimal-bootstrap-raw-syscall-hello-unsigned";
    version = "0-unstable-2026-05-07";

    dontUnpack = true;
    strictDeps = true;

    buildPhase = ''
      runHook preBuild
      $CC ${source} -Wl,-no_adhoc_codesign -o raw-syscall-hello
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 raw-syscall-hello $out/bin/raw-syscall-hello
      runHook postInstall
    '';

    meta = {
      description = "Unsigned Darwin raw-syscall Mach-O smoke binary for signing bootstrap experiments";
      teams = [ lib.teams.minimal-bootstrap ];
      platforms = supportedSystems;
    };
  };

  phase1-hex1 =
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

          python3 ${./tools/phase1-amd64-hex1.py} \
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

          grep -v '^:' ${./M2libc}/aarch64/MACHO-aarch64.hex2 > hex1-darwin.hex0
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
      null;

  phase2-hex2 =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase2-hex2-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          python3 ${./tools/phase2-amd64-hex2.py} \
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
      null;

  phase2-catm =
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

          python3 ${./tools/phase2-amd64-catm.py} \
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
      null;

  phase3-m0 =
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

          python3 ${./tools/phase3-amd64-m0.py} ${stage0Sources} .
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
      null;

  phase4-cc-arch =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase4-cc-arch-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        buildPhase = ''
          runHook preBuild

          ${phase3-m0}/bin/M0-darwin ${stage0Sources}/AMD64/cc_amd64.M1 cc_arch-0.hex2
          ${phase2-catm}/bin/catm-darwin cc_arch.hex2 \
            ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            cc_arch-0.hex2
          ${phase2-hex2}/bin/hex2-darwin cc_arch.hex2 cc_arch-darwin

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
      null;

  tests = {
    hex0-converts-hex = runCommand "darwin-minimal-bootstrap-hex0-converts-hex" { } ''
      cat > input.hex0 <<'HEX'
        68 65 6c 6c 6f 0a ; hello newline
      HEX
      ${hex0}/bin/hex0 input.hex0 output
      test "$(cat output)" = "hello"
      mkdir $out
    '';

    raw-syscall-hello-runs = runCommand "darwin-minimal-bootstrap-raw-syscall-hello-runs" { } ''
      output="$(${raw-syscall-hello}/bin/raw-syscall-hello)"
      test "$output" = "hello darwin"
      mkdir $out
    '';

    xcode-signing-bridge = runCommand "darwin-minimal-bootstrap-xcode-signing-bridge" { } ''
      source ${darwin.signingUtils}

      cp ${raw-syscall-hello-unsigned}/bin/raw-syscall-hello ./raw-syscall-hello
      chmod +w ./raw-syscall-hello
      sign ./raw-syscall-hello

      output="$(./raw-syscall-hello)"
      test "$output" = "hello darwin"
      mkdir $out
    '';

    m2libc-darwin-smoke = m2libcDarwinSmoke;

    macho-template-hello-runs = machoTemplateHelloRuns;

    stage0-posix-phase-graph = runCommand "darwin-minimal-bootstrap-stage0-posix-phase-graph" { } ''
      test ${lib.escapeShellArg (toString stage0-posix.sameLengthAsLinuxMesccToolsBoot)} = 1
      test ${lib.escapeShellArg (toString (builtins.length stage0-posix.missingCriticalPath))} -eq 6
      test ${lib.escapeShellArg stage0-posix.m2libcOS} = Darwin
      test ${lib.escapeShellArg stage0-posix.executableHeader} = MACHO-${arch}.hex2
      if grep -q '/linux/' ${./stage0-posix/mescc-tools-boot.nix}; then
        echo "Darwin mescc-tools-boot still references Linux M2libc paths" >&2
        exit 1
      fi
      mkdir $out
    '';
  };
in
{
  inherit
    hex0
    m2libc-darwin
    stage0-posix
    supportedSystems
    raw-syscall-hello
    raw-syscall-hello-unsigned
    phase1-hex1
    phase2-hex2
    phase2-catm
    phase3-m0
    phase4-cc-arch
    tests
    ;
}
