args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase33-tinycc-boot1-link-candidate-amd64" { } ''
        mkdir -p $out/bin $out/share/darwin-bootstrap

        ${phase30-tinycc-self-link-candidate}/bin/tcc-self-candidate -c \
          ${root + "/bootstrap/tinycc-sysv-libc.c"} \
          -o tinycc-sysv-libc.o \
          > tinycc-sysv-libc.stdout \
          2> tinycc-sysv-libc.stderr

        ${phase26b-elf64-to-m1}/bin/elf64-to-m1 --prefix tinycc_sysv_libc_ \
          tinycc-sysv-libc.o \
          tinycc-sysv-libc.M1

        ${phase26b-elf64-to-m1}/bin/elf64-to-m1 --prefix tcc_boot1_ \
          ${phase32-tinycc-boot1-object-probe}/share/darwin-bootstrap/tcc-boot1.o \
          tcc-boot1.M1

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
          cat ${root + "/bootstrap/tinycc-sysv-syscalls-amd64-darwin.M1"}
          emit_code tcc-boot1.M1
          emit_code tinycc-sysv-libc.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          emit_data tcc-boot1.M1
          emit_data tinycc-sysv-libc.M1
        } > tcc-boot1-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f tcc-boot1-combined.M1 \
          -o tcc-boot1.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f tcc-boot1.hex2 \
          -o tcc-boot1

        ${phase11c-hex2-data-relocs}/bin/hex2-data-relocs patch tcc-boot1.hex2 tcc-boot1

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=tcc-boot1 bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x tcc-boot1

        source ${darwin.signingUtils}
        sign tcc-boot1

        set +e
        ./tcc-boot1 -version > tcc-boot1-version.stdout 2> tcc-boot1-version.stderr
        version_status="$?"
        set -e
        printf '%s\n' "$version_status" > tcc-boot1-version.status
        test "$version_status" = 0
        grep -q '0.9.28-darwin-bootstrap' tcc-boot1-version.stdout
        test ! -s tcc-boot1-version.stderr

        cat > hello.c <<'C'
        int main(void) { return 42; }
        C
        set +e
        ./tcc-boot1 -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
        compile_status="$?"
        set -e
        printf '%s\n' "$compile_status" > hello-c.status
        test "$compile_status" = 0
        test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

        cp tcc-boot1 $out/bin/tcc-boot1-candidate
        cp tinycc-sysv-libc.o tinycc-sysv-libc.M1 \
          tinycc-sysv-libc.stdout tinycc-sysv-libc.stderr \
          tcc-boot1.M1 crt1-tcc-sysv.M1 tcc-boot1-combined.M1 tcc-boot1.hex2 \
          tcc-boot1-version.stdout tcc-boot1-version.stderr tcc-boot1-version.status \
          hello.c hello-c.stdout hello-c.stderr hello-c.status \
          $out/share/darwin-bootstrap/
        if test -f hello.o; then
          cp hello.o $out/share/darwin-bootstrap/
        fi
      ''
    else
      null
