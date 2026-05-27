{
  darwin,
  lib,
  mesNyacc,
  nyaccVersion,
  phase10-hex2,
  phase13-mes-source,
  phase16-mes-m2,
  phase22-mescc-libc-tcc-probe,
  phase9-m1,
  runCommand,
  source,
  ...
}:
runCommand "phase22-mescc-libc-tcc-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap m1 logs

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

  cat > config.sh <<'EOF'
  mes_cpu=x86_64
  mes_kernel=linux
  compiler=mescc
  mes_libc=mes
  EOF
  . ./config.sh
  . ${phase13-mes-source}/build-aux/configure-lib.sh

  map_source() {
    source="$1"
    case "$source" in
      lib/linux/x86_64-mes-mescc/*)
        mapped="lib/darwin/x86_64-mes-mescc/$(basename "$source")"
        ;;
      lib/linux/*)
        mapped="lib/darwin/''${source#lib/linux/}"
        ;;
      *)
        mapped="$source"
        ;;
    esac
    if test -f "${phase13-mes-source}/$mapped"; then
      printf '%s\n' "$mapped"
    else
      printf '%s\n' "$source"
    fi
  }

  compile_m1() {
    source="$1"
    mapped="$(map_source "$source")"
    source_path="${phase13-mes-source}/$mapped"
    object_name="$(printf '%s\n' "$mapped" | sed -e 's|/|-|g' -e 's|[.]c$||').M1"
    output_path="m1/$object_name"
    echo "$source -> $mapped" >> logs/sources.map
    mescc -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 "$source_path" -o "$output_path" \
      > "$output_path.stdout" 2> "$output_path.stderr"
    test -s "$output_path"
    sed -i.bak '/^<$/d' "$output_path"
    rm -f "$output_path.bak"
    chmod 444 "$output_path"
    printf '%s\n' "$output_path" >> logs/objects.list
  }

  for source in $libc_tcc_SOURCES; do
    compile_m1 "$source"
  done

  while read -r object; do
    case "$object" in
      *lib-mes-globals.M1)
        ;;
      *)
        split_label='^:ELF_data$'
        if test "$(basename "$object")" = "lib-stdlib-exit.M1"; then
          split_label='^:__call_at_exit$'
        fi
        awk '
          split_re != "" && $0 ~ split_re { data = 1; next }
          /^:ELF_data$/ { data = 1; next }
          /^:HEX2_data$/ { next }
          data != 1 { print }
        ' split_re="$split_label" "$object"
        ;;
    esac
  done < logs/objects.list > logs/code.M1

  {
    cat logs/code.M1
    echo ':ELF_data'
    echo ':HEX2_data'
    while read -r object; do
      case "$object" in
        *lib-mes-globals.M1)
          cat "$object"
          ;;
        *)
          split_label='^:ELF_data$'
          if test "$(basename "$object")" = "lib-stdlib-exit.M1"; then
            split_label='^:__call_at_exit$'
          fi
          awk '
            split_re != "" && $0 ~ split_re { data = 1; print; next }
            /^:ELF_data$/ { data = 1; next }
            /^:HEX2_data$/ { next }
            data == 1 { print }
          ' split_re="$split_label" "$object"
          ;;
      esac
    done < logs/objects.list
  } > 'libc+tcc.M1'

  grep -q '^:fprintf' 'libc+tcc.M1'
  grep -q '^:setjmp' 'libc+tcc.M1'
  grep -q '^:__sys_call4' 'libc+tcc.M1'
  grep -q '^:ELF_data' 'libc+tcc.M1'

  cp 'libc+tcc.M1' logs/sources.map logs/objects.list $out/share/darwin-bootstrap/
''
