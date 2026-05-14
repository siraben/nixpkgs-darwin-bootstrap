{
  darwin,
  cctools,
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

  gcc46Version = "4.6.4";

  gcc46Tarball = fetchurl {
    url = "mirror://gnu/gcc/gcc-${gcc46Version}/gcc-${gcc46Version}.tar.bz2";
    hash = "sha256-Na8Wr6C2evm46xXK+3bSvF9WhUBVJSL13CyI3UXZd+g=";
  };

  gcc46GmpTarball = fetchurl {
    url = "mirror://gnu/gmp/gmp-4.3.2.tar.bz2";
    hash = "sha256-k2FiwDEohsIVgQAreZMoKaoEjPr5k3xiZa6qFPHNF3U=";
  };

  gcc46MpfrTarball = fetchurl {
    url = "https://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2";
    hash = "sha256-x+daCKjUnSCC5MruFZGgXRG51WJ1FOZ48C1moSS88ro=";
  };

  gcc46MpcTarball = fetchurl {
    url = "https://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz";
    hash = "sha256-5mRgN1clH9ijUoSCdkl6THm3+LIf2K7dXMBZijj+4+Q=";
  };

  gnumakeVersion = "4.4.1";

  gnumakeTarball = fetchurl {
    url = "mirror://gnu/make/make-${gnumakeVersion}.tar.gz";
    hash = "sha256-3Rb7HWe/q3mnL16DkHNcSePo5wtJRaFasfgd23hlj7M=";
  };

  gnupatchVersion = "2.5.9";

  gnupatchTarball = fetchurl {
    url = "mirror://gnu/patch/patch-${gnupatchVersion}.tar.gz";
    hash = "sha256-7LXGRp1zK88B1uwa/p5k8WaMq6W/2xA8KNf1N7o824o=";
  };

  coreutilsVersion = "5.0";
  coreutilsLiveBootstrap = "https://github.com/fosslinux/live-bootstrap/raw/a8752029f60217a5c41c548b16f5cdd2a1a0e0db/sysa/coreutils-${coreutilsVersion}";

  coreutilsTarball = fetchurl {
    url = "mirror://gnu/coreutils/coreutils-${coreutilsVersion}.tar.gz";
    hash = "sha256-wnznXj9iRV9PrPTz/VW8njh30KsdXAQmyU2haMw0mIM=";
  };

  coreutilsMakefile = fetchurl {
    url = "${coreutilsLiveBootstrap}/mk/main.mk";
    hash = "sha256-zdGb+WebOqRY5X1bQXqrzlJo4NEULVoz1Rm7zlgnT1o=";
  };

  coreutilsPatches = [
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/modechange.patch";
      hash = "sha256-RddxUzLzTo/xYNDzfnu2fSv820QQYqP70NJrwYsiqhM=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/mbstate.patch";
      hash = "sha256-fo/C2F0NzlGtuV+iQwW9sr4TB1oH6V4I2bI/6jRg42c=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/ls-strcmp.patch";
      hash = "sha256-5pZCTaMtkAKuU76/tB3leBXrJ3DS5LWY3WvgrsnPqFM=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/touch-getdate.patch";
      hash = "sha256-qhISPP99SWV1GaOdKC8q19PfWVoQ2KI3ykfOTU/5o/U=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/touch-dereference.patch";
      hash = "sha256-qjnadcdkb0TSk8xWv+pjmh32O+bMm2ec5x0JMEcufnI=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/expr-strcmp.patch";
      hash = "sha256-SaVxnAzFoHLjT/95ly8Yhzxc6UnbO3H3xzyGqh0Nw6U=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/sort-locale.patch";
      hash = "sha256-zEShwIcwdMa6b/jHEDJ16apLFgfaYf8M9d37W1GArC0=";
    })
    (fetchurl {
      url = "${coreutilsLiveBootstrap}/patches/uniq-fopen.patch";
      hash = "sha256-1w2zfx+Mw2cC4b9D0SR18pGc+326yLLJgEQm2j3URmM=";
    })
  ];

  nyaccVersion = "1.09.1";

  nyaccTarball = fetchurl {
    url = "mirror://savannah/nyacc/nyacc-${nyaccVersion}.tar.gz";
    hash = "sha256-DsmuU34NlReBpQ3jx5KayXqFwdS16F5dUVQuN1ECJxc=";
  };

  mesNyacc = stdenv.mkDerivation {
    pname = "darwin-minimal-bootstrap-nyacc";
    version = nyaccVersion;
    src = nyaccTarball;
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share
      cp -R . $out/share/nyacc-${nyaccVersion}
      runHook postInstall
    '';
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

  tinyccMesSrc = runCommand "darwin-bootstrap-tinycc-mes-source" { } ''
    mkdir -p $out
    cp -R ${tinyccBootstrappableSrc}/. $out/
    chmod -R u+w $out
    cd $out

    patch -p1 < ${./patches/tinycc-mes-bootstrap.patch}
    : > config.h
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
          mkdir -p $out/include/arch
          cp $out/include/darwin/x86_64/kernel-stat.h $out/include/arch/kernel-stat.h
          cp $out/include/darwin/x86_64/signal.h $out/include/arch/signal.h
          cp $out/include/darwin/x86_64/syscall.h $out/include/arch/syscall.h
          ${python3}/bin/python3 - <<'PY'
          import os
          from pathlib import Path

          path = Path(os.environ["out"]) / "lib/mes/__assert_fail.c"
          text = path.read_text()
          text = text.replace(
              "  if (file && *file)\n    {\n      eputs (file);\n      eputs (\":\");\n    }\n",
              "  if (file)\n    if (*file)\n      {\n        eputs (file);\n        eputs (\":\");\n      }\n",
          )
          text = text.replace(
              "  if (function && *function)\n    {\n      eputs (function);\n      eputs (\":\");\n    }\n",
              "  if (function)\n    if (*function)\n      {\n        eputs (function);\n        eputs (\":\");\n      }\n",
          )
          path.write_text(text)
          PY

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
          test -f $out/include/arch/kernel-stat.h
          test -f $out/include/arch/signal.h
          test -f $out/include/arch/syscall.h
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
        MES_PREFIX=${phase13-mes-source} \
          GUILE_LOAD_PATH=${phase13-mes-source}/module:${phase13-mes-source}/mes/module \
          ./mes-m2 -c "(display 'Hello,M2-mes!) (newline)" \
          > mes-m2-run.stdout 2> mes-m2-run.stderr
        status="$?"
        set -e

        test "$status" -eq 0
        grep -q 'Hello,M2-mes!' mes-m2-run.stdout
        test ! -s mes-m2-run.stderr

        cp mes-m2 mes.hex2 mes-m2-run.stdout mes-m2-run.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase16-mes-m2 =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase16-mes-m2-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        cp ${phase15-mes-macho-link-probe}/share/darwin-bootstrap/mes-m2 $out/bin/mes-m2
        chmod 555 $out/bin/mes-m2

        sed \
          -e 's|@prefix@|${phase13-mes-source}|g' \
          -e 's|@VERSION@|${mesVersion}|g' \
          -e 's|@mes_cpu@|x86_64|g' \
          -e 's|@mes_kernel@|darwin|g' \
          ${phase13-mes-source}/scripts/mescc.scm.in > $out/bin/mescc.scm
        chmod 444 $out/bin/mescc.scm

        cat > trivial.c <<'EOF'
        int main () { return 0; }
        EOF

        mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module

        MES_PREFIX=${phase13-mes-source} \
          GUILE_LOAD_PATH="$mesLoadPath" \
          $out/bin/mes-m2 -c "(display 'Hello,M2-mes!) (newline)" \
          > mes-m2.stdout 2> mes-m2.stderr
        grep -q 'Hello,M2-mes!' mes-m2.stdout
        test ! -s mes-m2.stderr

        MES_PREFIX=${phase13-mes-source} \
          GUILE_LOAD_PATH="$mesLoadPath" \
          srcdest=${phase13-mes-source}/ \
          includedir=${phase13-mes-source}/include \
          libdir=${phase13-mes-source}/lib \
          M1=${phase9-m1}/bin/M1 \
          HEX2=${phase10-hex2}/bin/hex2 \
          $out/bin/mes-m2 --no-auto-compile -e main $out/bin/mescc.scm -- \
            -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 \
            trivial.c -o trivial.M1 \
          > mescc-trivial.stdout 2> mescc-trivial.stderr

        test -s trivial.M1
        chmod 444 trivial.M1
        grep -q main trivial.M1

        cp mes-m2.stdout mes-m2.stderr mescc-trivial.stdout mescc-trivial.stderr trivial.M1 \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase17-mescc-macho-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase17-mescc-macho-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        sed '/^<$/d' ${phase16-mes-m2}/share/darwin-bootstrap/trivial.M1 > trivial.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f ${phase13-mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
          -f ${phase13-mes-source}/lib/x86_64-mes/x86_64.M1 \
          -f ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/crt1.M1 \
          -f trivial.M1 \
          -o trivial.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f trivial.hex2 \
          -o trivial-mescc

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=trivial-mescc bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x trivial-mescc

        source ${darwin.signingUtils}
        sign trivial-mescc

        ./trivial-mescc > trivial.stdout 2> trivial.stderr
        test ! -s trivial.stdout
        test ! -s trivial.stderr

        cp trivial-mescc trivial.hex2 trivial.stdout trivial.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase18-mescc-libc-mini-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase18-mescc-libc-mini-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap m1

        mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module
        mescc() {
          MES_PREFIX=${phase13-mes-source} \
            GUILE_LOAD_PATH="$mesLoadPath" \
            srcdest=${phase13-mes-source}/ \
            includedir=${phase13-mes-source}/include \
            libdir=${phase13-mes-source}/lib \
            M1=${phase9-m1}/bin/M1 \
            HEX2=${phase10-hex2}/bin/hex2 \
            MES_STACK=6000000 \
            MES_ARENA=60000000 \
            MES_MAX_ARENA=60000000 \
            ${phase16-mes-m2}/bin/mes-m2 --no-auto-compile -e main ${phase16-mes-m2}/bin/mescc.scm -- "$@"
        }

        compile_m1() {
          source_path="$1"
          output_path="$2"
          mescc -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 "$source_path" -o "$output_path" \
            > "$output_path.stdout" 2> "$output_path.stderr"
          test -s "$output_path"
          sed -i.bak '/^<$/d' "$output_path"
          rm -f "$output_path.bak"
          chmod 444 "$output_path"
        }

        compile_m1 ${phase13-mes-source}/lib/mes/__init_io.c m1/__init_io.M1
        compile_m1 ${phase13-mes-source}/lib/mes/eputs.c m1/eputs.M1
        compile_m1 ${phase13-mes-source}/lib/mes/oputs.c m1/oputs.M1
        compile_m1 ${phase13-mes-source}/lib/mes/globals.c m1/globals.M1
        compile_m1 ${phase13-mes-source}/lib/stdlib/exit.c m1/exit.M1
        compile_m1 ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/_exit.c m1/_exit.M1
        compile_m1 ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/_write.c m1/_write.M1
        compile_m1 ${phase13-mes-source}/lib/stdlib/puts.c m1/puts.M1
        compile_m1 ${phase13-mes-source}/lib/string/strlen.c m1/strlen.M1
        compile_m1 ${phase13-mes-source}/lib/mes/write.c m1/write.M1

        cat > puts-smoke.c <<'EOF'
        int puts (char const *s);
        int main () { puts ("libc-mini"); return 0; }
        EOF
        compile_m1 puts-smoke.c puts-smoke.M1

        for file in m1/*.M1; do
          if test "$(basename "$file")" = "globals.M1"; then
            cat "$file" >> libc-mini.data.M1
            continue
          fi
          split_label='^:ELF_data$'
          if test "$(basename "$file")" = "exit.M1"; then
            split_label='^:__call_at_exit$'
          fi
          awk '
            split_re != "" && $0 ~ split_re { data = 1; next }
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' split_re="$split_label" "$file" >> libc-mini.code.M1
          awk '
            split_re != "" && $0 ~ split_re { data = 1; print; next }
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' split_re="$split_label" "$file" >> libc-mini.data.M1
        done
        {
          cat libc-mini.code.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          cat libc-mini.data.M1
        } > libc-mini.M1

        awk '
          /^:ELF_data$/ { data = 1; next }
          /^:HEX2_data$/ { next }
          data != 1 { print }
        ' puts-smoke.M1 > puts-smoke.code.M1
        awk '
          /^:ELF_data$/ { data = 1; next }
          /^:HEX2_data$/ { next }
          data == 1 { print }
        ' puts-smoke.M1 > puts-smoke.data.M1
        {
          cat libc-mini.code.M1
          cat puts-smoke.code.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          cat libc-mini.data.M1
          cat puts-smoke.data.M1
        } > puts-smoke-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f ${phase13-mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
          -f ${phase13-mes-source}/lib/x86_64-mes/x86_64.M1 \
          -f ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/crt1-libc.M1 \
          -f puts-smoke-combined.M1 \
          -o puts-smoke.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f puts-smoke.hex2 \
          -o puts-smoke

        ${python3}/bin/python3 ${./tools/phase5-amd64-m2.py} patch puts-smoke.hex2 puts-smoke

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=puts-smoke bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x puts-smoke

        source ${darwin.signingUtils}
        sign puts-smoke

        ./puts-smoke > puts-smoke.stdout 2> puts-smoke.stderr
        test "$(cat puts-smoke.stdout)" = "libc-mini"
        test ! -s puts-smoke.stderr

        cp libc-mini.M1 puts-smoke.M1 puts-smoke-combined.M1 puts-smoke.hex2 puts-smoke.stdout puts-smoke.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase19-tinycc-mescc-m1-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase19-tinycc-mescc-m1-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module
        MES_PREFIX=${phase13-mes-source} \
          GUILE_LOAD_PATH="$mesLoadPath" \
          MES_STACK=6000000 \
          MES_ARENA=60000000 \
          MES_MAX_ARENA=60000000 \
          srcdest=${phase13-mes-source}/ \
          includedir=${phase13-mes-source}/include \
          libdir=${phase13-mes-source}/lib \
          M1=${phase9-m1}/bin/M1 \
          HEX2=${phase10-hex2}/bin/hex2 \
          ${phase16-mes-m2}/bin/mes-m2 --no-auto-compile -e main ${phase16-mes-m2}/bin/mescc.scm -- \
            -S \
            -o tcc.M1 \
            -I ${tinyccMesSrc} \
            -I ${tinyccMesSrc}/include \
            -I ${phase13-mes-source}/include \
            -D BOOTSTRAP=1 \
            -D HAVE_LONG_LONG=1 \
            -D TCC_TARGET_X86_64=1 \
            -D inline= \
            -D CONFIG_TCCDIR=\"\" \
            -D CONFIG_SYSROOT=\"\" \
            -D CONFIG_TCC_CRTPREFIX=\"{B}\" \
            -D CONFIG_TCC_ELFINTERP=\"/mes/loader\" \
            -D CONFIG_TCC_LIBPATHS=\"{B}\" \
            -D CONFIG_TCC_SYSINCLUDEPATHS=\"${tinyccMesSrc}/include:${phase13-mes-source}/include\" \
            -D TCC_LIBGCC=\"libc.a\" \
            -D TCC_LIBTCC1=\"libtcc1.a\" \
            -D CONFIG_TCC_LIBTCC1_MES=0 \
            -D CONFIG_TCCBOOT=1 \
            -D CONFIG_TCC_STATIC=1 \
            -D CONFIG_USE_LIBGCC=1 \
            -D TCC_MES_LIBC=1 \
            -D TCC_VERSION=\"0.9.28-darwin-bootstrap\" \
            -D ONE_SOURCE=1 \
            ${tinyccMesSrc}/tcc.c \
          > tcc-mescc.stdout 2> tcc-mescc.stderr

        test -s tcc.M1
        sed -i.bak '/^<$/d' tcc.M1
        rm -f tcc.M1.bak
        grep -q '^:main' tcc.M1

        cp tcc.M1 tcc-mescc.stdout tcc-mescc.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase20-mescc-libmescc-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase20-mescc-libmescc-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap m1

        mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module
        mescc() {
          MES_PREFIX=${phase13-mes-source} \
            GUILE_LOAD_PATH="$mesLoadPath" \
            srcdest=${phase13-mes-source}/ \
            includedir=${phase13-mes-source}/include \
            libdir=${phase13-mes-source}/lib \
            M1=${phase9-m1}/bin/M1 \
            HEX2=${phase10-hex2}/bin/hex2 \
            MES_STACK=6000000 \
            MES_ARENA=60000000 \
            MES_MAX_ARENA=60000000 \
            ${phase16-mes-m2}/bin/mes-m2 --no-auto-compile -e main ${phase16-mes-m2}/bin/mescc.scm -- "$@"
        }

        compile_m1() {
          source_path="$1"
          output_path="$2"
          mescc -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 "$source_path" -o "$output_path" \
            > "$output_path.stdout" 2> "$output_path.stderr"
          test -s "$output_path"
          sed -i.bak '/^<$/d' "$output_path"
          rm -f "$output_path.bak"
          chmod 444 "$output_path"
        }

        compile_m1 ${phase13-mes-source}/lib/mes/globals.c m1/globals.M1
        compile_m1 ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/syscall-internal.c m1/syscall-internal.M1

        {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' m1/syscall-internal.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          cat m1/globals.M1
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' m1/syscall-internal.M1
        } > libmescc.M1

        grep -q '^:__raise' libmescc.M1
        grep -q '^:__sys_call_internal' libmescc.M1

        cp libmescc.M1 m1/globals.M1 m1/syscall-internal.M1 \
          m1/globals.M1.stdout m1/globals.M1.stderr \
          m1/syscall-internal.M1.stdout m1/syscall-internal.M1.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase21-mescc-libc-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase21-mescc-libc-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap m1 logs

        mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module
        mescc() {
          MES_PREFIX=${phase13-mes-source} \
            GUILE_LOAD_PATH="$mesLoadPath" \
            srcdest=${phase13-mes-source}/ \
            includedir=${phase13-mes-source}/include \
            libdir=${phase13-mes-source}/lib \
            M1=${phase9-m1}/bin/M1 \
            HEX2=${phase10-hex2}/bin/hex2 \
            MES_STACK=6000000 \
            MES_ARENA=60000000 \
            MES_MAX_ARENA=60000000 \
            ${phase16-mes-m2}/bin/mes-m2 --no-auto-compile -e main ${phase16-mes-m2}/bin/mescc.scm -- "$@"
        }

        cat > config.sh <<'EOF'
        mes_cpu=x86_64
        mes_kernel=linux
        compiler=mescc
        mes_libc=mes
        EOF
        . ./config.sh
        . ${phase13-mes-source}/build-aux/configure-lib.sh

        map_source() {
          source="$1"
          case "$source" in
            lib/linux/x86_64-mes-mescc/*)
              mapped="lib/darwin/x86_64-mes-mescc/$(basename "$source")"
              ;;
            lib/linux/*)
              mapped="lib/darwin/''${source#lib/linux/}"
              ;;
            *)
              mapped="$source"
              ;;
          esac
          if test -f "${phase13-mes-source}/$mapped"; then
            printf '%s\n' "$mapped"
          else
            printf '%s\n' "$source"
          fi
        }

        compile_m1() {
          source="$1"
          mapped="$(map_source "$source")"
          source_path="${phase13-mes-source}/$mapped"
          object_name="$(printf '%s\n' "$mapped" | sed -e 's|/|-|g' -e 's|[.]c$||').M1"
          output_path="m1/$object_name"
          echo "$source -> $mapped" >> logs/sources.map
          mescc -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 "$source_path" -o "$output_path" \
            > "$output_path.stdout" 2> "$output_path.stderr"
          test -s "$output_path"
          sed -i.bak '/^<$/d' "$output_path"
          rm -f "$output_path.bak"
          chmod 444 "$output_path"
          printf '%s\n' "$output_path" >> logs/objects.list
        }

        for source in $libc_SOURCES; do
          compile_m1 "$source"
        done

        while read -r object; do
          case "$object" in
            *lib-mes-globals.M1)
              ;;
            *)
              split_label='^:ELF_data$'
              if test "$(basename "$object")" = "lib-stdlib-exit.M1"; then
                split_label='^:__call_at_exit$'
              fi
              awk '
                split_re != "" && $0 ~ split_re { data = 1; next }
                /^:ELF_data$/ { data = 1; next }
                /^:HEX2_data$/ { next }
                data != 1 { print }
              ' split_re="$split_label" "$object"
              ;;
          esac
        done < logs/objects.list > logs/code.M1

        {
          cat logs/code.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          while read -r object; do
            case "$object" in
              *lib-mes-globals.M1)
                cat "$object"
                ;;
              *)
                split_label='^:ELF_data$'
                if test "$(basename "$object")" = "lib-stdlib-exit.M1"; then
                  split_label='^:__call_at_exit$'
                fi
                awk '
                  split_re != "" && $0 ~ split_re { data = 1; print; next }
                  /^:ELF_data$/ { data = 1; next }
                  /^:HEX2_data$/ { next }
                  data == 1 { print }
                ' split_re="$split_label" "$object"
                ;;
            esac
          done < logs/objects.list
        } > libc.M1

        grep -q '^:write' libc.M1
        grep -q '^:_open3' libc.M1
        grep -q '^:__sys_call4' libc.M1
        grep -q '^:ELF_data' libc.M1

        cp libc.M1 logs/sources.map logs/objects.list $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase22-mescc-libc-tcc-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase22-mescc-libc-tcc-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap m1 logs

        mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module
        mescc() {
          MES_PREFIX=${phase13-mes-source} \
            GUILE_LOAD_PATH="$mesLoadPath" \
            srcdest=${phase13-mes-source}/ \
            includedir=${phase13-mes-source}/include \
            libdir=${phase13-mes-source}/lib \
            M1=${phase9-m1}/bin/M1 \
            HEX2=${phase10-hex2}/bin/hex2 \
            MES_STACK=6000000 \
            MES_ARENA=60000000 \
            MES_MAX_ARENA=60000000 \
            ${phase16-mes-m2}/bin/mes-m2 --no-auto-compile -e main ${phase16-mes-m2}/bin/mescc.scm -- "$@"
        }

        cat > config.sh <<'EOF'
        mes_cpu=x86_64
        mes_kernel=linux
        compiler=mescc
        mes_libc=mes
        EOF
        . ./config.sh
        . ${phase13-mes-source}/build-aux/configure-lib.sh

        map_source() {
          source="$1"
          case "$source" in
            lib/linux/x86_64-mes-mescc/*)
              mapped="lib/darwin/x86_64-mes-mescc/$(basename "$source")"
              ;;
            lib/linux/*)
              mapped="lib/darwin/''${source#lib/linux/}"
              ;;
            *)
              mapped="$source"
              ;;
          esac
          if test -f "${phase13-mes-source}/$mapped"; then
            printf '%s\n' "$mapped"
          else
            printf '%s\n' "$source"
          fi
        }

        compile_m1() {
          source="$1"
          mapped="$(map_source "$source")"
          source_path="${phase13-mes-source}/$mapped"
          object_name="$(printf '%s\n' "$mapped" | sed -e 's|/|-|g' -e 's|[.]c$||').M1"
          output_path="m1/$object_name"
          echo "$source -> $mapped" >> logs/sources.map
          mescc -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 "$source_path" -o "$output_path" \
            > "$output_path.stdout" 2> "$output_path.stderr"
          test -s "$output_path"
          sed -i.bak '/^<$/d' "$output_path"
          rm -f "$output_path.bak"
          chmod 444 "$output_path"
          printf '%s\n' "$output_path" >> logs/objects.list
        }

        for source in $libc_tcc_SOURCES; do
          compile_m1 "$source"
        done

        while read -r object; do
          case "$object" in
            *lib-mes-globals.M1)
              ;;
            *)
              split_label='^:ELF_data$'
              if test "$(basename "$object")" = "lib-stdlib-exit.M1"; then
                split_label='^:__call_at_exit$'
              fi
              awk '
                split_re != "" && $0 ~ split_re { data = 1; next }
                /^:ELF_data$/ { data = 1; next }
                /^:HEX2_data$/ { next }
                data != 1 { print }
              ' split_re="$split_label" "$object"
              ;;
          esac
        done < logs/objects.list > logs/code.M1

        {
          cat logs/code.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          while read -r object; do
            case "$object" in
              *lib-mes-globals.M1)
                cat "$object"
                ;;
              *)
                split_label='^:ELF_data$'
                if test "$(basename "$object")" = "lib-stdlib-exit.M1"; then
                  split_label='^:__call_at_exit$'
                fi
                awk '
                  split_re != "" && $0 ~ split_re { data = 1; print; next }
                  /^:ELF_data$/ { data = 1; next }
                  /^:HEX2_data$/ { next }
                  data == 1 { print }
                ' split_re="$split_label" "$object"
                ;;
            esac
          done < logs/objects.list
        } > 'libc+tcc.M1'

        grep -q '^:fprintf' 'libc+tcc.M1'
        grep -q '^:setjmp' 'libc+tcc.M1'
        grep -q '^:__sys_call4' 'libc+tcc.M1'
        grep -q '^:ELF_data' 'libc+tcc.M1'

        cp 'libc+tcc.M1' logs/sources.map logs/objects.list $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase23-tinycc-mescc-link-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase23-tinycc-mescc-link-probe-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        split_m1() {
          input="$1"
          code="$2"
          data="$3"
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' "$input" > "$code"
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' "$input" > "$data"
        }

        split_m1 ${phase22-mescc-libc-tcc-probe}/share/darwin-bootstrap/libc+tcc.M1 libc-tcc.code.M1 libc-tcc.data.M1
        split_m1 ${phase19-tinycc-mescc-m1-probe}/share/darwin-bootstrap/tcc.M1 tcc.code.M1 tcc.data.M1

        {
          cat libc-tcc.code.M1
          cat tcc.code.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          cat libc-tcc.data.M1
          cat tcc.data.M1
        } > tcc-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f ${phase13-mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
          -f ${phase13-mes-source}/lib/x86_64-mes/x86_64.M1 \
          -f ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/crt1-libc.M1 \
          -f tcc-combined.M1 \
          -o tcc.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f tcc.hex2 \
          -o tcc

        ${python3}/bin/python3 ${./tools/phase5-amd64-m2.py} patch tcc.hex2 tcc

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=tcc bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x tcc

        source ${darwin.signingUtils}
        sign tcc

        ./tcc -version > tcc-version.stdout 2> tcc-version.stderr
        grep -q '0.9.28-darwin-bootstrap' tcc-version.stdout
        test ! -s tcc-version.stderr
        ./tcc --version > tcc-long-version.stdout 2> tcc-long-version.stderr
        grep -q '0.9.28-darwin-bootstrap' tcc-long-version.stdout
        test ! -s tcc-long-version.stderr

        cp tcc $out/bin/tcc
        cp tcc tcc.hex2 tcc-combined.M1 \
          tcc-version.stdout tcc-version.stderr \
          tcc-long-version.stdout tcc-long-version.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase24-tinycc-compile-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase24-tinycc-compile-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        cat > hello.c <<'C'
        #define VALUE 42
        int main(void) { return VALUE; }
        C

        ${phase23-tinycc-mescc-link-probe}/bin/tcc -E hello.c > hello.i 2> hello-E.stderr
        grep -q 'return 42' hello.i
        test ! -s hello-E.stderr

        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
        test ! -s hello-c.stdout
        test ! -s hello-c.stderr
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        cp hello.c hello.i hello.o hello-E.stderr hello-c.stdout hello-c.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase25-tinycc-self-object-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase25-tinycc-self-object-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap include

        cp -R ${phase13-mes-source}/include/. include/
        chmod -R u+w include
        cp -R ${tinyccMesSrc}/include/. include/

        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c \
          -I$PWD/include \
          -DBOOTSTRAP=1 \
          -DHAVE_LONG_LONG=1 \
          -DTCC_TARGET_X86_64=1 \
          -Dinline= \
          -D'CONFIG_TCCDIR=""' \
          -D'CONFIG_SYSROOT=""' \
          -D'CONFIG_TCC_CRTPREFIX="{B}"' \
          -D'CONFIG_TCC_ELFINTERP="/mes/loader"' \
          -D'CONFIG_TCC_LIBPATHS="{B}"' \
          -D'TCC_LIBGCC="libc.a"' \
          -D'TCC_LIBTCC1="libtcc1.a"' \
          -DCONFIG_TCC_LIBTCC1_MES=0 \
          -DCONFIG_TCCBOOT=1 \
          -DCONFIG_TCC_STATIC=1 \
          -DCONFIG_USE_LIBGCC=1 \
          -DTCC_MES_LIBC=1 \
          -D'TCC_VERSION="0.9.28-darwin-bootstrap"' \
          -DONE_SOURCE=1 \
          ${tinyccMesSrc}/tcc.c \
          -otcc.o \
          > tcc-self.stdout \
          2> tcc-self.stderr

        test "$(od -An -tx1 -N4 tcc.o | tr -d ' \n')" = "7f454c46"
        grep -q 'implicit declaration of function' tcc-self.stderr

        cp tcc.o tcc-self.stdout tcc-self.stderr $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase26-gcc46-source =
    runCommand "darwin-minimal-bootstrap-phase26-gcc-${gcc46Version}-source" { } ''
      mkdir -p work $out
      cd work

      tar -xf ${gcc46Tarball}
      tar -xf ${gcc46GmpTarball}
      tar -xf ${gcc46MpfrTarball}
      tar -xf ${gcc46MpcTarball}

      mv gcc-${gcc46Version}/* $out/
      cp -R gmp-4.3.2 $out/gmp
      cp -R mpfr-2.4.2 $out/mpfr
      cp -R mpc-0.8.1 $out/mpc

      test -x $out/configure
      test -f $out/gcc/gcc.c
      test -f $out/gmp/configure
      test -f $out/mpfr/configure
      test -f $out/mpc/configure
    '';

  gcc46DarwinBootstrapSrc =
    runCommand "darwin-minimal-bootstrap-gcc-${gcc46Version}-darwin-bootstrap-source" { } ''
      mkdir -p $out
      cp -R ${phase26-gcc46-source}/. $out/
      chmod -R u+w $out
      cd $out
    '';

  phase35-gcc46-all-gcc =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase35-gcc-${gcc46Version}-all-gcc-amd64" { } ''
        mkdir -p src build $out/bin $out/share/darwin-bootstrap
        cp -R ${gcc46DarwinBootstrapSrc}/. src/
        chmod -R u+w src

        export CC=${phase34-tinycc-darwin-cc}/bin/tcc-darwin-cc
        export CPP="$CC -E"
        export CC_FOR_BUILD="$CC"
        export AR=${cctools}/bin/ar
        export NM=${cctools}/bin/nm
        export RANLIB=${cctools}/bin/ranlib
        export STRIP=${cctools}/bin/strip
        export LIPO=${cctools}/bin/lipo
        export OTOOL=${cctools}/bin/otool
        export CFLAGS="-g"
        export CFLAGS_FOR_BUILD="-g"
        export CXX="$CC"
        export CXXCPP="$CC -E"
        export ac_cv_have_decl_getrlimit=no
        export ac_cv_have_decl_setrlimit=no
        export ac_cv_func_getrlimit=no
        export ac_cv_func_setrlimit=no

        cd build
        mkdir -p gcc
        cat > gcc/config.cache <<'CACHE'
        ac_cv_func_getrlimit=''${ac_cv_func_getrlimit=no}
        ac_cv_func_setrlimit=''${ac_cv_func_setrlimit=no}
        ac_cv_func_getrusage=''${ac_cv_func_getrusage=no}
        ac_cv_func_times=''${ac_cv_func_times=no}
        ac_cv_func_clock=''${ac_cv_func_clock=no}
        ac_cv_func_kill=''${ac_cv_func_kill=no}
        ac_cv_func_gettimeofday=''${ac_cv_func_gettimeofday=no}
        ac_cv_func_fork=''${ac_cv_func_fork=no}
        ac_cv_func_fork_works=''${ac_cv_func_fork_works=no}
        ac_cv_func_vfork=''${ac_cv_func_vfork=no}
        ac_cv_func_vfork_works=''${ac_cv_func_vfork_works=no}
        ac_cv_func_mmap=''${ac_cv_func_mmap=no}
        ac_cv_func_mbstowcs=''${ac_cv_func_mbstowcs=no}
        ac_cv_func_wcswidth=''${ac_cv_func_wcswidth=no}
        ac_cv_func_getchar_unlocked=''${ac_cv_func_getchar_unlocked=no}
        ac_cv_func_getc_unlocked=''${ac_cv_func_getc_unlocked=no}
        ac_cv_func_putchar_unlocked=''${ac_cv_func_putchar_unlocked=no}
        ac_cv_func_putc_unlocked=''${ac_cv_func_putc_unlocked=no}
        ac_cv_func_clearerr_unlocked=''${ac_cv_func_clearerr_unlocked=no}
        ac_cv_func_feof_unlocked=''${ac_cv_func_feof_unlocked=no}
        ac_cv_func_ferror_unlocked=''${ac_cv_func_ferror_unlocked=no}
        ac_cv_func_fflush_unlocked=''${ac_cv_func_fflush_unlocked=no}
        ac_cv_func_fgetc_unlocked=''${ac_cv_func_fgetc_unlocked=no}
        ac_cv_func_fgets_unlocked=''${ac_cv_func_fgets_unlocked=no}
        ac_cv_func_fileno_unlocked=''${ac_cv_func_fileno_unlocked=no}
        ac_cv_func_fprintf_unlocked=''${ac_cv_func_fprintf_unlocked=no}
        ac_cv_func_fputc_unlocked=''${ac_cv_func_fputc_unlocked=no}
        ac_cv_func_fputs_unlocked=''${ac_cv_func_fputs_unlocked=no}
        ac_cv_func_fread_unlocked=''${ac_cv_func_fread_unlocked=no}
        ac_cv_func_fwrite_unlocked=''${ac_cv_func_fwrite_unlocked=no}
        ac_cv_have_decl_getrlimit=''${ac_cv_have_decl_getrlimit=no}
        ac_cv_have_decl_setrlimit=''${ac_cv_have_decl_setrlimit=no}
        ac_cv_have_decl_getrusage=''${ac_cv_have_decl_getrusage=no}
        ac_cv_have_decl_times=''${ac_cv_have_decl_times=no}
        ac_cv_have_decl_clock=''${ac_cv_have_decl_clock=no}
        ac_cv_have_decl_gettimeofday=''${ac_cv_have_decl_gettimeofday=no}
        ac_cv_have_decl_clearerr_unlocked=''${ac_cv_have_decl_clearerr_unlocked=no}
        ac_cv_have_decl_feof_unlocked=''${ac_cv_have_decl_feof_unlocked=no}
        ac_cv_have_decl_ferror_unlocked=''${ac_cv_have_decl_ferror_unlocked=no}
        ac_cv_have_decl_fflush_unlocked=''${ac_cv_have_decl_fflush_unlocked=no}
        ac_cv_have_decl_fgetc_unlocked=''${ac_cv_have_decl_fgetc_unlocked=no}
        ac_cv_have_decl_fgets_unlocked=''${ac_cv_have_decl_fgets_unlocked=no}
        ac_cv_have_decl_fileno_unlocked=''${ac_cv_have_decl_fileno_unlocked=no}
        ac_cv_have_decl_fprintf_unlocked=''${ac_cv_have_decl_fprintf_unlocked=no}
        ac_cv_have_decl_fputc_unlocked=''${ac_cv_have_decl_fputc_unlocked=no}
        ac_cv_have_decl_fputs_unlocked=''${ac_cv_have_decl_fputs_unlocked=no}
        ac_cv_have_decl_fread_unlocked=''${ac_cv_have_decl_fread_unlocked=no}
        ac_cv_have_decl_fwrite_unlocked=''${ac_cv_have_decl_fwrite_unlocked=no}
        ac_cv_have_decl_getchar_unlocked=''${ac_cv_have_decl_getchar_unlocked=no}
        ac_cv_have_decl_getc_unlocked=''${ac_cv_have_decl_getc_unlocked=no}
        ac_cv_have_decl_putchar_unlocked=''${ac_cv_have_decl_putchar_unlocked=no}
        ac_cv_have_decl_putc_unlocked=''${ac_cv_have_decl_putc_unlocked=no}
CACHE
        for f in getenv atol asprintf sbrk abort atof getcwd getwd \
          strsignal strstr strverscmp errno snprintf vsnprintf vasprintf \
          malloc realloc calloc free basename getopt clock getpagesize \
          clearerr_unlocked feof_unlocked ferror_unlocked fflush_unlocked \
          fgetc_unlocked fgets_unlocked fileno_unlocked fprintf_unlocked \
          fputc_unlocked fputs_unlocked fread_unlocked fwrite_unlocked \
          getchar_unlocked getc_unlocked putchar_unlocked putc_unlocked; do
          echo "gcc_cv_have_decl_$f=\''${gcc_cv_have_decl_$f=no}" >> gcc/config.cache
        done
        for d in libiberty build-x86_64-apple-darwin/libiberty; do
          mkdir -p "$d"
          cat > "$d/config.cache" <<'CACHE'
        ac_cv_sizeof_int=''${ac_cv_sizeof_int=4}
        ac_cv_sizeof_long=''${ac_cv_sizeof_long=8}
        ac_cv_sizeof_long_long=''${ac_cv_sizeof_long_long=8}
        ac_cv_sizeof_short=''${ac_cv_sizeof_short=2}
        ac_cv_sizeof_void_p=''${ac_cv_sizeof_void_p=8}
        ac_cv_type_intptr_t=''${ac_cv_type_intptr_t=yes}
        ac_cv_type_uintptr_t=''${ac_cv_type_uintptr_t=yes}
        ac_cv_type_intmax_t=''${ac_cv_type_intmax_t=yes}
        ac_cv_type_uintmax_t=''${ac_cv_type_uintmax_t=yes}
        ac_cv_func_getpagesize=''${ac_cv_func_getpagesize=no}
        ac_cv_func_mmap=''${ac_cv_func_mmap=no}
        ac_cv_func_getrlimit=''${ac_cv_func_getrlimit=no}
        ac_cv_func_setrlimit=''${ac_cv_func_setrlimit=no}
CACHE
        done
        for d in mpfr mpc; do
          mkdir -p "$d"
          cat > "$d/config.cache" <<'CACHE'
        ac_cv_lib_gmp___gmpz_init=''${ac_cv_lib_gmp___gmpz_init=yes}
CACHE
        done
        ../src/configure \
          --prefix=$out \
          --build=x86_64-apple-darwin \
          --host=x86_64-apple-darwin \
          --target=x86_64-apple-darwin \
          --disable-bootstrap \
          --disable-shared \
          --disable-multilib \
          --disable-nls \
          --enable-languages=c \
          > $out/share/darwin-bootstrap/configure.stdout \
          2> $out/share/darwin-bootstrap/configure.stderr

        make all-gcc -j1 \
          CPP="$CPP" \
          AR="$AR" \
          NM="$NM" \
          RANLIB="$RANLIB" \
          STRIP="$STRIP" \
          LIPO="$LIPO" \
          OTOOL="$OTOOL" \
          > $out/share/darwin-bootstrap/make-all-gcc.stdout \
          2> $out/share/darwin-bootstrap/make-all-gcc.stderr

        test -x gcc/xgcc
        cp gcc/xgcc $out/bin/xgcc
        $out/bin/xgcc --version > $out/share/darwin-bootstrap/xgcc-version.stdout

        cat > xgcc-smoke.c <<'C'
        int main(void) { return 42; }
C
        $out/bin/xgcc xgcc-smoke.c -o xgcc-smoke \
          > $out/share/darwin-bootstrap/xgcc-smoke.stdout \
          2> $out/share/darwin-bootstrap/xgcc-smoke.stderr
        set +e
        ./xgcc-smoke
        xgccSmokeStatus=$?
        set -e
        echo "$xgccSmokeStatus" > $out/share/darwin-bootstrap/xgcc-smoke.status
        test "$xgccSmokeStatus" = 42

        cd ..
        mkdir -p $out/share/darwin-bootstrap/work
        cp -R src $out/share/darwin-bootstrap/work/src
        cp -R build $out/share/darwin-bootstrap/work/build
      ''
    else
      null;

  phase36-gcc46-cc1 =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase36-gcc-${gcc46Version}-cc1-amd64" { } ''
        mkdir -p work $out/bin $out/share/darwin-bootstrap

        cp -R ${phase35-gcc46-all-gcc}/share/darwin-bootstrap/work/src work/src
        cp -R ${phase35-gcc46-all-gcc}/share/darwin-bootstrap/work/build work/build
        chmod -R u+w work
        find work/build -type f -name Makefile -print | while read makefile; do
          sed -i \
            -e "s#/nix/var/nix/builds/[^/]*/build#$PWD/work/build#g" \
            -e "s#/nix/var/nix/builds/[^/]*/src#$PWD/work/src#g" \
            "$makefile"
        done
        for sourceDir in config c-family ada cp java objc; do
          rm -rf "work/build/gcc/$sourceDir"
          cp -R "work/src/gcc/$sourceDir" "work/build/gcc/$sourceDir"
        done
        find work/src/gcc -maxdepth 1 -type f -name '*.def' -exec cp {} work/build/gcc/ \;

        export CC=${phase34-tinycc-darwin-cc}/bin/tcc-darwin-cc
        export CPP="$CC -E"
        export CC_FOR_BUILD="$CC"
        export AR=${cctools}/bin/ar
        export NM=${cctools}/bin/nm
        export RANLIB=${cctools}/bin/ranlib
        export STRIP=${cctools}/bin/strip
        export LIPO=${cctools}/bin/lipo
        export OTOOL=${cctools}/bin/otool
        export CFLAGS="-g"
        export CFLAGS_FOR_BUILD="-g"
        export CXX="$CC"
        export CXXCPP="$CC -E"

        cd work/build
        make -C gcc cc1 -j1 \
          CPP="$CPP" \
          AR="$AR" \
          NM="$NM" \
          RANLIB="$RANLIB" \
          STRIP="$STRIP" \
          LIPO="$LIPO" \
          OTOOL="$OTOOL" \
          > $out/share/darwin-bootstrap/make-cc1.stdout \
          2> $out/share/darwin-bootstrap/make-cc1.stderr

        test -x gcc/cc1
        cp gcc/cc1 $out/bin/cc1
      ''
    else
      null;

  phase27-tinycc-elf-to-macho-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase27-tinycc-elf-to-macho-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        cat > hello.c <<'C'
        int answer(void) { return 42; }
        int main(void) { return answer(); }
        C

        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c hello.c -o hello.o \
          > hello-c.stdout \
          2> hello-c.stderr
        test ! -s hello-c.stdout
        test ! -s hello-c.stderr
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix hello_ hello.o hello-object.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        {
          cat crt1-tcc-sysv.M1
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' hello-object.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' hello-object.M1
        } > hello-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f hello-combined.M1 \
          -o hello.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f hello.hex2 \
          -o hello

        ${python3}/bin/python3 ${./tools/phase5-amd64-m2.py} patch hello.hex2 hello

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=hello bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x hello

        source ${darwin.signingUtils}
        sign hello

        set +e
        ./hello
        status="$?"
        set -e
        test "$status" = 42

        cp hello.c hello.o hello-object.M1 crt1-tcc-sysv.M1 hello-combined.M1 hello.hex2 hello \
          hello-c.stdout hello-c.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase28-tinycc-self-m1-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase28-tinycc-self-m1-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix tcc_self_ \
          ${phase25-tinycc-self-object-probe}/share/darwin-bootstrap/tcc.o \
          tcc-from-elf.M1

        grep -q '^:main$' tcc-from-elf.M1
        grep -q '^:tcc_new$' tcc-from-elf.M1
        grep -q '^%memcpy$' tcc-from-elf.M1
        grep -q '^%vsnprintf$' tcc-from-elf.M1
        grep -q '^:ELF_data$' tcc-from-elf.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f tcc-from-elf.M1 \
          -o tcc-from-elf.hex2

        test -s tcc-from-elf.hex2

        cp tcc-from-elf.M1 tcc-from-elf.hex2 $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase29-tinycc-sysv-libc-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase29-tinycc-sysv-libc-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        cat > hello.c <<'C'
        unsigned long strlen(const char *s);
        int main(void) { return (int)strlen("bootstrap"); }
        C

        cat > strlen.c <<'C'
        unsigned long strlen(const char *s)
        {
            const char *p = s;
            while (*p)
                p++;
            return p - s;
        }
        C

        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c hello.c -o hello.o \
          > hello-c.stdout \
          2> hello-c.stderr
        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c strlen.c -o strlen.o \
          > strlen-c.stdout \
          2> strlen-c.stderr
        test ! -s hello-c.stdout
        test ! -s hello-c.stderr
        test ! -s strlen-c.stdout
        test ! -s strlen-c.stderr

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix hello_ hello.o hello-object.M1
        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix strlen_ strlen.o strlen-object.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        emit_code() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' "$1"
        }

        emit_data() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' "$1"
        }

        {
          cat crt1-tcc-sysv.M1
          emit_code hello-object.M1
          emit_code strlen-object.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          emit_data hello-object.M1
          emit_data strlen-object.M1
        } > hello-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f hello-combined.M1 \
          -o hello.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f hello.hex2 \
          -o hello

        ${python3}/bin/python3 ${./tools/phase5-amd64-m2.py} patch hello.hex2 hello

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=hello bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x hello

        source ${darwin.signingUtils}
        sign hello

        set +e
        ./hello
        status="$?"
        set -e
        test "$status" = 9

        cp hello.c strlen.c hello.o strlen.o hello-object.M1 strlen-object.M1 \
          crt1-tcc-sysv.M1 hello-combined.M1 hello.hex2 hello \
          hello-c.stdout hello-c.stderr strlen-c.stdout strlen-c.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase30-tinycc-self-link-candidate =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase30-tinycc-self-link-candidate-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c \
          ${./bootstrap/tinycc-sysv-libc.c} \
          -o tinycc-sysv-libc.o \
          > tinycc-sysv-libc.stdout \
          2> tinycc-sysv-libc.stderr

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix tinycc_sysv_libc_ \
          tinycc-sysv-libc.o \
          tinycc-sysv-libc.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        emit_code() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' "$1"
        }

        emit_data() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' "$1"
        }

        {
          cat crt1-tcc-sysv.M1
          cat ${./bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1}
          emit_code ${phase28-tinycc-self-m1-probe}/share/darwin-bootstrap/tcc-from-elf.M1
          emit_code tinycc-sysv-libc.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          emit_data ${phase28-tinycc-self-m1-probe}/share/darwin-bootstrap/tcc-from-elf.M1
          emit_data tinycc-sysv-libc.M1
        } > tcc-self-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f tcc-self-combined.M1 \
          -o tcc-self.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f tcc-self.hex2 \
          -o tcc-self

        ${python3}/bin/python3 ${./tools/hex2-data-relocs.py} patch tcc-self.hex2 tcc-self

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=tcc-self bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x tcc-self

        source ${darwin.signingUtils}
        sign tcc-self

        set +e
        ./tcc-self -version > tcc-self-version.stdout 2> tcc-self-version.stderr
        status="$?"
        set -e
        printf '%s\n' "$status" > tcc-self-version.status
        test "$status" = 0
        grep -q '0.9.28-darwin-bootstrap' tcc-self-version.stdout
        test ! -s tcc-self-version.stderr

        cp tcc-self $out/bin/tcc-self-candidate
        cp tinycc-sysv-libc.o tinycc-sysv-libc.M1 \
          tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
          crt1-tcc-sysv.M1 tcc-self-combined.M1 tcc-self.hex2 \
          tcc-self-version.stdout tcc-self-version.stderr tcc-self-version.status \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase31-tinycc-self-compile-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase31-tinycc-self-compile-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        cat > hello.c <<'C'
        int answer(void) { return 42; }
        int main(void) { return answer(); }
        C

        ${phase30-tinycc-self-link-candidate}/bin/tcc-self-candidate \
          -c hello.c -o hello.o \
          > hello-c.stdout \
          2> hello-c.stderr

        test ! -s hello-c.stdout
        test ! -s hello-c.stderr
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix hello_ hello.o hello-object.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        {
          cat crt1-tcc-sysv.M1
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' hello-object.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' hello-object.M1
        } > hello-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f hello-combined.M1 \
          -o hello.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f hello.hex2 \
          -o hello

        ${python3}/bin/python3 ${./tools/hex2-data-relocs.py} patch hello.hex2 hello

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=hello bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x hello

        source ${darwin.signingUtils}
        sign hello

        set +e
        ./hello
        status="$?"
        set -e
        test "$status" = 42

        cp hello.c hello.o hello-object.M1 crt1-tcc-sysv.M1 hello-combined.M1 hello.hex2 hello \
          hello-c.stdout hello-c.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase32-tinycc-boot1-object-probe =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase32-tinycc-boot1-object-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap include

        cp -R ${phase13-mes-source}/include/. include/
        chmod -R u+w include
        cp -R ${tinyccMesSrc}/include/. include/

        ${phase30-tinycc-self-link-candidate}/bin/tcc-self-candidate -c \
          -I$PWD/include \
          -DBOOTSTRAP=1 \
          -DHAVE_LONG_LONG=1 \
          -DTCC_TARGET_X86_64=1 \
          -Dinline= \
          -D'CONFIG_TCCDIR=""' \
          -D'CONFIG_SYSROOT=""' \
          -D'CONFIG_TCC_CRTPREFIX="{B}"' \
          -D'CONFIG_TCC_ELFINTERP="/mes/loader"' \
          -D'CONFIG_TCC_LIBPATHS="{B}"' \
          -D'TCC_LIBGCC="libc.a"' \
          -D'TCC_LIBTCC1="libtcc1.a"' \
          -DCONFIG_TCC_LIBTCC1_MES=0 \
          -DCONFIG_TCCBOOT=1 \
          -DCONFIG_TCC_STATIC=1 \
          -DCONFIG_USE_LIBGCC=1 \
          -DTCC_MES_LIBC=1 \
          -D'TCC_VERSION="0.9.28-darwin-bootstrap"' \
          -DONE_SOURCE=1 \
          ${tinyccMesSrc}/tcc.c \
          -otcc-boot1.o \
          > tcc-boot1.stdout \
          2> tcc-boot1.stderr

        test "$(od -An -tx1 -N4 tcc-boot1.o | tr -d ' \n')" = "7f454c46"
        test ! -s tcc-boot1.stdout

        cp tcc-boot1.o tcc-boot1.stdout tcc-boot1.stderr $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase33-tinycc-boot1-link-candidate =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase33-tinycc-boot1-link-candidate-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        ${phase30-tinycc-self-link-candidate}/bin/tcc-self-candidate -c \
          ${./bootstrap/tinycc-sysv-libc.c} \
          -o tinycc-sysv-libc.o \
          > tinycc-sysv-libc.stdout \
          2> tinycc-sysv-libc.stderr

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix tinycc_sysv_libc_ \
          tinycc-sysv-libc.o \
          tinycc-sysv-libc.M1

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix tcc_boot1_ \
          ${phase32-tinycc-boot1-object-probe}/share/darwin-bootstrap/tcc-boot1.o \
          tcc-boot1.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        emit_code() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' "$1"
        }

        emit_data() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' "$1"
        }

        {
          cat crt1-tcc-sysv.M1
          cat ${./bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1}
          emit_code tcc-boot1.M1
          emit_code tinycc-sysv-libc.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          emit_data tcc-boot1.M1
          emit_data tinycc-sysv-libc.M1
        } > tcc-boot1-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f tcc-boot1-combined.M1 \
          -o tcc-boot1.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f tcc-boot1.hex2 \
          -o tcc-boot1

        ${python3}/bin/python3 ${./tools/hex2-data-relocs.py} patch tcc-boot1.hex2 tcc-boot1

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=tcc-boot1 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x tcc-boot1

        source ${darwin.signingUtils}
        sign tcc-boot1

        set +e
        ./tcc-boot1 -version > tcc-boot1-version.stdout 2> tcc-boot1-version.stderr
        version_status="$?"
        set -e
        printf '%s\n' "$version_status" > tcc-boot1-version.status
        test "$version_status" = 0
        grep -q '0.9.28-darwin-bootstrap' tcc-boot1-version.stdout
        test ! -s tcc-boot1-version.stderr

        cat > hello.c <<'C'
        int main(void) { return 42; }
        C
        set +e
        ./tcc-boot1 -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
        compile_status="$?"
        set -e
        printf '%s\n' "$compile_status" > hello-c.status
        test "$compile_status" = 0
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        cp tcc-boot1 $out/bin/tcc-boot1-candidate
        cp tinycc-sysv-libc.o tinycc-sysv-libc.M1 \
          tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
          tcc-boot1.M1 crt1-tcc-sysv.M1 tcc-boot1-combined.M1 tcc-boot1.hex2 \
          tcc-boot1-version.stdout tcc-boot1-version.stderr tcc-boot1-version.status \
          hello.c hello-c.stdout hello-c.stderr hello-c.status \
          $out/share/darwin-bootstrap/
        if test -f hello.o; then
          cp hello.o $out/share/darwin-bootstrap/
        fi
      ''
    else
      null;

  tinyccSelfObjectProbe =
    {
      phase,
      boot,
      compiler,
    }:
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-${phase}-tinycc-${boot}-object-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap include

        cp -R ${phase13-mes-source}/include/. include/
        chmod -R u+w include
        cp -R ${tinyccMesSrc}/include/. include/

        ${compiler} -c \
          -I$PWD/include \
          -DBOOTSTRAP=1 \
          -DHAVE_LONG_LONG=1 \
          -DTCC_TARGET_X86_64=1 \
          -Dinline= \
          -D'CONFIG_TCCDIR=""' \
          -D'CONFIG_SYSROOT=""' \
          -D'CONFIG_TCC_CRTPREFIX="{B}"' \
          -D'CONFIG_TCC_ELFINTERP="/mes/loader"' \
          -D'CONFIG_TCC_LIBPATHS="{B}"' \
          -D'TCC_LIBGCC="libc.a"' \
          -D'TCC_LIBTCC1="libtcc1.a"' \
          -DCONFIG_TCC_LIBTCC1_MES=0 \
          -DCONFIG_TCCBOOT=1 \
          -DCONFIG_TCC_STATIC=1 \
          -DCONFIG_USE_LIBGCC=1 \
          -DTCC_MES_LIBC=1 \
          -D'TCC_VERSION="0.9.28-darwin-bootstrap"' \
          -DONE_SOURCE=1 \
          ${tinyccMesSrc}/tcc.c \
          -o${boot}.o \
          > ${boot}.stdout \
          2> ${boot}.stderr

        test "$(od -An -tx1 -N4 ${boot}.o | tr -d ' \n')" = "7f454c46"
        test ! -s ${boot}.stdout

        cp ${boot}.o ${boot}.stdout ${boot}.stderr $out/share/darwin-bootstrap/
      ''
    else
      null;

  tinyccSelfLinkCandidate =
    {
      phase,
      boot,
      compiler,
      objectProbe,
    }:
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-${phase}-tinycc-${boot}-link-candidate-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        ${compiler} -c \
          ${./bootstrap/tinycc-sysv-libc.c} \
          -o tinycc-sysv-libc.o \
          > tinycc-sysv-libc.stdout \
          2> tinycc-sysv-libc.stderr

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix tinycc_sysv_libc_ \
          tinycc-sysv-libc.o \
          tinycc-sysv-libc.M1

        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix ${lib.replaceStrings [ "-" ] [ "_" ] boot}_ \
          ${objectProbe}/share/darwin-bootstrap/${boot}.o \
          ${boot}.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        emit_code() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' "$1"
        }

        emit_data() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' "$1"
        }

        {
          cat crt1-tcc-sysv.M1
          cat ${./bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1}
          emit_code ${boot}.M1
          emit_code tinycc-sysv-libc.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          emit_data ${boot}.M1
          emit_data tinycc-sysv-libc.M1
        } > ${boot}-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f ${boot}-combined.M1 \
          -o ${boot}.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f ${boot}.hex2 \
          -o ${boot}

        ${python3}/bin/python3 ${./tools/hex2-data-relocs.py} patch ${boot}.hex2 ${boot}

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=${boot} bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x ${boot}

        source ${darwin.signingUtils}
        sign ${boot}

        ./${boot} -version > ${boot}-version.stdout 2> ${boot}-version.stderr
        printf '0\n' > ${boot}-version.status
        grep -q '0.9.28-darwin-bootstrap' ${boot}-version.stdout
        test ! -s ${boot}-version.stderr

        cat > hello.c <<'C'
        int main(void) { return 42; }
        C
        ./${boot} -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
        printf '0\n' > hello-c.status
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        cp ${boot} $out/bin/${boot}-candidate
        cp tinycc-sysv-libc.o tinycc-sysv-libc.M1 \
          tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
          ${boot}.M1 crt1-tcc-sysv.M1 ${boot}-combined.M1 ${boot}.hex2 \
          ${boot}-version.stdout ${boot}-version.stderr ${boot}-version.status \
          hello.c hello.o hello-c.stdout hello-c.stderr hello-c.status \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase35-tinycc-boot2-object-probe = tinyccSelfObjectProbe {
    phase = "phase35";
    boot = "tcc-boot2";
    compiler = "${phase33-tinycc-boot1-link-candidate}/bin/tcc-boot1-candidate";
  };

  phase36-tinycc-boot2-link-candidate = tinyccSelfLinkCandidate {
    phase = "phase36";
    boot = "tcc-boot2";
    compiler = "${phase33-tinycc-boot1-link-candidate}/bin/tcc-boot1-candidate";
    objectProbe = phase35-tinycc-boot2-object-probe;
  };

  phase37-tinycc-boot3-object-probe = tinyccSelfObjectProbe {
    phase = "phase37";
    boot = "tcc-boot3";
    compiler = "${phase36-tinycc-boot2-link-candidate}/bin/tcc-boot2-candidate";
  };

  phase38-tinycc-boot3-link-candidate = tinyccSelfLinkCandidate {
    phase = "phase38";
    boot = "tcc-boot3";
    compiler = "${phase36-tinycc-boot2-link-candidate}/bin/tcc-boot2-candidate";
    objectProbe = phase37-tinycc-boot3-object-probe;
  };

  phase34-tinycc-darwin-cc =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase34-tinycc-darwin-cc-amd64" { } ''
        mkdir -p $out/bin $out/include/tcc-darwin-bootstrap/sys $out/share/darwin-bootstrap

        cat > $out/include/tcc-darwin-bootstrap/limits.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_LIMITS_H
        #define _DARWIN_BOOTSTRAP_LIMITS_H
        #define CHAR_BIT 8
        #define SCHAR_MIN (-128)
        #define SCHAR_MAX 127
        #define UCHAR_MAX 255
        #define CHAR_MIN SCHAR_MIN
        #define CHAR_MAX SCHAR_MAX
        #define SHRT_MIN (-32768)
        #define SHRT_MAX 32767
        #define USHRT_MAX 65535
        #define INT_MIN (-2147483647 - 1)
        #define INT_MAX 2147483647
        #define UINT_MAX 4294967295U
        #define LONG_MIN (-9223372036854775807L - 1L)
        #define LONG_MAX 9223372036854775807L
        #define ULONG_MAX 18446744073709551615UL
        #define LLONG_MIN (-9223372036854775807LL - 1LL)
        #define LLONG_MAX 9223372036854775807LL
        #define ULLONG_MAX 18446744073709551615ULL
        #define PATH_MAX 1024
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/float.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_FLOAT_H
        #define _DARWIN_BOOTSTRAP_FLOAT_H
        #define FLT_RADIX 2
        #define FLT_MANT_DIG 24
        #define DBL_MANT_DIG 53
        #define LDBL_MANT_DIG 64
        #define FLT_DIG 6
        #define DBL_DIG 15
        #define LDBL_DIG 18
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/math.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_MATH_H
        #define _DARWIN_BOOTSTRAP_MATH_H
        double ldexp(double, int);
        double frexp(double, int *);
        double fabs(double);
        double atof(const char *);
        double strtod(const char *, char **);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/assert.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_ASSERT_H
        #define _DARWIN_BOOTSTRAP_ASSERT_H
        #define assert(expr) ((void)0)
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/types.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_TYPES_H
        #define _DARWIN_BOOTSTRAP_SYS_TYPES_H
        typedef unsigned long size_t;
        typedef long ssize_t;
        typedef long ptrdiff_t;
        typedef long intptr_t;
        typedef unsigned long uintptr_t;
        typedef int wchar_t;
        typedef int pid_t;
        typedef unsigned int uid_t;
        typedef unsigned int gid_t;
        typedef long off_t;
        typedef unsigned long ino_t;
        typedef unsigned long dev_t;
        typedef long time_t;
        typedef long clock_t;
        typedef char *caddr_t;
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/stat.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_STAT_H
        #define _DARWIN_BOOTSTRAP_SYS_STAT_H
        typedef long off_t;
        typedef int mode_t;
        struct stat { unsigned long st_dev; unsigned long st_ino; unsigned int st_mode; unsigned int st_nlink; unsigned int st_uid; unsigned int st_gid; unsigned long st_rdev; off_t st_size; long st_atime; long st_mtime; long st_ctime; };
        int stat(const char *, struct stat *);
        int fstat(int, struct stat *);
        int chmod(const char *, mode_t);
        int chown(const char *, unsigned int, unsigned int);
        int mkdir(const char *, mode_t);
        #define lstat stat
        #define S_IFMT 0170000
        #define S_IFREG 0100000
        #define S_IFDIR 0040000
        #define S_IFLNK 0120000
        #define S_IFCHR 0020000
        #define S_IRWXU 0700
        #define S_IRWXG 0070
        #define S_IRWXO 0007
        #define S_IRUSR 0400
        #define S_IWUSR 0200
        #define S_IXUSR 0100
        #define S_IRGRP 0040
        #define S_IWGRP 0020
        #define S_IXGRP 0010
        #define S_IROTH 0004
        #define S_IWOTH 0002
        #define S_IXOTH 0001
        #define S_ISREG(m) (((m) & S_IFMT) == S_IFREG)
        #define S_ISDIR(m) (((m) & S_IFMT) == S_IFDIR)
        #define S_ISLNK(m) (((m) & S_IFMT) == S_IFLNK)
        #define S_ISCHR(m) (((m) & S_IFMT) == S_IFCHR)
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/fcntl.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_FCNTL_H
        #define _DARWIN_BOOTSTRAP_FCNTL_H
        #define O_RDONLY 0
        #define O_WRONLY 1
        #define O_RDWR 2
        #define O_CREAT 0x0200
        #define O_EXCL 0x0800
        #define O_TRUNC 0x0400
        #define O_APPEND 0x0008
        #define F_GETFD 1
        #define F_SETFD 2
        #define FD_CLOEXEC 1
        int open(const char *, int, ...);
        int creat(const char *, int);
        int fcntl(int, int, ...);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/dirent.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_DIRENT_H
        #define _DARWIN_BOOTSTRAP_DIRENT_H
        typedef struct DIR DIR;
        struct dirent { unsigned long d_ino; char d_name[256]; };
        DIR *opendir(const char *);
        struct dirent *readdir(DIR *);
        int closedir(DIR *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/time.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_TIME_H
        #define _DARWIN_BOOTSTRAP_TIME_H
        typedef long time_t;
        typedef long clock_t;
        struct timespec { long tv_sec; long tv_nsec; };
        struct tm { int tm_sec; int tm_min; int tm_hour; int tm_mday; int tm_mon; int tm_year; int tm_wday; int tm_yday; int tm_isdst; };
        time_t time(time_t *);
        clock_t clock(void);
        struct tm *localtime(const time_t *);
        struct tm *gmtime(const time_t *);
        time_t mktime(struct tm *);
        char *ctime(const time_t *);
        int nanosleep(const struct timespec *, struct timespec *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/time.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_TIME_H
        #define _DARWIN_BOOTSTRAP_SYS_TIME_H
        struct timeval { long tv_sec; long tv_usec; };
        struct timezone { int tz_minuteswest; int tz_dsttime; };
        int gettimeofday(struct timeval *, struct timezone *);
        int settimeofday(const struct timeval *, const struct timezone *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/wait.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_WAIT_H
        #define _DARWIN_BOOTSTRAP_SYS_WAIT_H
        #define WNOHANG 1
        int wait(int *);
        int wait4(int, int *, int, void *);
        int waitpid(int, int *, int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/file.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_FILE_H
        #define _DARWIN_BOOTSTRAP_SYS_FILE_H
        #define F_OK 0
        #define X_OK 1
        #define W_OK 2
        #define R_OK 4
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/param.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_PARAM_H
        #define _DARWIN_BOOTSTRAP_SYS_PARAM_H
        #define MAXPATHLEN 1024
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/resource.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_RESOURCE_H
        #define _DARWIN_BOOTSTRAP_SYS_RESOURCE_H
        struct rlimit { unsigned long rlim_cur; unsigned long rlim_max; };
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/sys/select.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SYS_SELECT_H
        #define _DARWIN_BOOTSTRAP_SYS_SELECT_H
        typedef long fd_set;
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdint.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDINT_H
        #define _DARWIN_BOOTSTRAP_STDINT_H
        typedef signed char int8_t;
        typedef unsigned char uint8_t;
        typedef short int16_t;
        typedef unsigned short uint16_t;
        typedef int int32_t;
        typedef unsigned int uint32_t;
        typedef long int64_t;
        typedef unsigned long uint64_t;
        typedef long intmax_t;
        typedef unsigned long uintmax_t;
        typedef long intptr_t;
        typedef unsigned long uintptr_t;
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdbool.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDBOOL_H
        #define _DARWIN_BOOTSTRAP_STDBOOL_H
        #define bool int
        #define true 1
        #define false 0
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/inttypes.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_INTTYPES_H
        #define _DARWIN_BOOTSTRAP_INTTYPES_H
        #include <stdint.h>
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/locale.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_LOCALE_H
        #define _DARWIN_BOOTSTRAP_LOCALE_H
        #define LC_ALL 0
        char *setlocale(int, const char *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/pwd.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_PWD_H
        #define _DARWIN_BOOTSTRAP_PWD_H
        struct passwd { char *pw_name; char *pw_passwd; unsigned int pw_uid; unsigned int pw_gid; char *pw_gecos; char *pw_dir; char *pw_shell; };
        struct passwd *getpwnam(const char *);
        struct passwd *getpwuid(unsigned int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/grp.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_GRP_H
        #define _DARWIN_BOOTSTRAP_GRP_H
        struct group { char *gr_name; unsigned int gr_gid; char **gr_mem; };
        struct group *getgrnam(const char *);
        struct group *getgrgid(unsigned int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stddef.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDDEF_H
        #define _DARWIN_BOOTSTRAP_STDDEF_H
        typedef unsigned long size_t;
        typedef long ptrdiff_t;
        typedef long ssize_t;
        typedef long intptr_t;
        typedef unsigned long uintptr_t;
        typedef int wchar_t;
        #ifndef NULL
        #define NULL ((void *)0)
        #endif
        #define offsetof(type, field) ((size_t)&((type *)0)->field)
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdarg.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDARG_H
        #define _DARWIN_BOOTSTRAP_STDARG_H
        typedef struct {
            unsigned int gp_offset;
            unsigned int fp_offset;
            union {
                unsigned int overflow_offset;
                char *overflow_arg_area;
            };
            char *reg_save_area;
        } __va_list_struct;
        #ifndef _DARWIN_BOOTSTRAP_VA_LIST_TYPE
        #define _DARWIN_BOOTSTRAP_VA_LIST_TYPE
        typedef __va_list_struct va_list[1];
        #endif
        void __va_start(__va_list_struct *, void *);
        void *__va_arg(__va_list_struct *, int, int, int);
        #define va_start(ap, last) __va_start(ap, __builtin_frame_address(0))
        #define va_arg(ap, type) (*(type *)(__va_arg(ap, __builtin_va_arg_types(type), sizeof(type), __alignof__(type))))
        #define va_end(ap) ((void)0)
        #define va_copy(dst, src) (*(dst) = *(src))
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/alloca.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_ALLOCA_H
        #define _DARWIN_BOOTSTRAP_ALLOCA_H
        void *malloc(unsigned long);
        #define alloca malloc
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/string.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STRING_H
        #define _DARWIN_BOOTSTRAP_STRING_H
        typedef unsigned long size_t;
        void *memchr(const void *, int, size_t);
        int memcmp(const void *, const void *, size_t);
        void *memcpy(void *, const void *, size_t);
        void *memmove(void *, const void *, size_t);
        void *memset(void *, int, size_t);
        char *strcat(char *, const char *);
        char *strchr(const char *, int);
        int strcmp(const char *, const char *);
        char *strcpy(char *, const char *);
        unsigned long strlen(const char *);
        int strncmp(const char *, const char *, size_t);
        char *strncpy(char *, const char *, size_t);
        char *strpbrk(const char *, const char *);
        char *strrchr(const char *, int);
        char *strerror(int);
        char *strdup(const char *);
        char *strstr(const char *, const char *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/strings.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STRINGS_H
        #define _DARWIN_BOOTSTRAP_STRINGS_H
        #include <string.h>
        int bcmp(const void *, const void *, unsigned long);
        void bcopy(const void *, void *, unsigned long);
        void bzero(void *, unsigned long);
        char *index(const char *, int);
        char *rindex(const char *, int);
        int strcasecmp(const char *, const char *);
        int strncasecmp(const char *, const char *, unsigned long);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/ctype.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_CTYPE_H
        #define _DARWIN_BOOTSTRAP_CTYPE_H
        int isalnum(int);
        int isalpha(int);
        int iscntrl(int);
        int isdigit(int);
        int islower(int);
        int isprint(int);
        int ispunct(int);
        int isspace(int);
        int isupper(int);
        int isxdigit(int);
        int tolower(int);
        int toupper(int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/errno.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_ERRNO_H
        #define _DARWIN_BOOTSTRAP_ERRNO_H
        extern int errno;
        #define EINVAL 22
        #define ENOMEM 12
        #define ENOENT 2
        #define EINTR 4
        #define EIO 5
        #define EAGAIN 35
        #define EBADF 9
        #define EACCES 13
        #define EEXIST 17
        #define ENOEXEC 8
        #define ENOTDIR 20
        #define EISDIR 21
        #define EPIPE 32
        #define ECHILD 10
        #define EXDEV 18
        #define ENOSPC 28
        #define ERANGE 34
        #define ENAMETOOLONG 63
        #define ENOSYS 78
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/fnmatch.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_FNMATCH_H
        #define _DARWIN_BOOTSTRAP_FNMATCH_H
        #define FNM_NOMATCH 1
        #define FNM_NOESCAPE 0x01
        #define FNM_PATHNAME 0x02
        #define FNM_FILE_NAME FNM_PATHNAME
        #define FNM_PERIOD 0x04
        #define FNM_LEADING_DIR 0x08
        #define FNM_CASEFOLD 0x10
        #define FNM_EXTMATCH 0x20
        int fnmatch(const char *, const char *, int);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/signal.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_SIGNAL_H
        #define _DARWIN_BOOTSTRAP_SIGNAL_H
        typedef int sig_atomic_t;
        typedef long sigset_t;
        typedef void (*__sighandler_t)(int);
        struct sigaction { __sighandler_t sa_handler; sigset_t sa_mask; int sa_flags; };
        #define SIG_DFL ((__sighandler_t)0)
        #define SIG_IGN ((__sighandler_t)1)
        #define SIG_ERR ((__sighandler_t)-1)
        #define SIG_BLOCK 1
        #define SIG_UNBLOCK 2
        #define SIG_SETMASK 3
        #define SA_RESTART 0
        #define SIGABRT 6
        #define SIGALRM 14
        #define SIGCHLD 20
        #define SIGINT 2
        #define SIGTERM 15
        __sighandler_t signal(int, __sighandler_t);
        int sigaction(int, const struct sigaction *, struct sigaction *);
        int raise(int);
        int kill(int, int);
        int sigemptyset(sigset_t *);
        int sigaddset(sigset_t *, int);
        int sigprocmask(int, const sigset_t *, sigset_t *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdlib.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDLIB_H
        #define _DARWIN_BOOTSTRAP_STDLIB_H
        typedef unsigned long size_t;
        void abort(void);
        #define EXIT_SUCCESS 0
        #define EXIT_FAILURE 1
        int system(const char *);
        void exit(int);
        void _exit(int);
        int atexit(void (*)(void));
        void free(void *);
        char *getenv(const char *);
        void *malloc(size_t);
        void *calloc(size_t, size_t);
        void *realloc(void *, size_t);
        int abs(int);
        long strtol(const char *, char **, int);
        unsigned long strtoul(const char *, char **, int);
        long long strtoll(const char *, char **, int);
        unsigned long long strtoull(const char *, char **, int);
        double atof(const char *);
        char *mktemp(char *);
        void qsort(void *, size_t, size_t, int (*)(const void *, const void *));
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/stdio.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_STDIO_H
        #define _DARWIN_BOOTSTRAP_STDIO_H
        #define EOF (-1)
        #define BUFSIZ 1024
        #define _IONBF 0
        #define _IOLBF 1
        #define _IOFBF 2
        #define SEEK_SET 0
        #define SEEK_CUR 1
        #define SEEK_END 2
        typedef struct FILE FILE;
        typedef unsigned long size_t;
        #include <stdarg.h>
        extern FILE *stdin;
        extern FILE *stdout;
        extern FILE *stderr;
        int printf(const char *, ...);
        int fprintf(FILE *, const char *, ...);
        int vfprintf(FILE *, const char *, va_list);
        void perror(const char *);
        int fscanf(FILE *, const char *, ...);
        int sscanf(const char *, const char *, ...);
        int sprintf(char *, const char *, ...);
        int snprintf(char *, size_t, const char *, ...);
        int vsprintf(char *, const char *, va_list);
        int vsnprintf(char *, size_t, const char *, va_list);
        int vasprintf(char **, const char *, va_list);
        FILE *fopen(const char *, const char *);
        FILE *fopen_unlocked(const char *, const char *);
        FILE *fdopen(int, const char *);
        int fclose(FILE *);
        int ferror(FILE *);
        int fputs(const char *, FILE *);
        int puts(const char *);
        int fputc(int, FILE *);
        int putchar(int);
        int getchar(void);
        void setbuf(FILE *, char *);
        int getc(FILE *);
        char *fgets(char *, int, FILE *);
        int ungetc(int, FILE *);
        int putc(int, FILE *);
        int fflush(FILE *);
        size_t fread(void *, size_t, size_t, FILE *);
        size_t fwrite(const void *, size_t, size_t, FILE *);
        int feof(FILE *);
        int fseek(FILE *, long, int);
        long ftell(FILE *);
        int fileno(FILE *);
        int remove(const char *);
        int setvbuf(FILE *, char *, int, size_t);
        FILE *popen(const char *, const char *);
        int pclose(FILE *);
        #endif
        H

        cat > $out/include/tcc-darwin-bootstrap/unistd.h <<'H'
        #ifndef _DARWIN_BOOTSTRAP_UNISTD_H
        #define _DARWIN_BOOTSTRAP_UNISTD_H
        typedef long ssize_t;
        typedef long off_t;
        int close(int);
        #define F_OK 0
        int access(const char *, int);
        int dup(int);
        int dup2(int, int);
        int execvp(const char *, char *const *);
        int fork(void);
        char *getcwd(char *, unsigned long);
        char *getlogin(void);
        int chdir(const char *);
        int geteuid(void);
        int getuid(void);
        int getegid(void);
        int getgid(void);
        int getpid(void);
        int isatty(int);
        int fchdir(int);
        int pipe(int *);
        int sleep(unsigned int);
        unsigned int alarm(unsigned int);
        char *ttyname(int);
        int umask(int);
        ssize_t readlink(const char *, char *, unsigned long);
        ssize_t read(int, void *, unsigned long);
        ssize_t write(int, const void *, unsigned long);
        off_t lseek(int, off_t, int);
        int unlink(const char *);
        int rename(const char *, const char *);
        int rmdir(const char *);
        #endif
        H

        ${phase30-tinycc-self-link-candidate}/bin/tcc-self-candidate -c \
          ${./bootstrap/tinycc-sysv-libc.c} \
          -o tinycc-sysv-libc.o \
          > tinycc-sysv-libc.stdout \
          2> tinycc-sysv-libc.stderr
        ${python3}/bin/python3 ${./tools/elf64-to-m1.py} --prefix tinycc_sysv_libc_ \
          tinycc-sysv-libc.o \
          tinycc-sysv-libc.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        cp crt1-tcc-sysv.M1 tinycc-sysv-libc.M1 $out/share/darwin-bootstrap/

        cat > $out/bin/tcc-darwin-cc <<'SH'
        #!${stdenv.shell}
        set -euo pipefail

        out=a.out
        compile_only=0
        preprocess_only=0
        args=()
        inputs=()
        prepared_inputs=()
        objects=()
        archives=()
        library_dirs=()
        libraries=()
        include_dirs=(@INCLUDE@)
        cleanup_files=()

        while (($#)); do
          case "$1" in
            --version|-version)
              echo "tcc-darwin-cc bootstrap wrapper"
              exit 0
              ;;
            -c)
              compile_only=1
              args+=("$1")
              shift
              ;;
            -E)
              preprocess_only=1
              args+=("$1")
              shift
              ;;
            -o)
              out="$2"
              if ((compile_only)); then
                args+=("-o" "$2")
              fi
              shift 2
              ;;
            -o*)
              out="''${1#-o}"
              if ((compile_only)); then
                args+=("$1")
              fi
              shift
              ;;
            -I)
              args+=("$1" "$2")
              include_dirs+=("$2")
              shift 2
              ;;
            -I*)
              args+=("$1")
              include_dirs+=("''${1#-I}")
              shift
              ;;
            *.c)
              inputs+=("$1")
              shift
              ;;
            *.o)
              objects+=("$1")
              shift
              ;;
            *.a)
              case "$1" in
                /*) archives+=("$1") ;;
                *) archives+=("$(pwd)/$1") ;;
              esac
              shift
              ;;
            -L)
              library_dirs+=("$2")
              shift 2
              ;;
            -L*)
              library_dirs+=("''${1#-L}")
              shift
              ;;
            -l*)
              libraries+=("''${1#-l}")
              shift
              ;;
            *)
              args+=("$1")
              shift
              ;;
          esac
        done

        materialize_quote_headers() {
          for dir in "''${include_dirs[@]}"; do
            test -d "$dir" || continue
            for header in "$dir"/*.h "$dir"/*/*.h; do
              test -f "$header" || continue
              rel="''${header#$dir/}"
              mkdir -p "$(dirname "$rel")"
              test -e "$rel" || ln -s "$header" "$rel" 2>/dev/null || true
            done
          done
        }

        prepare_source_inputs() {
          local index=0
          for input in "''${inputs[@]}"; do
            case "$input" in
              */*)
                local copy=".tcc-darwin-input-$index.c"
                cp "$input" "$copy"
                cleanup_files+=("$copy")
                prepared_inputs+=("$copy")
                include_dirs+=("$(dirname "$input")")
                ;;
              *)
                prepared_inputs+=("$input")
                ;;
            esac
            index=$((index + 1))
          done
        }

        resolve_libraries() {
          local lib dir path found
          for lib in "''${libraries[@]}"; do
            found=0
            for dir in "''${library_dirs[@]}" .; do
              path="$dir/lib$lib.a"
              if [ -f "$path" ]; then
                case "$path" in
                  /*) archives+=("$path") ;;
                  *) archives+=("$(cd "$(dirname "$path")" && pwd)/$(basename "$path")") ;;
                esac
                found=1
                break
              fi
            done
            if [ "$found" = 0 ]; then
              echo "tcc-darwin-cc: library not found: -l$lib" >&2
              return 1
            fi
          done
        }

        expand_archives() {
          local archive archive_dir member archive_index=0
          for archive in "''${archives[@]}"; do
            archive_dir="$tmp/archive-$archive_index"
            mkdir -p "$archive_dir"
            (cd "$archive_dir" && @AR@ -x "$archive")
            for member in "$archive_dir"/*.o; do
              test -f "$member" || continue
              objects+=("$member")
            done
            archive_index=$((archive_index + 1))
          done
        }

        cleanup() {
          for file in "''${cleanup_files[@]}"; do
            rm -f "$file"
          done
        }
        trap cleanup EXIT

        if ((compile_only || preprocess_only)); then
          prepare_source_inputs
          materialize_quote_headers
          @TCC@ "''${args[@]}" -I@INCLUDE@ "''${prepared_inputs[@]}" "''${objects[@]}"
          exit "$?"
        fi

        tmp="$(mktemp -d)"
        trap 'cleanup; rm -rf "$tmp"' EXIT

        prepare_source_inputs
        materialize_quote_headers
        object_index=0
        for input in "''${prepared_inputs[@]}"; do
          object="$tmp/source-$object_index.o"
          @TCC@ -c "''${args[@]}" -I@INCLUDE@ "$input" -o "$object"
          objects+=("$object")
          object_index=$((object_index + 1))
        done
        resolve_libraries
        expand_archives

        code_files=()
        data_files=()
        object_index=0
        for object in "''${objects[@]}"; do
          m1="$tmp/object-$object_index.M1"
          @PYTHON@ @ELF_TO_M1@ --prefix "obj_$object_index"_ "$object" "$m1"
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' "$m1" > "$tmp/object-$object_index.code.M1"
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' "$m1" > "$tmp/object-$object_index.data.M1"
          code_files+=("$tmp/object-$object_index.code.M1")
          data_files+=("$tmp/object-$object_index.data.M1")
          object_index=$((object_index + 1))
        done

        {
          cat @CRT1@
          cat @SYSCALLS@
          for file in "''${code_files[@]}"; do cat "$file"; done
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data != 1 { print }' @LIBC_M1@
          echo ':ELF_data'
          echo ':HEX2_data'
          for file in "''${data_files[@]}"; do cat "$file"; done
          awk '/^:ELF_data$/ { data = 1; next } /^:HEX2_data$/ { next } data == 1 { print }' @LIBC_M1@
        } > "$tmp/combined.M1"

        @M1@ --architecture amd64 --little-endian -f "$tmp/combined.M1" -o "$tmp/combined.hex2"
        @HEX2@ --architecture amd64 --little-endian --base-address 0x1000000 \
          -f @MACHO@ -f "$tmp/combined.hex2" -o "$out"
        @PYTHON@ @HEX2_RELOCS@ patch "$tmp/combined.hex2" "$out"
        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of="$out" bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc 2>/dev/null
        chmod +x "$out"
        source @SIGNING@
        sign "$out"
        SH

        substituteInPlace $out/bin/tcc-darwin-cc \
          --replace-fail @TCC@ ${phase38-tinycc-boot3-link-candidate}/bin/tcc-boot3-candidate \
          --replace-fail @AR@ ${cctools}/bin/ar \
          --replace-fail @INCLUDE@ $out/include/tcc-darwin-bootstrap \
          --replace-fail @PYTHON@ ${python3}/bin/python3 \
          --replace-fail @ELF_TO_M1@ ${./tools/elf64-to-m1.py} \
          --replace-fail @HEX2_RELOCS@ ${./tools/hex2-data-relocs.py} \
          --replace-fail @M1@ ${phase9-m1}/bin/M1 \
          --replace-fail @HEX2@ ${phase10-hex2}/bin/hex2 \
          --replace-fail @MACHO@ ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          --replace-fail @CRT1@ $out/share/darwin-bootstrap/crt1-tcc-sysv.M1 \
          --replace-fail @SYSCALLS@ ${./bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1} \
          --replace-fail @LIBC_M1@ $out/share/darwin-bootstrap/tinycc-sysv-libc.M1 \
          --replace-fail @SIGNING@ ${darwin.signingUtils}
        chmod +x $out/bin/tcc-darwin-cc

        cat > hello.c <<'C'
        int main(void) { return 42; }
        C
        $out/bin/tcc-darwin-cc hello.c -o hello
        set +e
        ./hello
        status="$?"
        set -e
        test "$status" = 42

        cat > data-reloc.c <<'C'
        static long x;
        static long *p = &x;
        int main(void) { return p == &x && x == 0 ? 0 : 3; }
        C
        $out/bin/tcc-darwin-cc data-reloc.c -o data-reloc
        ./data-reloc

        cat > function-reloc.c <<'C'
        int f(int x) { return x + 1; }
        int (*fp)(int) = f;
        struct entry { const char *name; int (*fn)(int); };
        struct entry table[] = { { "f", f }, { 0, 0 } };
        int main(void) { if (fp(41) != 42) return 1; if (table[0].fn(41) != 42) return 2; return 0; }
        C
        $out/bin/tcc-darwin-cc function-reloc.c -o function-reloc
        ./function-reloc

        cat > string-reloc.c <<'C'
        #include <stdio.h>
        int main(void) { fputs("FIRST", stdout); fputs("SECOND", stdout); return 0; }
        C
        $out/bin/tcc-darwin-cc string-reloc.c -o string-reloc
        test "$(./string-reloc)" = FIRSTSECOND

        $out/bin/tcc-darwin-cc -c hello.c -o hello.o
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        cp tinycc-sysv-libc.o tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
          hello.c hello data-reloc.c data-reloc function-reloc.c function-reloc \
          string-reloc.c string-reloc hello.o \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase39-gnumake =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase39-gnumake-${gnumakeVersion}-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        tar -xzf ${gnumakeTarball}
        cd make-${gnumakeVersion}

        substituteInPlace src/read.c \
          --replace-fail '    "/usr/gnu/include",' "" \
          --replace-fail '    "/usr/local/include",' "" \
          --replace-fail '    "/usr/include",' ""
        substituteInPlace src/remake.c \
          --replace-fail '      "/lib",' "" \
          --replace-fail '      "/usr/lib",' ""
        substituteInPlace src/job.c \
          --replace-fail '#if defined(__MSDOS__) || defined(VMS) || defined(_AMIGA) || defined(__riscos__)' '#if defined(__MSDOS__) || defined(VMS) || defined(_AMIGA) || defined(__riscos__) || defined(__TINYC__)'
        substituteInPlace src/main.c \
          --replace-fail '              putenv (b);' '              (void) b;'
        substituteInPlace src/misc.c \
          --replace-fail "if (*mktemp (path) == '\\0')" 'if (!strcmp (mktemp (path), ""))'
        substituteInPlace lib/glob.c \
          --replace-fail 'extern char *alloca ();' '/* bootstrap: alloca macro maps to malloc */'

        cat src/mkconfig.h src/mkcustom.h > src/config.h
        cp lib/glob.in.h lib/glob.h
        cp lib/fnmatch.in.h lib/fnmatch.h

        export CC=${phase34-tinycc-darwin-cc}/bin/tcc-darwin-cc
        export CFLAGS="-I./src -I./lib -DHAVE_CONFIG_H -DMAKE_MAINTAINER_MODE -DLIBDIR=\"$out/lib\" -DLOCALEDIR=\"/fake-locale\" -DPOSIX=1 -DNO_ARCHIVES=1 -DNO_OUTPUT_SYNC=1 -DO_TMPFILE=020000000 -DFILE_TIMESTAMP_HI_RES=0 -Dalloca=malloc -DHAVE_ATEXIT -DHAVE_DECL_BSD_SIGNAL=0 -DHAVE_DECL_GETLOADAVG=0 -DHAVE_DECL_SYS_SIGLIST=0 -DHAVE_DECL__SYS_SIGLIST=0 -DHAVE_DECL___SYS_SIGLIST=0 -DHAVE_DIRENT_H -DHAVE_DUP2 -DHAVE_FCNTL_H -DHAVE_FDOPEN -DHAVE_GETCWD -DHAVE_GETTIMEOFDAY -DHAVE_INTTYPES_H -DHAVE_ISATTY -DHAVE_LIMITS_H -DHAVE_LOCALE_H -DHAVE_MEMORY_H -DHAVE_MKTEMP -DHAVE_SETVBUF -DHAVE_SIGSETMASK -DHAVE_STDINT_H -DHAVE_STDLIB_H -DHAVE_STRDUP -DHAVE_STRERROR -DHAVE_STRINGS_H -DHAVE_STRING_H -DHAVE_STRTOLL -DHAVE_SYS_FILE_H -DHAVE_SYS_PARAM_H -DHAVE_SYS_RESOURCE_H -DHAVE_SYS_SELECT_H -DHAVE_SYS_STAT_H -DHAVE_SYS_TIME_H -DHAVE_SYS_WAIT_H -DHAVE_TTYNAME -DHAVE_UMASK -DHAVE_UNISTD_H -DHAVE_WAITPID -DMAKE_JOBSERVER -DMAKE_SYMLINKS -DPATH_SEPARATOR_CHAR=0x3a"
        export CFLAGS="$CFLAGS -DSCCS_GET=\"get\" -DSTDC_HEADERS -Dvfork=fork"

        sources='src/commands.c src/default.c src/dir.c src/expand.c src/file.c src/function.c src/getopt.c src/getopt1.c src/guile.c src/hash.c src/implicit.c src/job.c src/load.c src/loadapi.c src/main.c src/misc.c src/output.c src/read.c src/remake.c src/rule.c src/shuffle.c src/signame.c src/strcache.c src/variable.c src/version.c src/vpath.c lib/fnmatch.c lib/glob.c src/remote-stub.c src/posixos.c'
        objects=
        for source in $sources; do
          object="$(basename "$source" .c).o"
          $CC $CFLAGS -c "$source" -o "$object" > "$object.stdout" 2> "$object.stderr"
          objects="$objects $object"
        done

        $CC $CFLAGS -o make $objects > make-link.stdout 2> make-link.stderr
        ./make --version > make-version.stdout 2> make-version.stderr
        grep -q 'GNU Make' make-version.stdout
        test ! -s make-version.stderr
        cat > bootstrap-smoke.mk <<'MK'
        all:
        	echo hi
        MK
        MAKEFLAGS= ./make -f bootstrap-smoke.mk > make-smoke.stdout 2> make-smoke.stderr
        grep -q 'echo hi' make-smoke.stdout

        install -Dm755 make $out/bin/make
        cp make-version.stdout make-version.stderr make-smoke.stdout make-smoke.stderr \
          make-link.stdout make-link.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase40-gnupatch =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase40-gnupatch-${gnupatchVersion}-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        tar -xzf ${gnupatchTarball}
        cd patch-${gnupatchVersion}

        cat > config.h <<'H'
        H

        export CC=${phase34-tinycc-darwin-cc}/bin/tcc-darwin-cc
        export CFLAGS="-I. -DNULL=0 -DHAVE_DECL_GETENV -DHAVE_DECL_MALLOC -DHAVE_DIRENT_H -DHAVE_LIMITS_H -DHAVE_GETEUID -DHAVE_MKTEMP -DPACKAGE_BUGREPORT= -Ded_PROGRAM=\"/nullop\" -Dmbstate_t=int -DRETSIGTYPE=int -DHAVE_MKDIR -DHAVE_RMDIR -DHAVE_FCNTL_H -DPACKAGE_NAME=\"patch\" -DPACKAGE_VERSION=\"${gnupatchVersion}\" -DHAVE_MALLOC -DHAVE_REALLOC -DSTDC_HEADERS -DHAVE_STRING_H -DHAVE_STDLIB_H -DHAVE_VPRINTF"

        sources='addext.c argmatch.c backupfile.c basename.c dirname.c getopt.c getopt1.c inp.c maketime.c partime.c patch.c pch.c quote.c quotearg.c quotesys.c util.c version.c xmalloc.c error.c'
        objects=
        for source in $sources; do
          object="$(basename "$source" .c).o"
          $CC $CFLAGS -c "$source" -o "$object" > "$object.stdout" 2> "$object.stderr"
          objects="$objects $object"
        done

        $CC $CFLAGS -o patch $objects > patch-link.stdout 2> patch-link.stderr
        ./patch --version > patch-version.stdout 2> patch-version.stderr
        grep -q 'patch ${gnupatchVersion}' patch-version.stdout
        printf 'a\n' > patch-smoke-file
        cat > patch-smoke.diff <<'P'
        --- patch-smoke-file
        +++ patch-smoke-file
        @@ -1 +1 @@
        -a
        +b
        P
        ./patch -p0 -i patch-smoke.diff > patch-smoke.stdout 2> patch-smoke.stderr
        grep -q '^b$' patch-smoke-file

        install -Dm755 patch $out/bin/patch
        cp patch-version.stdout patch-version.stderr patch-smoke.stdout patch-smoke.stderr \
          patch-link.stdout patch-link.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null;

  phase41-coreutils =
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase41-coreutils-${coreutilsVersion}-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        tar -xzf ${coreutilsTarball}
        cd coreutils-${coreutilsVersion}

        for patch_file in ${lib.escapeShellArgs coreutilsPatches}; do
          ${phase40-gnupatch}/bin/patch -Np0 -i "$patch_file"
        done

        cat > config.h <<'H'
        H
        cp lib/fnmatch_.h lib/fnmatch.h
        substituteInPlace lib/fnmatch.h \
          --replace-fail '# if !defined _POSIX_C_SOURCE || _POSIX_C_SOURCE < 2 || defined _GNU_SOURCE' '# if 1'
        cp lib/ftw_.h lib/ftw.h
        cp lib/search_.h lib/search.h
        rm src/dircolors.h

        {
          echo 'include ${coreutilsMakefile}'
          for source in src/*.c lib/*.c; do
            object="''${source%.c}.o"
            printf '%s: %s\n' "$object" "$source"
            printf '\t$(CC) $(CFLAGS) -c -o $@ $<\n\n'
          done
        } > bootstrap-coreutils.mk

        export CC=${phase34-tinycc-darwin-cc}/bin/tcc-darwin-cc
        MAKEFLAGS= ${phase39-gnumake}/bin/make -f bootstrap-coreutils.mk \
          CC="$CC -DNULL=0 -D_GNU_SOURCE=1 -DHAVE_SYS_TYPES_H=1 -DFILESYSTEM_PREFIX_LEN\(Filename\)=0 -DISSLASH\(C\)=\(\(C\)==47\)" \
          AR=${cctools}/bin/ar \
          PREFIX="$out" \
          > coreutils-build.stdout \
          2> coreutils-build.stderr

        ./src/echo "Hello coreutils!" > coreutils-smoke.stdout 2> coreutils-smoke.stderr
        grep -q "Hello coreutils!" coreutils-smoke.stdout

        MAKEFLAGS= ${phase39-gnumake}/bin/make -f bootstrap-coreutils.mk install \
          PREFIX="$out" \
          > coreutils-install.stdout \
          2> coreutils-install.stderr

        cp coreutils-build.stdout coreutils-build.stderr \
          coreutils-smoke.stdout coreutils-smoke.stderr \
          coreutils-install.stdout coreutils-install.stderr \
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
    phase16-mes-m2
    phase17-mescc-macho-probe
    phase18-mescc-libc-mini-probe
    phase19-tinycc-mescc-m1-probe
    phase20-mescc-libmescc-probe
    phase21-mescc-libc-probe
    phase22-mescc-libc-tcc-probe
    phase23-tinycc-mescc-link-probe
    phase24-tinycc-compile-probe
    phase25-tinycc-self-object-probe
    phase26-gcc46-source
    gcc46DarwinBootstrapSrc
    phase35-gcc46-all-gcc
    phase36-gcc46-cc1
    phase27-tinycc-elf-to-macho-probe
    phase28-tinycc-self-m1-probe
    phase29-tinycc-sysv-libc-probe
    phase30-tinycc-self-link-candidate
    phase31-tinycc-self-compile-probe
    phase32-tinycc-boot1-object-probe
    phase33-tinycc-boot1-link-candidate
    phase34-tinycc-darwin-cc
    phase35-tinycc-boot2-object-probe
    phase36-tinycc-boot2-link-candidate
    phase37-tinycc-boot3-object-probe
    phase38-tinycc-boot3-link-candidate
    phase39-gnumake
    phase40-gnupatch
    phase41-coreutils
    tinycc-m2-negative-probe
    tinyccBootstrappableSrc
    tinyccMesSrc
    tests
    ;
}
