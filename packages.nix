{
  apple-sdk,
  darwin,
  cctools,
  fetchurl,
  gcc_latest,
  gnumake,
  lib,
  minimal-bootstrap-sources,
  perl,
  stdenv,
  runCommand,
}:

let
  root = ./.;
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

  hex0 = import ./stage0-posix/hex0.nix { inherit hostPlatform lib root stdenv supportedSystems tests; };

  m2libc-darwin = runCommand "darwin-minimal-bootstrap-m2libc" { } ''
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
    inherit (utils) mkDarwin;
    inherit apple-sdk darwin cctools fetchurl gnumake lib minimal-bootstrap-sources perl;
    inherit stdenv runCommand hostPlatform supportedSystems arch source;
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
  ## Variable names retain the legacy `phaseN-` prefix during the rec
  ## bind so existing cross-references inside the package files keep
  ## resolving.  External consumers (flake outputs) get semantic aliases
  ## further down via `inherit (phaseDefs) ...`.
  ## Each phase is `import <path> (phaseContext // phaseDefs)`.
  callPhase = path: import path (phaseContext // phaseDefs);

  phaseDefs = {
    ## stage0-posix — hex0 through kaem (phases 1-11)
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

    ## mescc-tools — Darwin Mach-O helpers (M0/M1 + macho patcher)
    m1-to-hex2          = callPhase ./mescc-tools/m1-to-hex2.nix;
    hex2-data-relocs    = callPhase ./mescc-tools/hex2-data-relocs.nix;
    cc-arch-helper      = callPhase ./mescc-tools/cc-arch-helper.nix;
    macho-patcher-early = callPhase ./mescc-tools/macho-patcher-early.nix;
    elf64-to-m1         = callPhase ./mescc-tools/elf64-to-m1.nix;
    macho-patcher       = callPhase ./mescc-tools/macho-patcher.nix;
    m1-split            = callPhase ./mescc-tools/m1-split.nix;
    synth-inject        = callPhase ./mescc-tools/synth-inject.nix;

    ## mes — M2-Planet wrapper + mes-m2 build (phases 12-16)
    m2-planet            = callPhase ./mes/m2-planet.nix;
    mes-source           = callPhase ./mes/source.nix;
    mes-m2-probe         = callPhase ./mes/m2-compile.nix;
    mes-macho-link-probe = callPhase ./mes/m2-link.nix;
    mes-m2               = callPhase ./mes/m2.nix;

    ## mescc-libc — Mescc libc layers (phases 17-22)
    mescc-macho-probe       = callPhase ./mescc-libc/mescc-macho.nix;
    mescc-libc-mini-probe   = callPhase ./mescc-libc/libc-mini.nix;
    tinycc-mescc-m1-probe   = callPhase ./mescc-libc/tinycc-mescc-m1.nix;
    mescc-libmescc-probe    = callPhase ./mescc-libc/libmescc.nix;
    mescc-libc-probe        = callPhase ./mescc-libc/libc.nix;
    mescc-libc-tcc-probe    = callPhase ./mescc-libc/libc-tcc.nix;

    ## tinycc — Mescc-built TCC through full self-hosting (phases 23-38)
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

    ## gnumake / gnupatch / coreutils (phases 39-41)
    bootstrap-gnumake   = callPhase ./gnumake;
    gnupatch  = callPhase ./gnupatch;
    coreutils-boot = callPhase ./coreutils;

    ## bootstrap-deps — GMP/MPFR/MPC/ISL built by phase34-tcc (phases 26c-26f)
    bootstrap-gmp  = callPhase ./bootstrap-deps/gmp.nix;
    bootstrap-mpfr = callPhase ./bootstrap-deps/mpfr.nix;
    bootstrap-mpc  = callPhase ./bootstrap-deps/mpc.nix;
    bootstrap-isl  = callPhase ./bootstrap-deps/isl.nix;

    ## gcc-4.6 — TCC builds GCC 4.6 (phases 26, 35-37, 44)
    gcc46-source        = callPhase ./gcc-4.6/source.nix;
    gcc46DarwinBootstrapSrc     = callPhase ./gcc-4.6/darwin-bootstrap-src.nix;
    gcc46-all-gcc       = callPhase ./gcc-4.6/all-gcc.nix;
    gcc46-libgcc        = callPhase ./gcc-4.6/libgcc.nix;
    gcc46     = callPhase ./gcc-4.6/bootstrap.nix;
    gcc46-cxx = callPhase ./gcc-4.6/cxx.nix;

    ## gcc-10 — GCC 4.6 builds GCC 10 (phases 42, 45)
    gcc10-source    = callPhase ./gcc-10/source.nix;
    gcc10 = callPhase ./gcc-10;

    ## gcc-latest — GCC 10 builds GCC 16 + strict re-bootstrap (phases 43, 46, 47)
    gcc-latest-source           = callPhase ./gcc-latest/source.nix;
    gcc-latest        = callPhase ./gcc-latest;
    gcc-latest-strict = callPhase ./gcc-latest/strict.nix;

    ## cctools ar/ranlib chain-built from source via gcc-15 (downstream of gcc-15)
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
      darwin
      hex0
      raw-syscall-hello
      raw-syscall-hello-unsigned
      gnu-hello-hash-comparison
      ;
  });
in
## Splat all phase derivations + gnu-hello outputs into the returned set,
## plus the few attrs that aren't part of phaseDefs/gnuHello.
phaseDefs // gnuHello // {
  inherit
    hex0
    m2libc-darwin
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
