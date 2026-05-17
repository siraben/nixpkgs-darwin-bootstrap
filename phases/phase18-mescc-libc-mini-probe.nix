args:
with args;
    if hostPlatform.isx86_64 then
      runCommand "darwin-minimal-bootstrap-phase18-mescc-libc-mini-probe-amd64" { } ''
        mkdir -p $out/share/darwin-bootstrap m1

        mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module
        mescc() {
          MES_PREFIX=${phase13-mes-source} \
            GUILE_LOAD_PATH="$mesLoadPath" \
            srcdest=${phase13-mes-source}/ \
            includedir=${phase13-mes-source}/include \
            libdir=${phase13-mes-source}/lib \
            M1=${phase9-m1}/bin/M1 \
            HEX2=${phase10-hex2}/bin/hex2 \
            MES_STACK=6000000 \
            MES_ARENA=60000000 \
            MES_MAX_ARENA=60000000 \
            ${phase16-mes-m2}/bin/mes-m2 --no-auto-compile -e main ${phase16-mes-m2}/bin/mescc.scm -- "$@"
        }

        compile_m1() {
          source_path="$1"
          output_path="$2"
          mescc -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 "$source_path" -o "$output_path" \
            > "$output_path.stdout" 2> "$output_path.stderr"
          test -s "$output_path"
          sed -i.bak '/^<$/d' "$output_path"
          rm -f "$output_path.bak"
          chmod 444 "$output_path"
        }

        compile_m1 ${phase13-mes-source}/lib/mes/__init_io.c m1/__init_io.M1
        compile_m1 ${phase13-mes-source}/lib/mes/eputs.c m1/eputs.M1
        compile_m1 ${phase13-mes-source}/lib/mes/oputs.c m1/oputs.M1
        compile_m1 ${phase13-mes-source}/lib/mes/globals.c m1/globals.M1
        compile_m1 ${phase13-mes-source}/lib/stdlib/exit.c m1/exit.M1
        compile_m1 ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/_exit.c m1/_exit.M1
        compile_m1 ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/_write.c m1/_write.M1
        compile_m1 ${phase13-mes-source}/lib/stdlib/puts.c m1/puts.M1
        compile_m1 ${phase13-mes-source}/lib/string/strlen.c m1/strlen.M1
        compile_m1 ${phase13-mes-source}/lib/mes/write.c m1/write.M1

        cat > puts-smoke.c <<'EOF'
        int puts (char const *s);
        int main () { puts ("libc-mini"); return 0; }
        EOF
        compile_m1 puts-smoke.c puts-smoke.M1

        for file in m1/*.M1; do
          if test "$(basename "$file")" = "globals.M1"; then
            cat "$file" >> libc-mini.data.M1
            continue
          fi
          split_label='^:ELF_data$'
          if test "$(basename "$file")" = "exit.M1"; then
            split_label='^:__call_at_exit$'
          fi
          awk '
            split_re != "" && $0 ~ split_re { data = 1; next }
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data != 1 { print }
          ' split_re="$split_label" "$file" >> libc-mini.code.M1
          awk '
            split_re != "" && $0 ~ split_re { data = 1; print; next }
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' split_re="$split_label" "$file" >> libc-mini.data.M1
        done
        {
          cat libc-mini.code.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          cat libc-mini.data.M1
        } > libc-mini.M1

        awk '
          /^:ELF_data$/ { data = 1; next }
          /^:HEX2_data$/ { next }
          data != 1 { print }
        ' puts-smoke.M1 > puts-smoke.code.M1
        awk '
          /^:ELF_data$/ { data = 1; next }
          /^:HEX2_data$/ { next }
          data == 1 { print }
        ' puts-smoke.M1 > puts-smoke.data.M1
        {
          cat libc-mini.code.M1
          cat puts-smoke.code.M1
          echo ':ELF_data'
          echo ':HEX2_data'
          cat libc-mini.data.M1
          cat puts-smoke.data.M1
        } > puts-smoke-combined.M1

        ${phase9-m1}/bin/M1 \
          --architecture amd64 \
          --little-endian \
          -f ${phase13-mes-source}/lib/m2/x86_64/x86_64_defs.M1 \
          -f ${phase13-mes-source}/lib/x86_64-mes/x86_64.M1 \
          -f ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/crt1-libc.M1 \
          -f puts-smoke-combined.M1 \
          -o puts-smoke.hex2

        ${phase10-hex2}/bin/hex2 \
          --architecture amd64 \
          --little-endian \
          --base-address 0x1000000 \
          -f ${phase3-m0}/share/darwin-bootstrap/MACHO-amd64-lowdata.hex2 \
          -f puts-smoke.hex2 \
          -o puts-smoke

        ${python3}/bin/python3 ${root + "/tools/phase5-amd64-m2.py"} patch puts-smoke.hex2 puts-smoke

        linkeditOffset="$((0x800000 + 0x2000000))"
        dd if=/dev/zero of=puts-smoke bs=1 count=1 seek="$((linkeditOffset - 1))" conv=notrunc
        chmod +x puts-smoke

        source ${darwin.signingUtils}
        sign puts-smoke

        ./puts-smoke > puts-smoke.stdout 2> puts-smoke.stderr
        test "$(cat puts-smoke.stdout)" = "libc-mini"
        test ! -s puts-smoke.stderr

        cp libc-mini.M1 puts-smoke.M1 puts-smoke-combined.M1 puts-smoke.hex2 puts-smoke.stdout puts-smoke.stderr \
          $out/share/darwin-bootstrap/
      ''
    else
      null
