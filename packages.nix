{
  darwin,
  cctools,
  fetchurl,
  gcc_latest,
  gnumake,
  lib,
  minimal-bootstrap-sources,
  perl,
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

  sources = import ./sources.nix { inherit fetchurl gcc_latest; };

  inherit (sources)
    mesVersion
    mesTarball
    gcc46Version
    gcc46Tarball
    gcc46GmpTarball
    gcc46MpfrTarball
    gcc46MpcTarball
    gcc10Version
    gcc10Tarball
    gcc10GmpVersion
    gcc10GmpTarball
    gccLatestVersion
    gccLatestTarball
    gnuHelloVersion
    gnuHelloTarball
    gccLatestGmpVersion
    gccLatestGmpTarball
    gccModernMpfrVersion
    gccModernMpfrTarball
    gccModernMpcVersion
    gccModernMpcTarball
    gccModernIslVersion
    gccModernIslTarball
    gnumakeVersion
    gnumakeTarball
    gnupatchVersion
    gnupatchTarball
    coreutilsVersion
    coreutilsLiveBootstrap
    coreutilsTarball
    coreutilsMakefile
    coreutilsPatches
    nyaccVersion
    nyaccTarball
    ;

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
    version = "0-unstable-2026-05-17";

    src = ./hex0;
    strictDeps = true;
    dontStrip = true;

    buildPhase = ''
      runHook preBuild
      $CC $CFLAGS -o hex0-materializer hex0.c
      ./hex0-materializer hex0-amd64-darwin.hex0 hex0
      chmod +x hex0

      ./hex0 hex0-amd64-darwin.hex0 hex0-self
      cmp hex0 hex0-self

      cat > smoke.hex0 <<'HEX'
        # whitespace, comments, and mixed-case nybbles are intentional
        48 65 6c 6c 6F 0a ; Hello newline
      HEX
      ./hex0 smoke.hex0 smoke.out
      printf 'Hello\n' > smoke.expected
      cmp smoke.expected smoke.out
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 hex0 $out/bin/hex0
      install -Dm644 hex0-amd64-darwin.hex0 $out/share/darwin-bootstrap/hex0-amd64-darwin.hex0
      install -Dm644 hex0-amd64-darwin.S $out/share/darwin-bootstrap/hex0-amd64-darwin.S
      install -Dm644 README.md $out/share/darwin-bootstrap/README.hex0.md
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

  phaseContext = {
    root = ./.;
    inherit darwin cctools fetchurl gnumake lib minimal-bootstrap-sources perl python3;
    inherit stdenv runCommand hostPlatform supportedSystems arch source;
    inherit stage0-posix stage0Sources mesVersion mesTarball gcc46Version gcc46Tarball;
    inherit gcc46GmpTarball gcc46MpfrTarball gcc46MpcTarball gcc10Version gcc10Tarball gcc10GmpVersion;
    inherit gcc10GmpTarball gccLatestVersion gccLatestTarball gccLatestGmpVersion gccLatestGmpTarball gccModernMpfrVersion;
    inherit gccModernMpfrTarball gccModernMpcVersion gccModernMpcTarball gccModernIslVersion gccModernIslTarball gnumakeVersion;
    inherit gnumakeTarball gnupatchVersion gnupatchTarball coreutilsVersion coreutilsLiveBootstrap coreutilsTarball;
    inherit coreutilsMakefile coreutilsPatches nyaccVersion nyaccTarball mesNyacc mesDarwinConfigH;
    inherit tinyccBootstrappableSrc tinyccMesSrc hex0;
  };

  phaseDefs = rec {
    phase1-hex1 = import ./phases/phase1-hex1.nix (phaseContext // phaseDefs);
    phase2-hex2 = import ./phases/phase2-hex2.nix (phaseContext // phaseDefs);
    phase2-catm = import ./phases/phase2-catm.nix (phaseContext // phaseDefs);
    phase3-m0 = import ./phases/phase3-m0.nix (phaseContext // phaseDefs);
    phase4-cc-arch = import ./phases/phase4-cc-arch.nix (phaseContext // phaseDefs);
    phase5-m2 = import ./phases/phase5-m2.nix (phaseContext // phaseDefs);
    phase6-blood-macho-0 = import ./phases/phase6-blood-macho-0.nix (phaseContext // phaseDefs);
    phase7-m1-0 = import ./phases/phase7-m1-0.nix (phaseContext // phaseDefs);
    phase8-hex2-1 = import ./phases/phase8-hex2-1.nix (phaseContext // phaseDefs);
    phase9-m1 = import ./phases/phase9-m1.nix (phaseContext // phaseDefs);
    phase10-hex2 = import ./phases/phase10-hex2.nix (phaseContext // phaseDefs);
    phase11-kaem = import ./phases/phase11-kaem.nix (phaseContext // phaseDefs);
    phase12-m2-planet = import ./phases/phase12-m2-planet.nix (phaseContext // phaseDefs);
    phase13-mes-source = import ./phases/phase13-mes-source.nix (phaseContext // phaseDefs);
    phase14-mes-m2-probe = import ./phases/phase14-mes-m2-probe.nix (phaseContext // phaseDefs);
    phase15-mes-macho-link-probe = import ./phases/phase15-mes-macho-link-probe.nix (phaseContext // phaseDefs);
    phase16-mes-m2 = import ./phases/phase16-mes-m2.nix (phaseContext // phaseDefs);
    phase17-mescc-macho-probe = import ./phases/phase17-mescc-macho-probe.nix (phaseContext // phaseDefs);
    phase18-mescc-libc-mini-probe = import ./phases/phase18-mescc-libc-mini-probe.nix (phaseContext // phaseDefs);
    phase19-tinycc-mescc-m1-probe = import ./phases/phase19-tinycc-mescc-m1-probe.nix (phaseContext // phaseDefs);
    phase20-mescc-libmescc-probe = import ./phases/phase20-mescc-libmescc-probe.nix (phaseContext // phaseDefs);
    phase21-mescc-libc-probe = import ./phases/phase21-mescc-libc-probe.nix (phaseContext // phaseDefs);
    phase22-mescc-libc-tcc-probe = import ./phases/phase22-mescc-libc-tcc-probe.nix (phaseContext // phaseDefs);
    phase23-tinycc-mescc-link-probe = import ./phases/phase23-tinycc-mescc-link-probe.nix (phaseContext // phaseDefs);
    phase24-tinycc-compile-probe = import ./phases/phase24-tinycc-compile-probe.nix (phaseContext // phaseDefs);
    phase25-tinycc-self-object-probe = import ./phases/phase25-tinycc-self-object-probe.nix (phaseContext // phaseDefs);
    phase26-gcc46-source = import ./phases/phase26-gcc46-source.nix (phaseContext // phaseDefs);
    phase42-gcc10-source = import ./phases/phase42-gcc10-source.nix (phaseContext // phaseDefs);
    phase43-gcc-latest-source = import ./phases/phase43-gcc-latest-source.nix (phaseContext // phaseDefs);
    gcc46DarwinBootstrapSrc = import ./phases/gcc46DarwinBootstrapSrc.nix (phaseContext // phaseDefs);
    phase35-gcc46-all-gcc = import ./phases/phase35-gcc46-all-gcc.nix (phaseContext // phaseDefs);
    phase36-gcc46-libgcc = import ./phases/phase36-gcc46-libgcc.nix (phaseContext // phaseDefs);
    phase37-gcc46-bootstrap = import ./phases/phase37-gcc46-bootstrap.nix (phaseContext // phaseDefs);
    phase27-tinycc-elf-to-macho-probe = import ./phases/phase27-tinycc-elf-to-macho-probe.nix (phaseContext // phaseDefs);
    phase28-tinycc-self-m1-probe = import ./phases/phase28-tinycc-self-m1-probe.nix (phaseContext // phaseDefs);
    phase29-tinycc-sysv-libc-probe = import ./phases/phase29-tinycc-sysv-libc-probe.nix (phaseContext // phaseDefs);
    phase30-tinycc-self-link-candidate = import ./phases/phase30-tinycc-self-link-candidate.nix (phaseContext // phaseDefs);
    phase31-tinycc-self-compile-probe = import ./phases/phase31-tinycc-self-compile-probe.nix (phaseContext // phaseDefs);
    phase32-tinycc-boot1-object-probe = import ./phases/phase32-tinycc-boot1-object-probe.nix (phaseContext // phaseDefs);
    phase33-tinycc-boot1-link-candidate = import ./phases/phase33-tinycc-boot1-link-candidate.nix (phaseContext // phaseDefs);
    tinyccSelfObjectProbe = import ./phases/tinyccSelfObjectProbe.nix (phaseContext // phaseDefs);
    tinyccSelfLinkCandidate = import ./phases/tinyccSelfLinkCandidate.nix (phaseContext // phaseDefs);
    phase35-tinycc-boot2-object-probe = import ./phases/phase35-tinycc-boot2-object-probe.nix (phaseContext // phaseDefs);
    phase36-tinycc-boot2-link-candidate = import ./phases/phase36-tinycc-boot2-link-candidate.nix (phaseContext // phaseDefs);
    phase37-tinycc-boot3-object-probe = import ./phases/phase37-tinycc-boot3-object-probe.nix (phaseContext // phaseDefs);
    phase38-tinycc-boot3-link-candidate = import ./phases/phase38-tinycc-boot3-link-candidate.nix (phaseContext // phaseDefs);
    phase34-tinycc-darwin-cc = import ./phases/phase34-tinycc-darwin-cc.nix (phaseContext // phaseDefs);
    phase39-gnumake = import ./phases/phase39-gnumake.nix (phaseContext // phaseDefs);
    phase40-gnupatch = import ./phases/phase40-gnupatch.nix (phaseContext // phaseDefs);
    phase41-coreutils = import ./phases/phase41-coreutils.nix (phaseContext // phaseDefs);
    phase44-gcc46-cxx-bootstrap = import ./phases/phase44-gcc46-cxx-bootstrap.nix (phaseContext // phaseDefs);
    phase45-gcc10-bootstrap = import ./phases/phase45-gcc10-bootstrap.nix (phaseContext // phaseDefs);
    phase46-gcc-latest-bootstrap = import ./phases/phase46-gcc-latest-bootstrap.nix (phaseContext // phaseDefs);
    phase47-gcc-latest-strict-bootstrap = import ./phases/phase47-gcc-latest-strict-bootstrap.nix (phaseContext // phaseDefs);
  };

  inherit (phaseDefs)
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
    phase42-gcc10-source
    phase43-gcc-latest-source
    gcc46DarwinBootstrapSrc
    phase35-gcc46-all-gcc
    phase36-gcc46-libgcc
    phase37-gcc46-bootstrap
    phase27-tinycc-elf-to-macho-probe
    phase28-tinycc-self-m1-probe
    phase29-tinycc-sysv-libc-probe
    phase30-tinycc-self-link-candidate
    phase31-tinycc-self-compile-probe
    phase32-tinycc-boot1-object-probe
    phase33-tinycc-boot1-link-candidate
    tinyccSelfObjectProbe
    tinyccSelfLinkCandidate
    phase35-tinycc-boot2-object-probe
    phase36-tinycc-boot2-link-candidate
    phase37-tinycc-boot3-object-probe
    phase38-tinycc-boot3-link-candidate
    phase34-tinycc-darwin-cc
    phase39-gnumake
    phase40-gnupatch
    phase41-coreutils
    phase44-gcc46-cxx-bootstrap
    phase45-gcc10-bootstrap
    phase46-gcc-latest-bootstrap
    phase47-gcc-latest-strict-bootstrap
    ;
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

  gnuHello = import ./gnu-hello.nix (
    phaseContext
    // phaseDefs
    // {
      inherit gcc_latest gnuHelloVersion gnuHelloTarball;
    }
  );

  inherit (gnuHello)
    gnu-hello-gcc-latest-bootstrap
    gnu-hello-gcc-latest-strict
    gnu-hello-nixpkgs-gcc-latest
    gnu-hello-hash-comparison
    ;

  tests = import ./checks.nix (phaseContext // phaseDefs // {
    inherit
      darwin
      hex0
      raw-syscall-hello
      raw-syscall-hello-unsigned
      m2libcDarwinSmoke
      machoTemplateHelloRuns
      gnu-hello-hash-comparison
      ;
  });
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
    phase42-gcc10-source
    phase43-gcc-latest-source
    gcc46DarwinBootstrapSrc
    phase35-gcc46-all-gcc
    phase36-gcc46-libgcc
    phase37-gcc46-bootstrap
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
    phase44-gcc46-cxx-bootstrap
    phase45-gcc10-bootstrap
    phase46-gcc-latest-bootstrap
    phase47-gcc-latest-strict-bootstrap
    gnu-hello-gcc-latest-bootstrap
    gnu-hello-gcc-latest-strict
    gnu-hello-nixpkgs-gcc-latest
    gnu-hello-hash-comparison
    tinycc-m2-negative-probe
    tinyccBootstrappableSrc
    tinyccMesSrc
    tests
    ;
}
