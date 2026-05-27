{
  cctools,
  gcc46DarwinBootstrapSrc,
  gcc46Version,
  perl,
  phase34-tinycc-darwin-cc,
  root,
  runCommand,
  ...
}:
      runCommand "phase35-gcc-${gcc46Version}-all-gcc" {
        nativeBuildInputs = [ perl ];
      } ''
        mkdir -p src build $out/bin $out/share/darwin-bootstrap
        cp -R ${gcc46DarwinBootstrapSrc}/. src/
        chmod -R u+w src
        sed -i \
          's|^NATIVE_SYSTEM_HEADER_DIR = /usr/include|NATIVE_SYSTEM_HEADER_DIR = ${phase34-tinycc-darwin-cc}/include/tcc-darwin-bootstrap|' \
          src/gcc/Makefile.in
        bash ${root + "/scripts/gcc46/phase35-prepare-source.sh"}

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
        export MACOSX_DEPLOYMENT_TARGET=10.6
        export TCC_DARWIN_CACHE_DIR="$PWD/.tcc-darwin-cache"
        mkdir -p "$TCC_DARWIN_CACHE_DIR"
        export ac_cv_have_decl_getrlimit=no
        export ac_cv_have_decl_setrlimit=no
        export ac_cv_func_getrlimit=no
        export ac_cv_func_setrlimit=no

        cd build
        mkdir -p gcc
        install -m644 ${root + "/gcc-4.6/fixtures/all-gcc-gcc-config.cache"} gcc/config.cache
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
          install -m644 ${root + "/gcc-4.6/fixtures/all-gcc-libiberty-config.cache"} "$d/config.cache"
        done
        for d in mpfr mpc; do
          mkdir -p "$d"
          install -m644 ${root + "/gcc-4.6/fixtures/all-gcc-mpfr-config.cache"} "$d/config.cache"
        done
        ../src/configure \
          --prefix=$out \
          --build=x86_64-apple-darwin \
          --host=x86_64-apple-darwin \
          --target=x86_64-apple-darwin \
          --with-native-system-header-dir=${phase34-tinycc-darwin-cc}/include/tcc-darwin-bootstrap \
          --with-build-sysroot=${phase34-tinycc-darwin-cc}/include/tcc-darwin-bootstrap \
          --disable-bootstrap \
          --disable-shared \
          --disable-multilib \
          --disable-nls \
          --enable-languages=c \
          MAKEINFO=true \
          > $out/share/darwin-bootstrap/configure.stdout \
          2> $out/share/darwin-bootstrap/configure.stderr

        {
          echo '#include "bconfig.h"'
          cat ../src/gcc/gengtype-lex.c
        } > gcc/gengtype-lex.c
        touch gcc/gengtype-lex.c

        buildCores="''${NIX_BUILD_CORES:-1}"
        if test "$buildCores" = 0; then
          buildCores="$(sysctl -n hw.ncpu 2>/dev/null || echo 1)"
        fi

        make all-gcc -j"$buildCores" \
          MAKEINFO=true \
          NATIVE_SYSTEM_HEADER_DIR=${phase34-tinycc-darwin-cc}/include/tcc-darwin-bootstrap \
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
        test -x gcc/cc1
        ./gcc/xgcc -B"$PWD/gcc/" --version > $out/share/darwin-bootstrap/xgcc-version.stdout

        cp ${root + "/gcc-4.6/fixtures/all-gcc-xgcc-smoke.c"} xgcc-smoke.c
        rm -f gccdump.s
        ./gcc/xgcc -B"$PWD/gcc/" -S xgcc-smoke.c -o xgcc-smoke.s \
          > $out/share/darwin-bootstrap/xgcc-smoke.stdout \
          2> $out/share/darwin-bootstrap/xgcc-smoke.stderr
        if test ! -s xgcc-smoke.s && test -s gccdump.s; then
          mv gccdump.s xgcc-smoke.s
        fi
        test -s xgcc-smoke.s
        cp gcc/xgcc $out/bin/xgcc

        cd ..
        mkdir -p $out/share/darwin-bootstrap/work
        cp -R src $out/share/darwin-bootstrap/work/src
        cp -R build $out/share/darwin-bootstrap/work/build
      ''
