{
  darwin,
  lib,
  mesNyacc,
  mesVersion,
  nyaccVersion,
  phase10-hex2,
  phase13-mes-source,
  phase15-mes-macho-link-probe,
  phase16-mes-m2,
  phase9-m1,
  runCommand,
  ...
}:
runCommand "phase16-mes-m2" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  cp ${phase15-mes-macho-link-probe}/share/darwin-bootstrap/mes-m2 $out/bin/mes-m2
  chmod 555 $out/bin/mes-m2

  sed \
    -e 's|@prefix@|${phase13-mes-source}|g' \
    -e 's|@VERSION@|${mesVersion}|g' \
    -e 's|@mes_cpu@|x86_64|g' \
    -e 's|@mes_kernel@|darwin|g' \
    ${phase13-mes-source}/scripts/mescc.scm.in > $out/bin/mescc.scm
  chmod 444 $out/bin/mescc.scm

  cat > trivial.c <<'EOF'
  int main () { return 0; }
  EOF

  mesLoadPath=${phase13-mes-source}/module:${phase13-mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module

  MES_PREFIX=${phase13-mes-source} \
    GUILE_LOAD_PATH="$mesLoadPath" \
    $out/bin/mes-m2 -c "(display 'Hello,M2-mes!) (newline)" \
    > mes-m2.stdout 2> mes-m2.stderr
  grep -q 'Hello,M2-mes!' mes-m2.stdout
  test ! -s mes-m2.stderr

  MES_PREFIX=${phase13-mes-source} \
    GUILE_LOAD_PATH="$mesLoadPath" \
    srcdest=${phase13-mes-source}/ \
    includedir=${phase13-mes-source}/include \
    libdir=${phase13-mes-source}/lib \
    M1=${phase9-m1}/bin/M1 \
    HEX2=${phase10-hex2}/bin/hex2 \
    $out/bin/mes-m2 --no-auto-compile -e main $out/bin/mescc.scm -- \
      -S -I ${phase13-mes-source}/include -D HAVE_CONFIG_H=1 \
      trivial.c -o trivial.M1 \
    > mescc-trivial.stdout 2> mescc-trivial.stderr

  test -s trivial.M1
  chmod 444 trivial.M1
  grep -q main trivial.M1

  cp mes-m2.stdout mes-m2.stderr mescc-trivial.stdout mescc-trivial.stderr trivial.M1 \
    $out/share/darwin-bootstrap/
''
