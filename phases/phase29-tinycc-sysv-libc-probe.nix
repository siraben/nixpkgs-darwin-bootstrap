args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase29-tinycc-sysv-libc-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap

        cat > hello.c <<'C'
        unsigned long strlen(const char *s);
        int main(void) { return (int)strlen("bootstrap"); }
        C

        cat > strlen.c <<'C'
        unsigned long strlen(const char *s)
        {
            const char *p = s;
            while (*p)
                p++;
            return p - s;
        }
        C

        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c hello.c -o hello.o \
          > hello-c.stdout \
          2> hello-c.stderr
        ${phase23-tinycc-mescc-link-probe}/bin/tcc -c strlen.c -o strlen.o \
          > strlen-c.stdout \
          2> strlen-c.stderr
        test ! -s hello-c.stdout
        test ! -s hello-c.stderr
        test ! -s strlen-c.stdout
        test ! -s strlen-c.stderr

        ${phase26b-elf64-to-m1}/bin/elf64-to-m1 --prefix hello_ hello.o hello-object.M1
        ${phase26b-elf64-to-m1}/bin/elf64-to-m1 --prefix strlen_ strlen.o strlen-object.M1

        cat > crt1-tcc-sysv.M1 <<'M1'
        :_start
        !0x48 !0x83 !0xe4 !0xf0
        !0xe8 %main
        !0x48 !0x89 !0xc7
        !0x48 !0xc7 !0xc0 !0x01 !0x00 !0x00 !0x02
        !0x0f !0x05
        M1

        emit_code() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' "$1"
        }

        emit_data() {
          awk '
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' "$1"
        }

        {
          cat crt1-tcc-sysv.M1
          emit_code hello-object.M1
          emit_code strlen-object.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          emit_data hello-object.M1
          emit_data strlen-object.M1
        } > hello-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f hello-combined.M1 \
          -o hello.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f hello.hex2 \
          -o hello

        ${python3}/bin/python3 ${root + "/tools/phase5-amd64-m2.py"} patch hello.hex2 hello

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=hello bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x hello

        source ${darwin.signingUtils}
        sign hello

        set +e
        ./hello
        status="$?"
        set -e
        test "$status" = 9

        cp hello.c strlen.c hello.o strlen.o hello-object.M1 strlen-object.M1 \
          crt1-tcc-sysv.M1 hello-combined.M1 hello.hex2 hello \
          hello-c.stdout hello-c.stderr strlen-c.stdout strlen-c.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null
