{
  apple-sdk,
  darwin,
  cctools,
  fetchurl,
  findutils,
  gcc_latest,
  gnutar,
  gnumake,
  gzip,
  lib,
  minimal-bootstrap-sources,
  perl,
  stdenv,
  runCommand,
}:

let
  root = ./.;
  hostPlatform = stdenv.hostPlatform;

  ## Build this once with the raw stdenv, then reuse the exact signed tool
  ## copies in every bootstrap runCommand.  This changes only Mach-O execution
  ## metadata at the disclosed host-orchestration boundary and prevents a
  ## fresh chain from repeatedly entering taskgated's leaking unsigned path.
  signedBuildTools = runCommand "darwin-signed-build-tools" {
    __impureHostDeps = [ "/usr/bin/codesign" ];
  } ''
    DARWIN_SIGNED_BUILD_TOOLS="$out/bin"
    DARWIN_SIGNED_COPY="$(command -v cp)"
    DARWIN_SIGNED_CHMOD="$(command -v chmod)"
    DARWIN_SIGNED_MKDIR="$(command -v mkdir)"
    export DARWIN_SIGNED_BUILD_TOOLS
    source ${root + "/scripts/darwin/prepare-signed-build-tools.sh"}
    prepare_signed_build_tool cctools-codesign-allocate ${cctools}/bin/codesign_allocate
    prepare_signed_build_tool tinycc-codesign ${darwin.sigtool}/bin/codesign
    prepare_signed_build_tool tinycc-sigtool ${darwin.sigtool}/bin/sigtool
    # Preserve nixpkgs's darwin.sigtool package interface so every generated
    # wrapper that embeds ${darwin.sigtool}/bin/{codesign,sigtool} resolves to
    # the same strict-valid shared copies.  In particular, tcc-darwin-cc calls
    # sigtool after linking; leaving that one absolute path on the original
    # unsigned closure re-entered taskgated and failed outside all-gcc's
    # private tool directory.
    "$out/bin/ln" -s tinycc-codesign "$out/bin/codesign"
    "$out/bin/ln" -s tinycc-sigtool "$out/bin/sigtool"

    # Keep nixpkgs's pinned signing implementation, but ensure its own
    # execution helpers do not re-enter taskgated for every stage output.
    export PATH="$DARWIN_SIGNED_BUILD_TOOLS:$PATH"
    mkdir -p "$out/share/darwin-bootstrap"
    cp ${darwin.signingUtils} "$out/share/darwin-bootstrap/signing-utils"
    substituteInPlace "$out/share/darwin-bootstrap/signing-utils" \
      --replace-fail ${cctools}/bin/codesign_allocate "$out/bin/cctools-codesign-allocate" \
      --replace-fail ${darwin.sigtool}/bin/codesign "$out/bin/tinycc-codesign" \
      --replace-fail ${darwin.sigtool}/bin/sigtool "$out/bin/tinycc-sigtool"
  '';
  bootstrapDarwin = darwin // {
    signingUtils = "${signedBuildTools}/share/darwin-bootstrap/signing-utils";
    sigtool = signedBuildTools;
  };
  signedRunCommand = name: attrs: buildCommand:
    runCommand name (attrs // {
      nativeBuildInputs = (attrs.nativeBuildInputs or [ ]) ++ [ signedBuildTools ];
    }) ''
      export PATH="${signedBuildTools}/bin:$PATH"
      export CONFIG_SHELL="${signedBuildTools}/bin/bash"
      export SHELL="${signedBuildTools}/bin/bash"
      ${buildCommand}
    '';
  signedMkDarwin = attrs:
    utils.mkDarwin (attrs // {
      nativeBuildInputs = (attrs.nativeBuildInputs or [ ]) ++ [ signedBuildTools ];
      preBuild = ''
        export PATH="${signedBuildTools}/bin:$PATH"
        export CONFIG_SHELL="${signedBuildTools}/bin/bash"
        export SHELL="${signedBuildTools}/bin/bash"
        ${attrs.preBuild or ""}
      '';
    });

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

  tinyccBootstrappableSrc = signedRunCommand "darwin-bootstrap-tinycc-bootstrappable-source" { } ''
    mkdir -p $out
    cp -R ${./vendor/tinycc-bootstrappable}/. $out/
  '';

  tinyccMesSrc = signedRunCommand "darwin-bootstrap-tinycc-mes-source" { } ''
    mkdir -p $out
    cp -R ${tinyccBootstrappableSrc}/. $out/
    chmod -R u+w $out
    cd $out

    patch -p1 < ${./patches/tinycc-mes-bootstrap.patch}
    : > config.h
  '';

  hex0 = import ./stage0-posix/hex0.nix { inherit hostPlatform lib root stdenv supportedSystems tests; };

  m2libc-darwin = signedRunCommand "darwin-minimal-bootstrap-m2libc" { } ''
    mkdir -p $out
    cp -R ${./M2libc}/. $out/
  '';

  inherit (import ./hello { inherit lib stdenv supportedSystems source tests; })
    raw-syscall-hello
    raw-syscall-hello-unsigned
    ;

  utils = import ./utils.nix { inherit stdenv lib; };

  phaseContext = {
    inherit root;
    mkDarwin = signedMkDarwin;
    darwin = bootstrapDarwin;
    inherit apple-sdk cctools fetchurl findutils gnutar gnumake gzip lib minimal-bootstrap-sources perl;
    inherit stdenv hostPlatform supportedSystems arch source;
    runCommand = signedRunCommand;
    inherit stage0-posix stage0Sources mesVersion mesTarball gcc46Version gcc46Tarball;
    inherit gcc46GmpTarball gcc46MpfrTarball gcc46MpcTarball gcc10Version gcc10Tarball gcc10GmpVersion;
    inherit gcc10GmpTarball gccLatestVersion gccLatestTarball gccLatestGmpVersion gccLatestGmpTarball gccModernMpfrVersion;
    inherit gccModernMpfrTarball gccModernMpcVersion gccModernMpcTarball gccModernIslVersion gccModernIslTarball gnumakeVersion;
    inherit gnumakeTarball gnupatchVersion gnupatchTarball coreutilsVersion coreutilsLiveBootstrap coreutilsTarball;
    inherit coreutilsMakefile coreutilsPatches nyaccVersion nyaccTarball mesNyacc mesDarwinConfigH;
    inherit tinyccBootstrappableSrc tinyccMesSrc hex0;
  };

  ## Package scope, grouped by directory.  All packages take `phaseContext
  ## // phaseDefs` as their args and use explicit `{ a, b, ..., ... }:`
  ## arg lists so each .nix file declares what it depends on.  Mirrors
  ## nixpkgs's pkgs/os-specific/linux/minimal-bootstrap/default.nix layout.
  ##
  ## Attr names are semantic (`hex1`, `m0`, `tinycc-darwin-cc`, …) — no
  ## `phaseN-` prefix — and the whole `phaseDefs` rec set is splatted into
  ## the flake outputs directly (see the `in` body below); there is no
  ## separate alias layer.  Each phase is
  ## `import <path> (phaseContext // phaseDefs)`.
  callPhase = path: import path (phaseContext // phaseDefs);

  phaseDefs = {
    ## stage0-posix — hex0 through kaem
    hex1                  = callPhase ./stage0-posix/hex1.nix;
    hex2-0                  = callPhase ./stage0-posix/hex2.nix;
    catm                  = callPhase ./stage0-posix/catm.nix;
    m0                    = callPhase ./stage0-posix/m0.nix;
    cc-arch               = callPhase ./stage0-posix/cc-arch.nix;
    m2                    = callPhase ./stage0-posix/m2-planet.nix;
    blood-macho-0         = callPhase ./stage0-posix/blood-elf-macho.nix;
    m1-0                  = callPhase ./stage0-posix/M1-0.nix;
    hex2-1                = callPhase ./stage0-posix/hex2-1.nix;
    m1                    = callPhase ./stage0-posix/M1.nix;
    hex2                 = callPhase ./stage0-posix/hex2-linker.nix;
    kaem                 = callPhase ./stage0-posix/kaem.nix;

    ## mescc-tools — seed-built Darwin Mach-O helpers (m1-to-hex2, hex2-data-relocs,
    ## cc-arch-helper, macho-patcher, elf64-to-m1, m1-split, synth-inject)
    m1-to-hex2          = callPhase ./mescc-tools/m1-to-hex2.nix;
    hex2-data-relocs    = callPhase ./mescc-tools/hex2-data-relocs.nix;
    cc-arch-helper      = callPhase ./mescc-tools/cc-arch-helper.nix;
    macho-patcher-early = callPhase ./mescc-tools/macho-patcher-early.nix;
    elf64-to-m1         = callPhase ./mescc-tools/elf64-to-m1.nix;
    macho-patcher       = callPhase ./mescc-tools/macho-patcher.nix;
    m1-split            = callPhase ./mescc-tools/m1-split.nix;
    synth-inject        = callPhase ./mescc-tools/synth-inject.nix;

    ## mes — M2-Planet wrapper + mes-m2 build
    m2-planet            = callPhase ./mes/m2-planet.nix;
    mes-source           = callPhase ./mes/source.nix;
    mes-m2-probe         = callPhase ./mes/m2-compile.nix;
    mes-macho-link-probe = callPhase ./mes/m2-link.nix;
    mes-m2               = callPhase ./mes/m2.nix;

    ## mescc-libc — Mescc libc layers
    mescc-macho-probe       = callPhase ./mescc-libc/mescc-macho.nix;
    mescc-libc-mini-probe   = callPhase ./mescc-libc/libc-mini.nix;
    tinycc-mescc-m1-probe   = callPhase ./mescc-libc/tinycc-mescc-m1.nix;
    mescc-libmescc-probe    = callPhase ./mescc-libc/libmescc.nix;
    mescc-libc-probe        = callPhase ./mescc-libc/libc.nix;
    mescc-libc-tcc-probe    = callPhase ./mescc-libc/libc-tcc.nix;

    ## tinycc — Mescc-built TCC through full self-hosting
    tinycc-mescc-link-probe     = callPhase ./tinycc/mescc-link.nix;
    tinycc-compile-probe        = callPhase ./tinycc/compile.nix;
    tinycc-self-object-probe    = callPhase ./tinycc/self-object.nix;
    tinycc-elf-to-macho-probe   = callPhase ./tinycc/elf-to-macho.nix;
    tinycc-self-m1-probe        = callPhase ./tinycc/self-m1.nix;
    tinycc-sysv-libc-probe      = callPhase ./tinycc/sysv-libc.nix;
    tinycc-self-link-candidate  = callPhase ./tinycc/self-link.nix;
    tinycc-self-compile-probe   = callPhase ./tinycc/self-compile.nix;
    tinycc-boot1-object-probe   = callPhase ./tinycc/boot1-object.nix;
    tinycc-boot1-link-candidate = callPhase ./tinycc/boot1-link.nix;
    tinycc-darwin-cc            = callPhase ./tinycc/darwin-cc.nix;
    tinycc-boot2-object-probe   = callPhase ./tinycc/boot2-object.nix;
    tinycc-boot2-link-candidate = callPhase ./tinycc/boot2-link.nix;
    tinycc-boot3-object-probe   = callPhase ./tinycc/boot3-object.nix;
    tinycc-boot3-link-candidate = callPhase ./tinycc/boot3-link.nix;
    tinyccSelfObjectProbe               = callPhase ./tinycc/self-object-helper.nix;
    tinyccSelfLinkCandidate             = callPhase ./tinycc/self-link-candidate.nix;

    ## gnumake / gnupatch / coreutils
    bootstrap-gnumake   = callPhase ./gnumake;
    gnupatch  = callPhase ./gnupatch;
    coreutils-boot = callPhase ./coreutils;

    ## bootstrap-deps — GMP/MPFR/MPC/ISL built by the chain GCC-15 (gcc-latest)
    bootstrap-gmp  = callPhase ./bootstrap-deps/gmp.nix;
    bootstrap-mpfr = callPhase ./bootstrap-deps/mpfr.nix;
    bootstrap-mpc  = callPhase ./bootstrap-deps/mpc.nix;
    bootstrap-isl  = callPhase ./bootstrap-deps/isl.nix;

    ## gcc-4.6 — TCC builds GCC 4.6
    gcc46-source        = callPhase ./gcc-4.6/source.nix;
    gcc46DarwinBootstrapSrc     = callPhase ./gcc-4.6/darwin-bootstrap-src.nix;
    gcc46-all-gcc       = callPhase ./gcc-4.6/all-gcc.nix;
    gcc46-libgcc        = callPhase ./gcc-4.6/libgcc.nix;
    gcc46     = callPhase ./gcc-4.6/bootstrap.nix;
    gcc46-cxx = callPhase ./gcc-4.6/cxx.nix;

    ## gcc-10 — GCC 4.6 builds GCC 10
    gcc10-source    = callPhase ./gcc-10/source.nix;
    gcc10 = callPhase ./gcc-10;

    ## gcc-latest — GCC 10 builds gcc_latest + strict re-bootstrap
    gcc-latest-source           = callPhase ./gcc-latest/source.nix;
    gcc-latest        = callPhase ./gcc-latest;
    gcc-latest-strict = callPhase ./gcc-latest/strict.nix;

    ## cctools ar/ranlib drivers + their libstuff.a/libmacho.a support archives
    ## are all chain-compiled from source by gcc-15 (gcc-latest-strict); the
    ## support archives are still *packed* with host cctools `ar` (you need an
    ## archiver to build an archiver) — known boundary, see README.
    cctools-ar = callPhase ./cctools/ar.nix;
  };

  tinycc-m2-negative-probe = import ./tinycc/m2-negative-probe.nix (phaseContext // phaseDefs);

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
      hex0
      raw-syscall-hello
      raw-syscall-hello-unsigned
      tinycc-m2-negative-probe
      gnu-hello-hash-comparison
      ;
    darwin = bootstrapDarwin;
  });
in
## Splat all phase derivations + gnu-hello outputs into the returned set,
## plus the few attrs that aren't part of phaseDefs/gnuHello.
phaseDefs // gnuHello // {
  "darwin-signed-build-tools" = signedBuildTools;
  inherit
    hex0
    m2libc-darwin
    mesNyacc
    stage0-posix
    supportedSystems
    raw-syscall-hello
    raw-syscall-hello-unsigned
    tinycc-m2-negative-probe
    tinyccBootstrappableSrc
    tinyccMesSrc
    tests
    ;
}
