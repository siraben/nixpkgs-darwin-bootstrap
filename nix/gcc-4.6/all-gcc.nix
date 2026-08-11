{
  cctools,
  darwin,
  gcc46DarwinBootstrapSrc,
  gcc46Version,
  gnupatch,
  tinycc-darwin-cc,
  root,
  runCommand,
  ...
}:
      runCommand "gcc-${gcc46Version}-all-gcc" {
        __impureHostDeps = [ "/usr/bin/codesign" ];
      } ''
        set -o pipefail

        DARWIN_SHARED_BUILD_TOOLS="$(dirname "$(command -v bash)")"
        DARWIN_SIGNED_BUILD_TOOLS="$PWD/.darwin-signed-build-tools"
        DARWIN_SIGNED_COPY="$(command -v cp)"
        DARWIN_SIGNED_CHMOD="$(command -v chmod)"
        DARWIN_SIGNED_MKDIR="$(command -v mkdir)"
        DARWIN_SIGNED_PREPARE_PATH_TOOLS=0
        source ${root + "/scripts/darwin/prepare-signed-build-tools.sh"}
        prepare_signed_build_tool cctools-ar ${cctools}/bin/ar
        prepare_signed_build_tool cctools-nm ${cctools}/bin/nm
        # nixpkgs's bin/ranlib is cctools libtool, which selects ranlib mode
        # only when argv[0] has this exact basename.  Make invokes this copy
        # directly, and cctools ar also derives the same sibling path when it
        # refreshes an archive index.
        prepare_signed_build_tool ranlib ${cctools}/bin/ranlib
        prepare_signed_build_tool cctools-strip ${cctools}/bin/strip
        prepare_signed_build_tool cctools-lipo ${cctools}/bin/lipo
        prepare_signed_build_tool cctools-otool ${cctools}/bin/otool
        prepare_signed_build_tool tinycc-sigtool ${darwin.sigtool}/bin/sigtool
        export PATH="$DARWIN_SIGNED_BUILD_TOOLS:$PATH"
        export CONFIG_SHELL="$DARWIN_SHARED_BUILD_TOOLS/bash"
        export SHELL="$DARWIN_SHARED_BUILD_TOOLS/bash"

        # The TinyCC wrapper contains absolute, pinned paths.  Rewrite only
        # those execution paths to the signed copies of the same inputs.
        cp ${darwin.signingUtils} "$DARWIN_SIGNED_BUILD_TOOLS/tinycc-signing-utils"
        cp ${tinycc-darwin-cc}/bin/tcc-darwin-cc "$DARWIN_SIGNED_BUILD_TOOLS/tcc-darwin-cc"
        chmod u+w "$DARWIN_SIGNED_BUILD_TOOLS/tinycc-signing-utils" \
          "$DARWIN_SIGNED_BUILD_TOOLS/tcc-darwin-cc"
        # bootstrapDarwin.signingUtils already points at the shared strict-
        # verified copies of codesign, sigtool, and codesign_allocate.
        substituteInPlace "$DARWIN_SIGNED_BUILD_TOOLS/tcc-darwin-cc" \
          --replace-fail ${cctools}/bin/ar "$DARWIN_SIGNED_BUILD_TOOLS/cctools-ar" \
          --replace-fail ${darwin.signingUtils} "$DARWIN_SIGNED_BUILD_TOOLS/tinycc-signing-utils" \
          --replace-fail ${darwin.sigtool}/bin/sigtool "$DARWIN_SIGNED_BUILD_TOOLS/tinycc-sigtool"

        mkdir -p src build $out/bin $out/share/darwin-bootstrap
        cp -R ${gcc46DarwinBootstrapSrc}/. src/
        chmod -R u+w src
        sed -i \
          's|^NATIVE_SYSTEM_HEADER_DIR = /usr/include|NATIVE_SYSTEM_HEADER_DIR = ${tinycc-darwin-cc}/include/tcc-darwin-bootstrap|' \
          src/gcc/Makefile.in
        GNUPATCH=${gnupatch}/bin/patch \
        PREPARE_SOURCE_PATCH=${root + "/patches/gcc-4.6/prepare-source.patch"} \
          "$DARWIN_SHARED_BUILD_TOOLS/bash" ${root + "/scripts/gcc-4.6/prepare-source.sh"}

        # Invoke the chain TinyCC wrapper through the signed copy of the exact
        # stdenv Bash.  The wrapper and all compiler inputs remain unchanged.
        export CC="$DARWIN_SHARED_BUILD_TOOLS/bash $DARWIN_SIGNED_BUILD_TOOLS/tcc-darwin-cc"
        export CPP="$CC -E"
        export CC_FOR_BUILD="$CC"
        export AR="$DARWIN_SIGNED_BUILD_TOOLS/cctools-ar"
        export NM="$DARWIN_SIGNED_BUILD_TOOLS/cctools-nm"
        export RANLIB="$DARWIN_SIGNED_BUILD_TOOLS/ranlib"
        export STRIP="$DARWIN_SIGNED_BUILD_TOOLS/cctools-strip"
        export LIPO="$DARWIN_SIGNED_BUILD_TOOLS/cctools-lipo"
        export OTOOL="$DARWIN_SIGNED_BUILD_TOOLS/cctools-otool"
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
          --with-native-system-header-dir=${tinycc-darwin-cc}/include/tcc-darwin-bootstrap \
          --with-build-sysroot=${tinycc-darwin-cc}/include/tcc-darwin-bootstrap \
          --disable-bootstrap \
          --disable-shared \
          --disable-multilib \
          --disable-nls \
          --enable-languages=c \
          MAKEINFO=true \
          2>&1 | tee $out/share/darwin-bootstrap/configure.log

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
          NATIVE_SYSTEM_HEADER_DIR=${tinycc-darwin-cc}/include/tcc-darwin-bootstrap \
          CPP="$CPP" \
          AR="$AR" \
          NM="$NM" \
          RANLIB="$RANLIB" \
          STRIP="$STRIP" \
          LIPO="$LIPO" \
          OTOOL="$OTOOL" \
          2>&1 | tee $out/share/darwin-bootstrap/make-all-gcc.log

        test -x gcc/xgcc
        test -x gcc/cc1
        ./gcc/xgcc -B"$PWD/gcc/" --version > $out/share/darwin-bootstrap/xgcc-version.stdout

        cp ${root + "/gcc-4.6/fixtures/all-gcc-xgcc-smoke.c"} xgcc-smoke.c
        rm -f gccdump.s
        # This fixture intentionally has no includes.  Do not probe Darwin's
        # host-default /usr/local/include and /Library/Frameworks paths: they
        # are outside the bootstrap sysroot and absent from the Nix sandbox.
        # -nostdinc still runs the newly built driver and cc1, while making the
        # test's header-search boundary explicit.
        ./gcc/xgcc -B"$PWD/gcc/" -nostdinc -S xgcc-smoke.c -o xgcc-smoke.s \
          2>&1 | tee $out/share/darwin-bootstrap/xgcc-smoke.log
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
