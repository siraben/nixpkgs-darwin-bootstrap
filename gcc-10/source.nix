{
  gcc10GmpTarball,
  gcc10GmpVersion,
  gcc10Tarball,
  gcc10Version,
  gccModernIslTarball,
  gccModernIslVersion,
  gccModernMpcTarball,
  gccModernMpcVersion,
  gccModernMpfrTarball,
  gccModernMpfrVersion,
  runCommand,
  ...
}:
    runCommand "phase42-gcc-${gcc10Version}-source" { } ''
      mkdir -p work $out
      cd work

      tar -xf ${gcc10Tarball}
      tar -xf ${gcc10GmpTarball}
      tar -xf ${gccModernMpfrTarball}
      tar -xf ${gccModernMpcTarball}
      tar -xf ${gccModernIslTarball}

      mv gcc-${gcc10Version}/* $out/
      cp -R gmp-${gcc10GmpVersion} $out/gmp
      cp -R mpfr-${gccModernMpfrVersion} $out/mpfr
      cp -R mpc-${gccModernMpcVersion} $out/mpc
      cp -R isl-${gccModernIslVersion} $out/isl

      test -x $out/configure
      test -f $out/gcc/gcc.c
      test -f $out/gmp/configure
      test -f $out/mpfr/configure
      test -f $out/mpc/configure
      test -f $out/isl/configure
    ''
