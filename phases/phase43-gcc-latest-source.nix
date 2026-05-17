args:
with args;
    runCommand "darwin-minimal-bootstrap-phase43-gcc-${gccLatestVersion}-source" { } ''
      mkdir -p work $out
      cd work

      tar -xf ${gccLatestTarball}
      tar -xf ${gccLatestGmpTarball}
      tar -xf ${gccModernMpfrTarball}
      tar -xf ${gccModernMpcTarball}
      tar -xf ${gccModernIslTarball}

      mv gcc-${gccLatestVersion}/* $out/
      cp -R gmp-${gccLatestGmpVersion} $out/gmp
      cp -R mpfr-${gccModernMpfrVersion} $out/mpfr
      cp -R mpc-${gccModernMpcVersion} $out/mpc
      cp -R isl-${gccModernIslVersion} $out/isl

      test -x $out/configure
      test -f $out/gcc/gcc.cc
      test -f $out/gmp/configure
      test -f $out/mpfr/configure
      test -f $out/mpc/configure
      test -f $out/isl/configure
    ''
