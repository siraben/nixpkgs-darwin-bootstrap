{
  gcc46GmpTarball,
  gcc46MpcTarball,
  gcc46MpfrTarball,
  gcc46Tarball,
  gcc46Version,
  runCommand,
  ...
}:
    runCommand "phase26-gcc-${gcc46Version}-source" { } ''
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
    ''
