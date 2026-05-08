{
  darwin,
  fetchurl,
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

  mesVersion = "0.27.1";

  mesTarball = fetchurl {
    url = "mirror://gnu/mes/mes-${mesVersion}.tar.gz";
    hash = "sha256-GDpA6kfqSfih470bnRLmdjdNZNY7x557wa59Zz398l0=";
  };

  mesDarwinConfigH = builtins.toFile "darwin-mes-config.h" ''
    #ifndef _MES_CONFIG_H
    #undef SYSTEM_LIBC
    #define MES_VERSION "${mesVersion}"
    #ifndef __M2__
    typedef unsigned long uintptr_t;
    typedef unsigned long size_t;
    typedef long ssize_t;
    typedef long intptr_t;
    typedef long ptrdiff_t;
    #define __MES_SIZE_T
    #define __MES_SSIZE_T
    #define __MES_INTPTR_T
    #define __MES_UINTPTR_T
    #define __MES_PTRDIFF_T
    #endif
    #endif
  '';

  tinyccBootstrappableSrc = runCommand "darwin-bootstrap-tinycc-bootstrappable-source" { } ''
    mkdir -p $out
    cp -R ${./vendor/tinycc-bootstrappable}/. $out/
  '';

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

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase3-m0}/bin/M0-darwin ${stage0Sources}/AMD64/cc_amd64.M1 cc_arch-0-linux.hex2
          python3 ${./tools/phase4-amd64-cc-arch.py} port cc_arch-0-linux.hex2 cc_arch-0.hex2
          ${phase2-catm}/bin/catm-darwin cc_arch.hex2 \
            ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            cc_arch-0.hex2
          ${phase2-hex2}/bin/hex2-darwin cc_arch.hex2 cc_arch-darwin
          python3 ${./tools/phase4-amd64-cc-arch.py} patch cc_arch-0.hex2 cc_arch-darwin

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

  phase5-m2 =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase5-m2-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase2-catm}/bin/catm-darwin M2-0.c \
            ${./M2libc/amd64/Darwin/bootstrap.c} \
            ${stage0Sources}/M2-Planet/cc.h \
            ${stage0Sources}/M2libc/bootstrappable.c \
            ${stage0Sources}/M2-Planet/cc_globals.c \
            ${stage0Sources}/M2-Planet/cc_reader.c \
            ${stage0Sources}/M2-Planet/cc_strings.c \
            ${stage0Sources}/M2-Planet/cc_types.c \
            ${stage0Sources}/M2-Planet/cc_emit.c \
            ${stage0Sources}/M2-Planet/cc_core.c \
            ${stage0Sources}/M2-Planet/cc_macro.c \
            ${stage0Sources}/M2-Planet/cc.c
          ${phase4-cc-arch}/bin/cc_arch-darwin M2-0.c M2-0.M1
          ${phase2-catm}/bin/catm-darwin M2-0-0.M1 \
            ${./M2libc/amd64/amd64_defs.M1} \
            ${./M2libc/amd64/libc-core-Darwin.M1} \
            M2-0.M1
          ${phase3-m0}/bin/M0-darwin M2-0-0.M1 M2-0.hex2

          if grep -q 'sub_rdi\|lea_r9\|DWORD\|DEFINE' M2-0.hex2; then
            echo "M2 hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase2-catm}/bin/catm-darwin M2-0-0.hex2 \
            ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            M2-0.hex2
          ${phase2-hex2}/bin/hex2-darwin M2-0-0.hex2 M2-darwin
          python3 ${./tools/phase5-amd64-m2.py} patch M2-0.hex2 M2-darwin

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=M2-darwin bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x M2-darwin

          source ${darwin.signingUtils}
          sign M2-darwin

          set +e
          ./M2-darwin > no-input.stdout 2> no-input.stderr
          status="$?"
          set -e
          test "$status" -eq 1
          grep -q 'Either no input files were given or they were empty' no-input.stderr

          ./M2-darwin --help > help.stdout 2> help.stderr
          grep -q 'Usage: M2-Planet' help.stdout

          cat > trivial.c <<'C'
          int main(){return 0;}
          C
          ./M2-darwin -f trivial.c -o trivial.M1
          grep -q ':FUNCTION_main' trivial.M1

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 M2-darwin $out/bin/M2-darwin
          install -Dm644 M2-0.M1 $out/share/darwin-bootstrap/M2-0.M1
          install -Dm644 M2-0.hex2 $out/share/darwin-bootstrap/M2-0.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-5 AMD64 M2-Planet candidate";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase6-blood-macho-0 =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase6-blood-macho-0-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase5-m2}/bin/M2-darwin \
            --architecture amd64 \
            -f ${./M2libc/amd64/Darwin/bootstrap.c} \
            -f ${stage0Sources}/M2libc/bootstrappable.c \
            -f ${stage0Sources}/mescc-tools/stringify.c \
            -f ${stage0Sources}/mescc-tools/blood-elf.c \
            --bootstrap-mode \
            -o blood-macho-0.M1
          ${phase2-catm}/bin/catm-darwin blood-macho-0-0.M1 \
            ${./M2libc/amd64/amd64_defs.M1} \
            ${./M2libc/amd64/libc-core-Darwin.M1} \
            blood-macho-0.M1
          ${phase3-m0}/bin/M0-darwin blood-macho-0-0.M1 blood-macho-0.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' blood-macho-0.hex2; then
            echo "blood-macho-0 hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase2-catm}/bin/catm-darwin blood-macho-0-0.hex2 \
            ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            blood-macho-0.hex2
          ${phase2-hex2}/bin/hex2-darwin blood-macho-0-0.hex2 blood-macho-0
          python3 ${./tools/phase5-amd64-m2.py} patch blood-macho-0.hex2 blood-macho-0

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=blood-macho-0 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x blood-macho-0

          source ${darwin.signingUtils}
          sign blood-macho-0

          cat > mini.M1 <<'M1'
          :FUNCTION_main
          RET R15
          :ELF_data
          M1
          ./blood-macho-0 --64 --little-endian -f mini.M1 -o footer.M1
          grep -q ':ELF_section_headers' footer.M1

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 blood-macho-0 $out/bin/blood-macho-0
          install -Dm644 blood-macho-0.M1 $out/share/darwin-bootstrap/blood-macho-0.M1
          install -Dm644 blood-macho-0.hex2 $out/share/darwin-bootstrap/blood-macho-0.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-6 AMD64 blood footer generator";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase7-m1-0 =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase7-m1-0-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase5-m2}/bin/M2-darwin \
            --architecture amd64 \
            -f ${./M2libc/amd64/Darwin/bootstrap.c} \
            -f ${stage0Sources}/M2libc/bootstrappable.c \
            -f ${stage0Sources}/mescc-tools/stringify.c \
            -f ${stage0Sources}/mescc-tools/M1-macro.c \
            --bootstrap-mode \
            -o M1-macro-0.M1
          ${phase2-catm}/bin/catm-darwin M1-0-0.M1 \
            ${./M2libc/amd64/amd64_defs.M1} \
            ${./M2libc/amd64/libc-core-Darwin.M1} \
            M1-macro-0.M1
          ${phase3-m0}/bin/M0-darwin M1-0-0.M1 M1-0.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-0.hex2; then
            echo "M1-0 hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase2-catm}/bin/catm-darwin M1-0-0.hex2 \
            ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            M1-0.hex2
          ${phase2-hex2}/bin/hex2-darwin M1-0-0.hex2 M1-0
          python3 ${./tools/phase5-amd64-m2.py} patch M1-0.hex2 M1-0

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=M1-0 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x M1-0

          source ${darwin.signingUtils}
          sign M1-0

          ./M1-0 --help > help.stdout 2> help.stderr
          grep -q 'Usage:' help.stderr

          cat > mini.M1 <<'M1'
          DEFINE RET C3
          :foo
          RET
          M1
          ./M1-0 --architecture amd64 --little-endian -f mini.M1 -o mini.hex2
          grep -q ':foo' mini.hex2
          grep -q 'C3' mini.hex2

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 M1-0 $out/bin/M1-0
          install -Dm644 M1-macro-0.M1 $out/share/darwin-bootstrap/M1-macro-0.M1
          install -Dm644 M1-0.hex2 $out/share/darwin-bootstrap/M1-0.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-7 AMD64 M1 macro assembler";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase8-hex2-1 =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase8-hex2-1-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase5-m2}/bin/M2-darwin \
            --architecture amd64 \
            -f ${stage0Sources}/M2libc/sys/types.h \
            -f ${stage0Sources}/M2libc/stddef.h \
            -f ${stage0Sources}/M2libc/sys/utsname.h \
            -f ${./M2libc/amd64/Darwin/unistd.c} \
            -f ${./M2libc/amd64/Darwin/fcntl.c} \
            -f ${stage0Sources}/M2libc/fcntl.c \
            -f ${./M2libc/amd64/Darwin/sys/stat.c} \
            -f ${stage0Sources}/M2libc/ctype.c \
            -f ${stage0Sources}/M2libc/stdlib.c \
            -f ${stage0Sources}/M2libc/stdarg.h \
            -f ${stage0Sources}/M2libc/stdio.h \
            -f ${stage0Sources}/M2libc/stdio.c \
            -f ${stage0Sources}/M2libc/bootstrappable.c \
            -f ${stage0Sources}/mescc-tools/hex2.h \
            -f ${stage0Sources}/mescc-tools/hex2_linker.c \
            -f ${stage0Sources}/mescc-tools/hex2_word.c \
            -f ${stage0Sources}/mescc-tools/hex2.c \
            -o hex2_linker-0.M1

          ${phase7-m1-0}/bin/M1-0 \
            --architecture amd64 \
            --little-endian \
            -f ${./M2libc/amd64/amd64_defs.M1} \
            -f ${./M2libc/amd64/libc-full-Darwin.M1} \
            -f hex2_linker-0.M1 \
            -o hex2_linker-0.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' hex2_linker-0.hex2; then
            echo "hex2-1 hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase2-catm}/bin/catm-darwin hex2-1-0.hex2 \
            ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            hex2_linker-0.hex2
          ${phase2-hex2}/bin/hex2-darwin hex2-1-0.hex2 hex2-1
          python3 ${./tools/phase5-amd64-m2.py} patch hex2_linker-0.hex2 hex2-1

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=hex2-1 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x hex2-1

          source ${darwin.signingUtils}
          sign hex2-1

          ./hex2-1 --help > help.stdout 2> help.stderr
          cat help.stdout help.stderr > help.combined
          grep -q 'Usage:' help.combined

          cat > mini.hex2 <<'HEX2'
          :FUNCTION_main
          48 C7 C0 00 00 00 00
          C3
          :ELF_data
          HEX2
          ./hex2-1 \
            --architecture amd64 \
            --little-endian \
            --base-address 0x600000 \
            -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            -f mini.hex2 \
            -o mini
          test -s mini

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 hex2-1 $out/bin/hex2-1
          install -Dm644 hex2_linker-0.M1 $out/share/darwin-bootstrap/hex2_linker-0.M1
          install -Dm644 hex2_linker-0.hex2 $out/share/darwin-bootstrap/hex2_linker-0.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-8 AMD64 hex2 linker";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase9-m1 =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase9-m1-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase5-m2}/bin/M2-darwin \
            --architecture amd64 \
            -f ${stage0Sources}/M2libc/sys/types.h \
            -f ${stage0Sources}/M2libc/stddef.h \
            -f ${stage0Sources}/M2libc/sys/utsname.h \
            -f ${./M2libc/amd64/Darwin/fcntl.c} \
            -f ${stage0Sources}/M2libc/fcntl.c \
            -f ${./M2libc/amd64/Darwin/unistd.c} \
            -f ${stage0Sources}/M2libc/stdarg.h \
            -f ${stage0Sources}/M2libc/string.c \
            -f ${stage0Sources}/M2libc/ctype.c \
            -f ${stage0Sources}/M2libc/stdlib.c \
            -f ${stage0Sources}/M2libc/stdio.h \
            -f ${stage0Sources}/M2libc/stdio.c \
            -f ${stage0Sources}/M2libc/bootstrappable.c \
            -f ${stage0Sources}/mescc-tools/stringify.c \
            -f ${stage0Sources}/mescc-tools/M1-macro.c \
            -o M1-macro-1.M1

          ${phase7-m1-0}/bin/M1-0 \
            --architecture amd64 \
            --little-endian \
            -f ${./M2libc/amd64/amd64_defs.M1} \
            -f ${./M2libc/amd64/libc-full-Darwin.M1} \
            -f M1-macro-1.M1 \
            -o M1-macro-1.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M1-macro-1.hex2; then
            echo "M1 hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase8-hex2-1}/bin/hex2-1 \
            --architecture amd64 \
            --little-endian \
            --base-address 0x600000 \
            -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            -f M1-macro-1.hex2 \
            -o M1
          python3 ${./tools/phase5-amd64-m2.py} patch M1-macro-1.hex2 M1

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=M1 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x M1

          source ${darwin.signingUtils}
          sign M1

          ./M1 --help > help.stdout 2> help.stderr
          cat help.stdout help.stderr > help.combined
          grep -q 'Usage:' help.combined

          cat > mini.M1 <<'M1SRC'
          DEFINE RET C3
          :foo
          RET
          M1SRC
          ./M1 --architecture amd64 --little-endian -f mini.M1 -o mini.hex2
          grep -q ':foo' mini.hex2
          grep -q 'C3' mini.hex2

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 M1 $out/bin/M1
          install -Dm644 M1-macro-1.M1 $out/share/darwin-bootstrap/M1-macro-1.M1
          install -Dm644 M1-macro-1.hex2 $out/share/darwin-bootstrap/M1-macro-1.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-9 AMD64 M1 macro assembler";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase10-hex2 =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase10-hex2-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase5-m2}/bin/M2-darwin \
            --architecture amd64 \
            -f ${stage0Sources}/M2libc/sys/types.h \
            -f ${stage0Sources}/M2libc/stddef.h \
            -f ${stage0Sources}/M2libc/sys/utsname.h \
            -f ${./M2libc/amd64/Darwin/unistd.c} \
            -f ${./M2libc/amd64/Darwin/fcntl.c} \
            -f ${stage0Sources}/M2libc/fcntl.c \
            -f ${./M2libc/amd64/Darwin/sys/stat.c} \
            -f ${stage0Sources}/M2libc/ctype.c \
            -f ${stage0Sources}/M2libc/stdlib.c \
            -f ${stage0Sources}/M2libc/stdarg.h \
            -f ${stage0Sources}/M2libc/stdio.h \
            -f ${stage0Sources}/M2libc/stdio.c \
            -f ${stage0Sources}/M2libc/bootstrappable.c \
            -f ${stage0Sources}/mescc-tools/hex2.h \
            -f ${stage0Sources}/mescc-tools/hex2_linker.c \
            -f ${stage0Sources}/mescc-tools/hex2_word.c \
            -f ${stage0Sources}/mescc-tools/hex2.c \
            -o hex2_linker-2.M1

          ${phase9-m1}/bin/M1 \
            --architecture amd64 \
            --little-endian \
            -f ${./M2libc/amd64/amd64_defs.M1} \
            -f ${./M2libc/amd64/libc-full-Darwin.M1} \
            -f hex2_linker-2.M1 \
            -o hex2_linker-2.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' hex2_linker-2.hex2; then
            echo "hex2 hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase8-hex2-1}/bin/hex2-1 \
            --architecture amd64 \
            --little-endian \
            --base-address 0x600000 \
            -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            -f hex2_linker-2.hex2 \
            -o hex2
          python3 ${./tools/phase5-amd64-m2.py} patch hex2_linker-2.hex2 hex2

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=hex2 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x hex2

          source ${darwin.signingUtils}
          sign hex2

          ./hex2 --help > help.stdout 2> help.stderr
          cat help.stdout help.stderr > help.combined
          grep -q 'Usage:' help.combined

          cat > mini.hex2 <<'HEX2'
          :FUNCTION_main
          48 C7 C0 00 00 00 00
          C3
          :ELF_data
          HEX2
          ./hex2 \
            --architecture amd64 \
            --little-endian \
            --base-address 0x600000 \
            -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            -f mini.hex2 \
            -o mini
          test -s mini

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 hex2 $out/bin/hex2
          install -Dm644 hex2_linker-2.M1 $out/share/darwin-bootstrap/hex2_linker-2.M1
          install -Dm644 hex2_linker-2.hex2 $out/share/darwin-bootstrap/hex2_linker-2.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-10 AMD64 full hex2 linker";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase11-kaem =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase11-kaem-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase5-m2}/bin/M2-darwin \
            --architecture amd64 \
            -f ${stage0Sources}/M2libc/sys/types.h \
            -f ${stage0Sources}/M2libc/stddef.h \
            -f ${stage0Sources}/M2libc/sys/utsname.h \
            -f ${./M2libc/amd64/Darwin/unistd.c} \
            -f ${./M2libc/amd64/Darwin/fcntl.c} \
            -f ${stage0Sources}/M2libc/fcntl.c \
            -f ${stage0Sources}/M2libc/ctype.c \
            -f ${stage0Sources}/M2libc/stdlib.c \
            -f ${stage0Sources}/M2libc/string.c \
            -f ${stage0Sources}/M2libc/stdarg.h \
            -f ${stage0Sources}/M2libc/stdio.h \
            -f ${stage0Sources}/M2libc/stdio.c \
            -f ${stage0Sources}/M2libc/bootstrappable.c \
            -f ${stage0Sources}/mescc-tools/Kaem/kaem.h \
            -f ${stage0Sources}/mescc-tools/Kaem/variable.c \
            -f ${stage0Sources}/mescc-tools/Kaem/kaem_globals.c \
            -f ${stage0Sources}/mescc-tools/Kaem/kaem.c \
            -o kaem.M1

          ${phase9-m1}/bin/M1 \
            --architecture amd64 \
            --little-endian \
            -f ${./M2libc/amd64/amd64_defs.M1} \
            -f ${./M2libc/amd64/libc-full-Darwin.M1} \
            -f kaem.M1 \
            -o kaem.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' kaem.hex2; then
            echo "kaem hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase10-hex2}/bin/hex2 \
            --architecture amd64 \
            --little-endian \
            --base-address 0x600000 \
            -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            -f kaem.hex2 \
            -o kaem
          python3 ${./tools/phase5-amd64-m2.py} patch kaem.hex2 kaem

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=kaem bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x kaem

          source ${darwin.signingUtils}
          sign kaem

          ./kaem --help > help.stdout 2> help.stderr
          cat help.stdout help.stderr > help.combined
          grep -q 'Usage:' help.combined

          cat > smoke.kaem <<'KAEM'
          echo hello
          KAEM
          output="$(./kaem --init-mode -f smoke.kaem)"
          test "$output" = "hello"

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 kaem $out/bin/kaem
          install -Dm644 kaem.M1 $out/share/darwin-bootstrap/kaem.M1
          install -Dm644 kaem.hex2 $out/share/darwin-bootstrap/kaem.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-11 AMD64 kaem shell";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase12-m2-planet =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase12-m2-planet-amd64";
        version = "0-unstable-2026-05-07";

        dontUnpack = true;
        dontStrip = true;
        strictDeps = true;

        nativeBuildInputs = [ python3 ];

        buildPhase = ''
          runHook preBuild

          ${phase5-m2}/bin/M2-darwin \
            --architecture amd64 \
            -f ${stage0Sources}/M2libc/sys/types.h \
            -f ${stage0Sources}/M2libc/stddef.h \
            -f ${stage0Sources}/M2libc/sys/utsname.h \
            -f ${./M2libc/amd64/Darwin/unistd.c} \
            -f ${./M2libc/amd64/Darwin/fcntl.c} \
            -f ${stage0Sources}/M2libc/fcntl.c \
            -f ${./M2libc/amd64/Darwin/sys/stat.c} \
            -f ${stage0Sources}/M2libc/ctype.c \
            -f ${stage0Sources}/M2libc/stdlib.c \
            -f ${stage0Sources}/M2libc/string.c \
            -f ${stage0Sources}/M2libc/stdarg.h \
            -f ${stage0Sources}/M2libc/stdio.h \
            -f ${stage0Sources}/M2libc/stdio.c \
            -f ${stage0Sources}/M2libc/bootstrappable.c \
            -f ${stage0Sources}/M2-Planet/cc.h \
            -f ${stage0Sources}/M2-Planet/cc_globals.c \
            -f ${stage0Sources}/M2-Planet/cc_reader.c \
            -f ${stage0Sources}/M2-Planet/cc_strings.c \
            -f ${stage0Sources}/M2-Planet/cc_types.c \
            -f ${stage0Sources}/M2-Planet/cc_emit.c \
            -f ${stage0Sources}/M2-Planet/cc_core.c \
            -f ${stage0Sources}/M2-Planet/cc_macro.c \
            -f ${stage0Sources}/M2-Planet/cc.c \
            -o M2-Planet.M1

          ${phase9-m1}/bin/M1 \
            --architecture amd64 \
            --little-endian \
            -f ${./M2libc/amd64/amd64_defs.M1} \
            -f ${./M2libc/amd64/libc-full-Darwin.M1} \
            -f M2-Planet.M1 \
            -o M2-Planet.hex2

          if grep -q 'sub_rdi\|lea_r9\|mov_rdi,rbp\|DWORD\|DEFINE' M2-Planet.hex2; then
            echo "M2-Planet hex2 contains untranslated M1 tokens" >&2
            exit 1
          fi

          ${phase10-hex2}/bin/hex2 \
            --architecture amd64 \
            --little-endian \
            --base-address 0x600000 \
            -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
            -f M2-Planet.hex2 \
            -o M2-Planet
          python3 ${./tools/phase5-amd64-m2.py} patch M2-Planet.hex2 M2-Planet

          linkeditOffset="$((0x800000 + 0x2000000))"
          dd if=/dev/zero of=M2-Planet bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
          chmod +x M2-Planet

          source ${darwin.signingUtils}
          sign M2-Planet

          ./M2-Planet --help > help.stdout 2> help.stderr
          grep -q 'Usage: M2-Planet' help.stdout

          cat > trivial.c <<'C'
          int main(){return 0;}
          C
          ./M2-Planet -f trivial.c -o trivial.M1
          grep -q ':FUNCTION_main' trivial.M1

          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          install -Dm755 M2-Planet $out/bin/M2-Planet
          install -Dm644 M2-Planet.M1 $out/share/darwin-bootstrap/M2-Planet.M1
          install -Dm644 M2-Planet.hex2 $out/share/darwin-bootstrap/M2-Planet.hex2
          runHook postInstall
        '';

        meta = {
          description = "Signed Darwin Mach-O phase-12 AMD64 full M2-Planet";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase13-mes-source =
    if hostPlatform.isx86_64 then
      stdenv.mkDerivation {
        pname = "darwin-minimal-bootstrap-phase13-mes-source";
        version = mesVersion;

        src = mesTarball;

        dontConfigure = true;
        dontBuild = true;
        dontFixup = true;

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/darwin-bootstrap
          cp -R . $out/
          chmod -R u+w $out
          cp ${mesDarwinConfigH} $out/include/mes/config.h
          cp -R ${./mes-darwin}/. $out/

          cat > $out/share/darwin-bootstrap/darwin-mes-next.txt <<'EOF'
          This is the Darwin Mes source-prep checkpoint.
          Next steps:
          - port Mes include/linux and lib/linux references to Darwin;
          - add Darwin crt1, syscall, signal, stat, and setjmp support;
          - build mes-m2 with phase11-kaem, phase9-M1, and phase10-hex2.
          EOF

          test -f $out/kaem.x86_64
          test -f $out/scripts/mescc.scm.in
          test -f $out/lib/darwin/x86_64-mes-m2/crt1.M1
          test -f $out/include/darwin/x86_64/syscall.h
          grep -q 'MES_VERSION "${mesVersion}"' $out/include/mes/config.h
          grep -q 'typedef unsigned long uintptr_t' $out/include/mes/config.h

          runHook postInstall
        '';

        meta = {
          description = "Prepared GNU Mes source tree for the Darwin bootstrap path";
          platforms = [ "x86_64-darwin" ];
        };
      }
    else
      null;

  phase14-mes-m2-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase14-mes-m2-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        # Stop Mes' bootstrap script immediately after the first M2-Planet
        # compilation.  This keeps the checkpoint focused on the next real
        # porting edge: replacing the downstream ELF/blood-elf link path with
        # the Darwin Mach-O path.
          sed \
          -e 's|lib/linux/''${mes_cpu}-mes-m2/crt1.c|lib/darwin/''${mes_cpu}-mes-m2/crt1.c|g' \
          -e 's|lib/linux/''${mes_cpu}-mes-m2/_exit.c|lib/darwin/''${mes_cpu}-mes-m2/_exit.c|g' \
          -e 's|lib/linux/''${mes_cpu}-mes-m2/_write.c|lib/darwin/''${mes_cpu}-mes-m2/_write.c|g' \
          -e 's|include/linux/''${mes_cpu}/syscall.h|include/darwin/''${mes_cpu}/syscall.h|g' \
          -e 's|lib/linux/''${mes_cpu}-mes-m2/syscall.c|lib/darwin/''${mes_cpu}-mes-m2/syscall.c|g' \
          -e 's|lib/linux/brk.c|lib/darwin/brk.c|g' \
          -e 's|lib/linux/malloc.c|lib/darwin/malloc.c|g' \
          -e 's|lib/linux/read.c|lib/darwin/read.c|g' \
          -e 's|lib/linux/_open3.c|lib/darwin/_open3.c|g' \
          -e 's|lib/linux/open.c|lib/darwin/open.c|g' \
          -e 's|lib/linux/access.c|lib/darwin/access.c|g' \
          -e 's|lib/linux/chmod.c|lib/darwin/chmod.c|g' \
          -e 's|lib/linux/ioctl3.c|lib/darwin/ioctl3.c|g' \
          -e 's|lib/linux/fork.c|lib/darwin/fork.c|g' \
          -e 's|lib/m2/execve.c|lib/darwin/execve.c|g' \
          -e 's|lib/linux/wait4.c|lib/darwin/wait4.c|g' \
          -e 's|lib/linux/waitpid.c|lib/darwin/waitpid.c|g' \
          -e 's|lib/linux/gettimeofday.c|lib/darwin/gettimeofday.c|g' \
          -e 's|lib/linux/clock_gettime.c|lib/darwin/clock_gettime.c|g' \
          -e 's|lib/linux/_getcwd.c|lib/darwin/_getcwd.c|g' \
          -e 's|lib/linux/dup.c|lib/darwin/dup.c|g' \
          -e 's|lib/linux/dup2.c|lib/darwin/dup2.c|g' \
          -e 's|lib/linux/uname.c|lib/darwin/uname.c|g' \
          -e 's|lib/linux/unlink.c|lib/darwin/unlink.c|g' \
          ${phase13-mes-source}/kaem.run \
          | awk '{ print } /-o m2\/mes\.M1/ { print "exit 99"; exit }' \
          > mes-m2-only.sh

        set +e
        PATH=${phase12-m2-planet}/bin:$PATH \
          srcdest=${phase13-mes-source}/ \
          cc_cpu=x86_64 \
          mes_cpu=x86_64 \
          stage0_cpu=amd64 \
          blood_elf_flag=--64 \
          sh mes-m2-only.sh > mes-m2.stdout 2> mes-m2.stderr
        status="$?"
        set -e

        test "$status" -eq 99
        test -s m2/mes.M1

        cp mes-m2.stdout mes-m2.stderr m2/mes.M1 \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase15-mes-macho-link-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase15-mes-macho-link-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f ${phase13-mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
          -f ${phase13-mes-source}/lib/x86_64-mes/x86_64.M1 \
          -f ${phase13-mes-source}/lib/darwin/x86_64-mes-m2/crt1.M1 \
          -f ${phase14-mes-m2-probe}/share/darwin-bootstrap/mes.M1 \
          -o mes.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f mes.hex2 \
          -o mes-m2

        ${python3}/bin/python3 ${./tools/phase5-amd64-m2.py} patch mes.hex2 mes-m2

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=mes-m2 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x mes-m2

        source ${darwin.signingUtils}
        sign mes-m2

        set +e
        ./mes-m2 -c "(display 'Hello,M2-mes!) (newline)" \
          > mes-m2-run.stdout 2> mes-m2-run.stderr
        status="$?"
        set -e

        test "$status" -eq 1
        grep -q 'boot failed: no such file: boot-5.scm' mes-m2-run.stderr

        cp mes-m2 mes.hex2 mes-m2-run.stdout mes-m2-run.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  tinycc-m2-negative-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-tinycc-m2-negative-probe-amd64" { } ''
        set +e
        ${phase12-m2-planet}/bin/M2-Planet \
          --architecture amd64 \
          -I ${tinyccBootstrappableSrc} \
          -I ${tinyccBootstrappableSrc}/include \
          -D float=int \
          -D double=long \
          -D BOOTSTRAP=1 \
          -D HAVE_LONG_LONG=1 \
          -D TCC_TARGET_X86_64=1 \
          -D LDOUBLE_SIZE=8 \
          -D CONFIG_TCCBOOT=1 \
          -D CONFIG_TCC_STATIC=1 \
          -D CONFIG_USE_LIBGCC=1 \
          -D TCC_MES_LIBC=1 \
          -D TCC_VERSION=\"0.9.28-bootstrap\" \
          -f ${stage0Sources}/M2libc/sys/types.h \
          -f ${stage0Sources}/M2libc/stddef.h \
          -f ${stage0Sources}/M2libc/stdint.h \
          -f ${stage0Sources}/M2libc/sys/utsname.h \
          -f ${./M2libc/amd64/Darwin/unistd.c} \
          -f ${./M2libc/amd64/Darwin/fcntl.c} \
          -f ${stage0Sources}/M2libc/fcntl.c \
          -f ${./M2libc/amd64/Darwin/sys/stat.c} \
          -f ${stage0Sources}/M2libc/ctype.c \
          -f ${stage0Sources}/M2libc/stdlib.c \
          -f ${stage0Sources}/M2libc/string.c \
          -f ${stage0Sources}/M2libc/stdarg.h \
          -f ${stage0Sources}/M2libc/stdio.h \
          -f ${stage0Sources}/M2libc/stdio.c \
          -f ${stage0Sources}/M2libc/bootstrappable.c \
          -f ${tinyccBootstrappableSrc}/elf.h \
          -f ${tinyccBootstrappableSrc}/libtcc.h \
          -f ${tinyccBootstrappableSrc}/tcc.h \
          -f ${tinyccBootstrappableSrc}/tccpp.c \
          -f ${tinyccBootstrappableSrc}/tccgen.c \
          -f ${tinyccBootstrappableSrc}/tccelf.c \
          -f ${tinyccBootstrappableSrc}/tccrun.c \
          -f ${tinyccBootstrappableSrc}/x86_64-gen.c \
          -f ${tinyccBootstrappableSrc}/x86_64-link.c \
          -f ${tinyccBootstrappableSrc}/i386-asm.c \
          -f ${tinyccBootstrappableSrc}/tccasm.c \
          -f ${tinyccBootstrappableSrc}/libtcc.c \
          -f ${tinyccBootstrappableSrc}/tcctools.c \
          -f ${tinyccBootstrappableSrc}/tcc.c \
          -o tcc.M1 > tcc-m2.stdout 2> tcc-m2.stderr
        status="$?"
        set -e

        test "$status" -ne 0
        grep -q "Invalid token '(' used in constant_expression_term" tcc-m2.stderr

        mkdir -p $out/share/darwin-bootstrap
        cp tcc-m2.stdout tcc-m2.stderr $out/share/darwin-bootstrap/
      ''
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
      test ${lib.escapeShellArg (toString (builtins.length stage0-posix.missingCriticalPath))} -eq 3
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
    phase5-m2
    phase6-blood-macho-0
    phase7-m1-0
    phase8-hex2-1
    phase9-m1
    phase10-hex2
    phase11-kaem
    phase12-m2-planet
    phase13-mes-source
    phase14-mes-m2-probe
    phase15-mes-macho-link-probe
    tinycc-m2-negative-probe
    tinyccBootstrappableSrc
    tests
    ;
}
