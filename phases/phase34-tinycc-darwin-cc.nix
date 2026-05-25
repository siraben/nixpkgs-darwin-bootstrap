args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase34-tinycc-darwin-cc-amd64" { } ''
        mkdir -p $out/bin $out/include/tcc-darwin-bootstrap/sys $out/share/darwin-bootstrap

        cp -R ${root + "/bootstrap/headers/tcc-darwin-bootstrap"}/. \
          $out/include/tcc-darwin-bootstrap/

        ${phase30-tinycc-self-link-candidate}/bin/tcc-self-candidate -c \
          ${root + "/bootstrap/tinycc-sysv-libc.c"} \
          -o tinycc-sysv-libc.o \
          > tinycc-sysv-libc.stdout \
          2> tinycc-sysv-libc.stderr
        ${phase26b-elf64-to-m1}/bin/elf64-to-m1 --prefix tinycc_sysv_libc_ \
          tinycc-sysv-libc.o \
          tinycc-sysv-libc.M1

        cp ${root + "/scripts/tinycc/crt1-tcc-sysv.M1"} crt1-tcc-sysv.M1

        ## Generate MACHO-amd64-largedata.hex2 by substituting 7 segment
        ## fields in MACHO-amd64-lowdata.hex2 (__TEXT vmsize, __TEXT
        ## filesize, __TEXT section size, __DATA vmaddr, __DATA fileoff,
        ## __LINKEDIT vmaddr+vmsize, __LINKEDIT fileoff).  Bakes in the
        ## constants that tools/patch-macho-large-segments.py used to write
        ## post-hex2; downstream tcc-darwin-cc.sh now skips that python call.
        awk '
        NR==10 { print "00 00 60 00 00 00 00 00 00 00 10 01 00 00 00 00"; next }
        NR==11 { print "00 00 00 00 00 00 00 00 00 00 10 01 00 00 00 00"; next }
        NR==15 { print "00 04 60 00 00 00 00 00 00 fc 0f 01 00 00 00 00"; next }
        NR==19 { print "00 00 00 00 00 00 00 00 00 00 70 01 00 00 00 00"; next }
        NR==20 { print "00 00 00 02 00 00 00 00 00 00 10 01 00 00 00 00"; next }
        NR==24 { print "00 00 70 03 00 00 00 00 00 10 00 00 00 00 00 00"; next }
        NR==25 { print "00 00 10 03 00 00 00 00 00 00 00 00 00 00 00 00"; next }
        { print }
        ' ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          > $out/share/darwin-bootstrap/MACHO-amd64-largedata.hex2

        cp crt1-tcc-sysv.M1 tinycc-sysv-libc.M1 $out/share/darwin-bootstrap/

        cp ${root + "/scripts/tinycc/tcc-darwin-cc.sh"} $out/bin/tcc-darwin-cc
        chmod u+w $out/bin/tcc-darwin-cc

        substituteInPlace $out/bin/tcc-darwin-cc \
          --replace-fail @SHELL@ ${stdenv.shell} \
          --replace-fail @TCC@ ${phase38-tinycc-boot3-link-candidate}/bin/tcc-boot3-candidate \
          --replace-fail @AR@ ${cctools}/bin/ar \
          --replace-fail @INCLUDE@ $out/include/tcc-darwin-bootstrap \
          --replace-fail @PYTHON@ ${python3}/bin/python3 \
          --replace-fail @ELF_TO_M1@ ${root + "/tools/elf64-to-m1.py"} \
          --replace-fail @M1_TO_HEX2@ ${root + "/tools/m1-to-hex2.py"} \
          --replace-fail @HEX2@ ${phase10-hex2}/bin/hex2 \
          --replace-fail @MACHO@ $out/share/darwin-bootstrap/MACHO-amd64-largedata.hex2 \
          --replace-fail @CRT1@ $out/share/darwin-bootstrap/crt1-tcc-sysv.M1 \
          --replace-fail @SYSCALLS@ ${root + "/bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1"} \
          --replace-fail @LIBC_M1@ $out/share/darwin-bootstrap/tinycc-sysv-libc.M1 \
          --replace-fail @SIGNING@ ${darwin.signingUtils}
        chmod +x $out/bin/tcc-darwin-cc

        cp ${root + "/scripts/tinycc/selftest/hello.c"} hello.c
        $out/bin/tcc-darwin-cc hello.c -o hello
        set +e
        ./hello
        status="$?"
        set -e
        test "$status" = 42

        cp ${root + "/scripts/tinycc/selftest/data-reloc.c"} data-reloc.c
        $out/bin/tcc-darwin-cc data-reloc.c -o data-reloc
        ./data-reloc

        cp ${root + "/scripts/tinycc/selftest/function-reloc.c"} function-reloc.c
        $out/bin/tcc-darwin-cc function-reloc.c -o function-reloc
        ./function-reloc

        cp ${root + "/scripts/tinycc/selftest/string-reloc.c"} string-reloc.c
        $out/bin/tcc-darwin-cc string-reloc.c -o string-reloc
        test "$(./string-reloc)" = FIRSTSECOND

        $out/bin/tcc-darwin-cc -c hello.c -o hello.o
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        cp tinycc-sysv-libc.o tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
          hello.c hello data-reloc.c data-reloc function-reloc.c function-reloc \
          string-reloc.c string-reloc hello.o \
          $out/share/darwin-bootstrap/
      ''
    else
      null
