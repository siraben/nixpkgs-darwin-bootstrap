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

  hex0 = import ./stage0-posix/hex0.nix { inherit lib stdenv supportedSystems tests; };

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
    root = ./.;
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
  ## // phaseDefs` as their args and use `args: with args; ...` style so
  ## each .nix file can reference siblings by name.  Mirrors nixpkgs's
  ## pkgs/os-specific/linux/minimal-bootstrap/default.nix layout.
  ##
  ## Variable names retain the legacy `phaseN-` prefix during the rec
  ## bind so existing cross-references inside the package files keep
  ## resolving.  External consumers (flake outputs) get semantic aliases
  ## further down via `inherit (phaseDefs) ...`.
  phaseDefs = rec {
    ## stage0-posix — hex0 through kaem (phases 1-11)
    phase1-hex1                  = import ./stage0-posix/hex1.nix              (phaseContext // phaseDefs);
    phase2-hex2                  = import ./stage0-posix/hex2.nix              (phaseContext // phaseDefs);
    phase2-catm                  = import ./stage0-posix/catm.nix              (phaseContext // phaseDefs);
    phase3-m0                    = import ./stage0-posix/m0.nix                (phaseContext // phaseDefs);
    phase4-cc-arch               = import ./stage0-posix/cc-arch.nix           (phaseContext // phaseDefs);
    phase5-m2                    = import ./stage0-posix/m2-planet.nix         (phaseContext // phaseDefs);
    phase6-blood-macho-0         = import ./stage0-posix/blood-elf-macho.nix   (phaseContext // phaseDefs);
    phase7-m1-0                  = import ./stage0-posix/M1-0.nix              (phaseContext // phaseDefs);
    phase8-hex2-1                = import ./stage0-posix/hex2-1.nix            (phaseContext // phaseDefs);
    phase9-m1                    = import ./stage0-posix/M1.nix                (phaseContext // phaseDefs);
    phase10-hex2                 = import ./stage0-posix/hex2-linker.nix       (phaseContext // phaseDefs);
    phase11-kaem                 = import ./stage0-posix/kaem.nix              (phaseContext // phaseDefs);

    ## mescc-tools — Darwin Mach-O helpers (M0/M1 + macho patcher)
    phase11b-m1-to-hex2          = import ./mescc-tools/m1-to-hex2.nix         (phaseContext // phaseDefs);
    phase11c-hex2-data-relocs    = import ./mescc-tools/hex2-data-relocs.nix   (phaseContext // phaseDefs);
    phase11d-cc-arch-helper      = import ./mescc-tools/cc-arch-helper.nix     (phaseContext // phaseDefs);
    phase11e-macho-patcher-early = import ./mescc-tools/macho-patcher-early.nix (phaseContext // phaseDefs);
    phase26b-elf64-to-m1         = import ./mescc-tools/elf64-to-m1.nix        (phaseContext // phaseDefs);
    phase26g-macho-patcher       = import ./mescc-tools/macho-patcher.nix      (phaseContext // phaseDefs);

    ## mes — M2-Planet wrapper + mes-m2 build (phases 12-16)
    phase12-m2-planet            = import ./mes/m2-planet.nix                  (phaseContext // phaseDefs);
    phase13-mes-source           = import ./mes/source.nix                     (phaseContext // phaseDefs);
    phase14-mes-m2-probe         = import ./mes/m2-compile.nix                 (phaseContext // phaseDefs);
    phase15-mes-macho-link-probe = import ./mes/m2-link.nix                    (phaseContext // phaseDefs);
    phase16-mes-m2               = import ./mes/m2.nix                         (phaseContext // phaseDefs);

    ## mescc-libc — Mescc libc layers (phases 17-22)
    phase17-mescc-macho-probe       = import ./mescc-libc/mescc-macho.nix      (phaseContext // phaseDefs);
    phase18-mescc-libc-mini-probe   = import ./mescc-libc/libc-mini.nix        (phaseContext // phaseDefs);
    phase19-tinycc-mescc-m1-probe   = import ./mescc-libc/tinycc-mescc-m1.nix  (phaseContext // phaseDefs);
    phase20-mescc-libmescc-probe    = import ./mescc-libc/libmescc.nix         (phaseContext // phaseDefs);
    phase21-mescc-libc-probe        = import ./mescc-libc/libc.nix             (phaseContext // phaseDefs);
    phase22-mescc-libc-tcc-probe    = import ./mescc-libc/libc-tcc.nix         (phaseContext // phaseDefs);

    ## tinycc — Mescc-built TCC through full self-hosting (phases 23-38)
    phase23-tinycc-mescc-link-probe     = import ./tinycc/mescc-link.nix       (phaseContext // phaseDefs);
    phase24-tinycc-compile-probe        = import ./tinycc/compile.nix          (phaseContext // phaseDefs);
    phase25-tinycc-self-object-probe    = import ./tinycc/self-object.nix      (phaseContext // phaseDefs);
    phase27-tinycc-elf-to-macho-probe   = import ./tinycc/elf-to-macho.nix     (phaseContext // phaseDefs);
    phase28-tinycc-self-m1-probe        = import ./tinycc/self-m1.nix          (phaseContext // phaseDefs);
    phase29-tinycc-sysv-libc-probe      = import ./tinycc/sysv-libc.nix        (phaseContext // phaseDefs);
    phase30-tinycc-self-link-candidate  = import ./tinycc/self-link.nix        (phaseContext // phaseDefs);
    phase31-tinycc-self-compile-probe   = import ./tinycc/self-compile.nix     (phaseContext // phaseDefs);
    phase32-tinycc-boot1-object-probe   = import ./tinycc/boot1-object.nix     (phaseContext // phaseDefs);
    phase33-tinycc-boot1-link-candidate = import ./tinycc/boot1-link.nix       (phaseContext // phaseDefs);
    phase34-tinycc-darwin-cc            = import ./tinycc/darwin-cc.nix        (phaseContext // phaseDefs);
    phase35-tinycc-boot2-object-probe   = import ./tinycc/boot2-object.nix     (phaseContext // phaseDefs);
    phase36-tinycc-boot2-link-candidate = import ./tinycc/boot2-link.nix       (phaseContext // phaseDefs);
    phase37-tinycc-boot3-object-probe   = import ./tinycc/boot3-object.nix     (phaseContext // phaseDefs);
    phase38-tinycc-boot3-link-candidate = import ./tinycc/boot3-link.nix       (phaseContext // phaseDefs);
    tinyccSelfObjectProbe               = import ./tinycc/self-object-helper.nix (phaseContext // phaseDefs);
    tinyccSelfLinkCandidate             = import ./tinycc/self-link-candidate.nix (phaseContext // phaseDefs);

    ## gnumake / gnupatch / coreutils (phases 39-41)
    phase39-gnumake   = import ./gnumake   (phaseContext // phaseDefs);
    phase40-gnupatch  = import ./gnupatch  (phaseContext // phaseDefs);
    phase41-coreutils = import ./coreutils (phaseContext // phaseDefs);

    ## bootstrap-deps — GMP/MPFR/MPC/ISL built by phase34-tcc (phases 26c-26f)
    phase26c-bootstrap-gmp  = import ./bootstrap-deps/gmp.nix  (phaseContext // phaseDefs);
    phase26d-bootstrap-mpfr = import ./bootstrap-deps/mpfr.nix (phaseContext // phaseDefs);
    phase26e-bootstrap-mpc  = import ./bootstrap-deps/mpc.nix  (phaseContext // phaseDefs);
    phase26f-bootstrap-isl  = import ./bootstrap-deps/isl.nix  (phaseContext // phaseDefs);

    ## gcc-4.6 — TCC builds GCC 4.6 (phases 26, 35-37, 44)
    phase26-gcc46-source        = import ./gcc-4.6/source.nix              (phaseContext // phaseDefs);
    gcc46DarwinBootstrapSrc     = import ./gcc-4.6/darwin-bootstrap-src.nix (phaseContext // phaseDefs);
    phase35-gcc46-all-gcc       = import ./gcc-4.6/all-gcc.nix             (phaseContext // phaseDefs);
    phase36-gcc46-libgcc        = import ./gcc-4.6/libgcc.nix              (phaseContext // phaseDefs);
    phase37-gcc46-bootstrap     = import ./gcc-4.6/bootstrap.nix           (phaseContext // phaseDefs);
    phase44-gcc46-cxx-bootstrap = import ./gcc-4.6/cxx.nix                 (phaseContext // phaseDefs);

    ## gcc-10 — GCC 4.6 builds GCC 10 (phases 42, 45)
    phase42-gcc10-source    = import ./gcc-10/source.nix (phaseContext // phaseDefs);
    phase45-gcc10-bootstrap = import ./gcc-10            (phaseContext // phaseDefs);

    ## gcc-latest — GCC 10 builds GCC 16 + strict re-bootstrap (phases 43, 46, 47)
    phase43-gcc-latest-source           = import ./gcc-latest/source.nix (phaseContext // phaseDefs);
    phase46-gcc-latest-bootstrap        = import ./gcc-latest           (phaseContext // phaseDefs);
    phase47-gcc-latest-strict-bootstrap = import ./gcc-latest/strict.nix (phaseContext // phaseDefs);
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
