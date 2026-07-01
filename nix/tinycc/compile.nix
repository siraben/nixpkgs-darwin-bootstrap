{
  tinycc-mescc-link-probe,
  tinycc-compile-probe,
  runCommand,
  root,
  ...
}:
runCommand "tinycc-compile-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  cp ${root + "/tinycc/fixtures/compile-hello.c"} hello.c
  ${tinycc-mescc-link-probe}/bin/tcc -E hello.c > hello.i 2> hello-E.stderr
  grep -q 'return 42' hello.i
  test ! -s hello-E.stderr

  ${tinycc-mescc-link-probe}/bin/tcc -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
  test ! -s hello-c.stdout
  test ! -s hello-c.stderr
  test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

  cp hello.c hello.i hello.o hello-E.stderr hello-c.stdout hello-c.stderr \
    $out/share/darwin-bootstrap/
''
