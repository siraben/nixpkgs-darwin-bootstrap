args:
with args;
runCommand "darwin-minimal-bootstrap-phase20-mescc-libmescc-probe-amd64" { } ''
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

  compile_m1 ${phase13-mes-source}/lib/mes/globals.c m1/globals.M1
  compile_m1 ${phase13-mes-source}/lib/darwin/x86_64-mes-mescc/syscall-internal.c m1/syscall-internal.M1

  {
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data != 1 { print }
    ' m1/syscall-internal.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    cat m1/globals.M1
    awk '
      /^:ELF_data$/ { data = 1; next }
      /^:HEX2_data$/ { next }
      data == 1 { print }
    ' m1/syscall-internal.M1
  } > libmescc.M1

  grep -q '^:__raise' libmescc.M1
  grep -q '^:__sys_call_internal' libmescc.M1

  cp libmescc.M1 m1/globals.M1 m1/syscall-internal.M1 \
    m1/globals.M1.stdout m1/globals.M1.stderr \
    m1/syscall-internal.M1.stdout m1/syscall-internal.M1.stderr \
    $out/share/darwin-bootstrap/
''
