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
    phase1-hex1                  = callPhase ./stage0-posix/hex1.nix;
    phase2-hex2                  = callPhase ./stage0-posix/hex2.nix;
    phase2-catm                  = callPhase ./stage0-posix/catm.nix;
    phase3-m0                    = callPhase ./stage0-posix/m0.nix;
    phase4-cc-arch               = callPhase ./stage0-posix/cc-arch.nix;
    phase5-m2                    = callPhase ./stage0-posix/m2-planet.nix;
    phase6-blood-macho-0         = callPhase ./stage0-posix/blood-elf-macho.nix;
    phase7-m1-0                  = callPhase ./stage0-posix/M1-0.nix;
    phase8-hex2-1                = callPhase ./stage0-posix/hex2-1.nix;
    phase9-m1                    = callPhase ./stage0-posix/M1.nix;
    phase10-hex2                 = callPhase ./stage0-posix/hex2-linker.nix;
    phase11-kaem                 = callPhase ./stage0-posix/kaem.nix;

    ## mescc-tools — Darwin Mach-O helpers (M0/M1 + macho patcher)
    phase11b-m1-to-hex2          = callPhase ./mescc-tools/m1-to-hex2.nix;
    phase11c-hex2-data-relocs    = callPhase ./mescc-tools/hex2-data-relocs.nix;
    phase11d-cc-arch-helper      = callPhase ./mescc-tools/cc-arch-helper.nix;
    phase11e-macho-patcher-early = callPhase ./mescc-tools/macho-patcher-early.nix;
    phase26b-elf64-to-m1         = callPhase ./mescc-tools/elf64-to-m1.nix;
    phase26g-macho-patcher       = callPhase ./mescc-tools/macho-patcher.nix;

    ## mes — M2-Planet wrapper + mes-m2 build (phases 12-16)
    phase12-m2-planet            = callPhase ./mes/m2-planet.nix;
    phase13-mes-source           = callPhase ./mes/source.nix;
    phase14-mes-m2-probe         = callPhase ./mes/m2-compile.nix;
    phase15-mes-macho-link-probe = callPhase ./mes/m2-link.nix;
    phase16-mes-m2               = callPhase ./mes/m2.nix;

    ## mescc-libc — Mescc libc layers (phases 17-22)
    phase17-mescc-macho-probe       = callPhase ./mescc-libc/mescc-macho.nix;
    phase18-mescc-libc-mini-probe   = callPhase ./mescc-libc/libc-mini.nix;
    phase19-tinycc-mescc-m1-probe   = callPhase ./mescc-libc/tinycc-mescc-m1.nix;
    phase20-mescc-libmescc-probe    = callPhase ./mescc-libc/libmescc.nix;
    phase21-mescc-libc-probe        = callPhase ./mescc-libc/libc.nix;
    phase22-mescc-libc-tcc-probe    = callPhase ./mescc-libc/libc-tcc.nix;

    ## tinycc — Mescc-built TCC through full self-hosting (phases 23-38)
    phase23-tinycc-mescc-link-probe     = callPhase ./tinycc/mescc-link.nix;
    phase24-tinycc-compile-probe        = callPhase ./tinycc/compile.nix;
    phase25-tinycc-self-object-probe    = callPhase ./tinycc/self-object.nix;
    phase27-tinycc-elf-to-macho-probe   = callPhase ./tinycc/elf-to-macho.nix;
    phase28-tinycc-self-m1-probe        = callPhase ./tinycc/self-m1.nix;
    phase29-tinycc-sysv-libc-probe      = callPhase ./tinycc/sysv-libc.nix;
    phase30-tinycc-self-link-candidate  = callPhase ./tinycc/self-link.nix;
    phase31-tinycc-self-compile-probe   = callPhase ./tinycc/self-compile.nix;
    phase32-tinycc-boot1-object-probe   = callPhase ./tinycc/boot1-object.nix;
    phase33-tinycc-boot1-link-candidate = callPhase ./tinycc/boot1-link.nix;
    phase34-tinycc-darwin-cc            = callPhase ./tinycc/darwin-cc.nix;
    phase35-tinycc-boot2-object-probe   = callPhase ./tinycc/boot2-object.nix;
    phase36-tinycc-boot2-link-candidate = callPhase ./tinycc/boot2-link.nix;
    phase37-tinycc-boot3-object-probe   = callPhase ./tinycc/boot3-object.nix;
    phase38-tinycc-boot3-link-candidate = callPhase ./tinycc/boot3-link.nix;
    tinyccSelfObjectProbe               = callPhase ./tinycc/self-object-helper.nix;
    tinyccSelfLinkCandidate             = callPhase ./tinycc/self-link-candidate.nix;

    ## gnumake / gnupatch / coreutils (phases 39-41)
    phase39-gnumake   = callPhase ./gnumake;
    phase40-gnupatch  = callPhase ./gnupatch;
    phase41-coreutils = callPhase ./coreutils;

    ## bootstrap-deps — GMP/MPFR/MPC/ISL built by phase34-tcc (phases 26c-26f)
    phase26c-bootstrap-gmp  = callPhase ./bootstrap-deps/gmp.nix;
    phase26d-bootstrap-mpfr = callPhase ./bootstrap-deps/mpfr.nix;
    phase26e-bootstrap-mpc  = callPhase ./bootstrap-deps/mpc.nix;
    phase26f-bootstrap-isl  = callPhase ./bootstrap-deps/isl.nix;

    ## gcc-4.6 — TCC builds GCC 4.6 (phases 26, 35-37, 44)
    phase26-gcc46-source        = callPhase ./gcc-4.6/source.nix;
    gcc46DarwinBootstrapSrc     = callPhase ./gcc-4.6/darwin-bootstrap-src.nix;
    phase35-gcc46-all-gcc       = callPhase ./gcc-4.6/all-gcc.nix;
    phase36-gcc46-libgcc        = callPhase ./gcc-4.6/libgcc.nix;
    phase37-gcc46-bootstrap     = callPhase ./gcc-4.6/bootstrap.nix;
    phase44-gcc46-cxx-bootstrap = callPhase ./gcc-4.6/cxx.nix;

    ## gcc-10 — GCC 4.6 builds GCC 10 (phases 42, 45)
    phase42-gcc10-source    = callPhase ./gcc-10/source.nix;
    phase45-gcc10-bootstrap = callPhase ./gcc-10;

    ## gcc-latest — GCC 10 builds GCC 16 + strict re-bootstrap (phases 43, 46, 47)
    phase43-gcc-latest-source           = callPhase ./gcc-latest/source.nix;
    phase46-gcc-latest-bootstrap        = callPhase ./gcc-latest;
    phase47-gcc-latest-strict-bootstrap = callPhase ./gcc-latest/strict.nix;
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
