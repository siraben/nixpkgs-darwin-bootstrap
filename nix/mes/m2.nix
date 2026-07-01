{
  darwin,
  lib,
  mesNyacc,
  mesVersion,
  nyaccVersion,
  hex2,
  mes-source,
  mes-macho-link-probe,
  mes-m2,
  m1,
  runCommand,
  root,
  ...
}:
runCommand "mes-m2" { } ''
  mkdir -p $out/bin $out/share/darwin-bootstrap

  cp ${mes-macho-link-probe}/share/darwin-bootstrap/mes-m2 $out/bin/mes-m2
  chmod 555 $out/bin/mes-m2

  sed \
    -e 's|@prefix@|${mes-source}|g' \
    -e 's|@VERSION@|${mesVersion}|g' \
    -e 's|@mes_cpu@|x86_64|g' \
    -e 's|@mes_kernel@|darwin|g' \
    ${mes-source}/scripts/mescc.scm.in > $out/bin/mescc.scm
  chmod 444 $out/bin/mescc.scm

  cp ${root + "/mes/fixtures/m2-trivial.c"} trivial.c
  mesLoadPath=${mes-source}/module:${mes-source}/mes/module:${mesNyacc}/share/nyacc-${nyaccVersion}/module

  MES_PREFIX=${mes-source} \
    GUILE_LOAD_PATH="$mesLoadPath" \
    $out/bin/mes-m2 -c "(display 'Hello,M2-mes!) (newline)" \
    > mes-m2.stdout 2> mes-m2.stderr
  grep -q 'Hello,M2-mes!' mes-m2.stdout
  test ! -s mes-m2.stderr

  MES_PREFIX=${mes-source} \
    GUILE_LOAD_PATH="$mesLoadPath" \
    srcdest=${mes-source}/ \
    includedir=${mes-source}/include \
    libdir=${mes-source}/lib \
    M1=${m1}/bin/M1 \
    HEX2=${hex2}/bin/hex2 \
    $out/bin/mes-m2 --no-auto-compile -e main $out/bin/mescc.scm -- \
      -S -I ${mes-source}/include -D HAVE_CONFIG_H=1 \
      trivial.c -o trivial.M1 \
    > mescc-trivial.stdout 2> mescc-trivial.stderr

  test -s trivial.M1
  chmod 444 trivial.M1
  grep -q main trivial.M1

  cp mes-m2.stdout mes-m2.stderr mescc-trivial.stdout mescc-trivial.stderr trivial.M1 \
    $out/share/darwin-bootstrap/
''
