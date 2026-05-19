args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase35-gcc-${gcc46Version}-all-gcc-amd64" { } ''
        mkdir -p src build $out/bin $out/share/darwin-bootstrap
        cp -R ${gcc46DarwinBootstrapSrc}/. src/
        chmod -R u+w src
        sed -i \
          's|^NATIVE_SYSTEM_HEADER_DIR = /usr/include|NATIVE_SYSTEM_HEADER_DIR = ${phase34-tinycc-darwin-cc}/include/tcc-darwin-bootstrap|' \
          src/gcc/Makefile.in
        ${python3}/bin/python3 ${root + "/scripts/gcc46/phase35-prepare-source.py"}

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
        cat > gcc/config.cache <<'CACHE'
        ac_cv_func_getrlimit=''${ac_cv_func_getrlimit=no}
        ac_cv_func_setrlimit=''${ac_cv_func_setrlimit=no}
        ac_cv_func_getrusage=''${ac_cv_func_getrusage=no}
        ac_cv_func_times=''${ac_cv_func_times=no}
        ac_cv_func_clock=''${ac_cv_func_clock=no}
        ac_cv_func_kill=''${ac_cv_func_kill=no}
        ac_cv_func_gettimeofday=''${ac_cv_func_gettimeofday=no}
        ac_cv_func_fork=''${ac_cv_func_fork=no}
        ac_cv_func_fork_works=''${ac_cv_func_fork_works=no}
        ac_cv_func_vfork=''${ac_cv_func_vfork=no}
        ac_cv_func_vfork_works=''${ac_cv_func_vfork_works=no}
        ac_cv_func_mmap=''${ac_cv_func_mmap=no}
        ac_cv_func_mbstowcs=''${ac_cv_func_mbstowcs=no}
        ac_cv_func_wcswidth=''${ac_cv_func_wcswidth=no}
        ac_cv_func_getchar_unlocked=''${ac_cv_func_getchar_unlocked=no}
        ac_cv_func_getc_unlocked=''${ac_cv_func_getc_unlocked=no}
        ac_cv_func_putchar_unlocked=''${ac_cv_func_putchar_unlocked=no}
        ac_cv_func_putc_unlocked=''${ac_cv_func_putc_unlocked=no}
        ac_cv_func_clearerr_unlocked=''${ac_cv_func_clearerr_unlocked=no}
        ac_cv_func_feof_unlocked=''${ac_cv_func_feof_unlocked=no}
        ac_cv_func_ferror_unlocked=''${ac_cv_func_ferror_unlocked=no}
        ac_cv_func_fflush_unlocked=''${ac_cv_func_fflush_unlocked=no}
        ac_cv_func_fgetc_unlocked=''${ac_cv_func_fgetc_unlocked=no}
        ac_cv_func_fgets_unlocked=''${ac_cv_func_fgets_unlocked=no}
        ac_cv_func_fileno_unlocked=''${ac_cv_func_fileno_unlocked=no}
        ac_cv_func_fprintf_unlocked=''${ac_cv_func_fprintf_unlocked=no}
        ac_cv_func_fputc_unlocked=''${ac_cv_func_fputc_unlocked=no}
        ac_cv_func_fputs_unlocked=''${ac_cv_func_fputs_unlocked=no}
        ac_cv_func_fread_unlocked=''${ac_cv_func_fread_unlocked=no}
        ac_cv_func_fwrite_unlocked=''${ac_cv_func_fwrite_unlocked=no}
        ac_cv_have_decl_getrlimit=''${ac_cv_have_decl_getrlimit=no}
        ac_cv_have_decl_setrlimit=''${ac_cv_have_decl_setrlimit=no}
        ac_cv_have_decl_getrusage=''${ac_cv_have_decl_getrusage=no}
        ac_cv_have_decl_times=''${ac_cv_have_decl_times=no}
        ac_cv_have_decl_clock=''${ac_cv_have_decl_clock=no}
        ac_cv_have_decl_gettimeofday=''${ac_cv_have_decl_gettimeofday=no}
        ac_cv_have_decl_clearerr_unlocked=''${ac_cv_have_decl_clearerr_unlocked=no}
        ac_cv_have_decl_feof_unlocked=''${ac_cv_have_decl_feof_unlocked=no}
        ac_cv_have_decl_ferror_unlocked=''${ac_cv_have_decl_ferror_unlocked=no}
        ac_cv_have_decl_fflush_unlocked=''${ac_cv_have_decl_fflush_unlocked=no}
        ac_cv_have_decl_fgetc_unlocked=''${ac_cv_have_decl_fgetc_unlocked=no}
        ac_cv_have_decl_fgets_unlocked=''${ac_cv_have_decl_fgets_unlocked=no}
        ac_cv_have_decl_fileno_unlocked=''${ac_cv_have_decl_fileno_unlocked=no}
        ac_cv_have_decl_fprintf_unlocked=''${ac_cv_have_decl_fprintf_unlocked=no}
        ac_cv_have_decl_fputc_unlocked=''${ac_cv_have_decl_fputc_unlocked=no}
        ac_cv_have_decl_fputs_unlocked=''${ac_cv_have_decl_fputs_unlocked=no}
        ac_cv_have_decl_fread_unlocked=''${ac_cv_have_decl_fread_unlocked=no}
        ac_cv_have_decl_fwrite_unlocked=''${ac_cv_have_decl_fwrite_unlocked=no}
        ac_cv_have_decl_getchar_unlocked=''${ac_cv_have_decl_getchar_unlocked=no}
        ac_cv_have_decl_getc_unlocked=''${ac_cv_have_decl_getc_unlocked=no}
        ac_cv_have_decl_putchar_unlocked=''${ac_cv_have_decl_putchar_unlocked=no}
        ac_cv_have_decl_putc_unlocked=''${ac_cv_have_decl_putc_unlocked=no}
CACHE
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
          cat > "$d/config.cache" <<'CACHE'
        ac_cv_sizeof_int=''${ac_cv_sizeof_int=4}
        ac_cv_sizeof_long=''${ac_cv_sizeof_long=8}
        ac_cv_sizeof_long_long=''${ac_cv_sizeof_long_long=8}
        ac_cv_sizeof_short=''${ac_cv_sizeof_short=2}
        ac_cv_sizeof_void_p=''${ac_cv_sizeof_void_p=8}
        ac_cv_type_intptr_t=''${ac_cv_type_intptr_t=yes}
        ac_cv_type_uintptr_t=''${ac_cv_type_uintptr_t=yes}
        ac_cv_type_intmax_t=''${ac_cv_type_intmax_t=yes}
        ac_cv_type_uintmax_t=''${ac_cv_type_uintmax_t=yes}
        ac_cv_func_getpagesize=''${ac_cv_func_getpagesize=no}
        ac_cv_func_mmap=''${ac_cv_func_mmap=no}
        ac_cv_func_getrlimit=''${ac_cv_func_getrlimit=no}
        ac_cv_func_setrlimit=''${ac_cv_func_setrlimit=no}
CACHE
        done
        for d in mpfr mpc; do
          mkdir -p "$d"
          cat > "$d/config.cache" <<'CACHE'
        ac_cv_lib_gmp___gmpz_init=''${ac_cv_lib_gmp___gmpz_init=yes}
CACHE
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

        cat > xgcc-smoke.c <<'C'
        int main(void) { return 42; }
C
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
    else
      null
