args:
with args;
runCommand "phase24-tinycc-compile-probe" { } ''
  mkdir -p $out/share/darwin-bootstrap

  cat > hello.c <<'C'
  #define VALUE 42
  int main(void) { return VALUE; }
  C

  ${phase23-tinycc-mescc-link-probe}/bin/tcc -E hello.c > hello.i 2> hello-E.stderr
  grep -q 'return 42' hello.i
  test ! -s hello-E.stderr

  ${phase23-tinycc-mescc-link-probe}/bin/tcc -c hello.c -o hello.o > hello-c.stdout 2> hello-c.stderr
  test ! -s hello-c.stdout
  test ! -s hello-c.stderr
  test "$(od -An -tx1 -N4 hello.o | tr -d ' \n')" = "7f454c46"

  cp hello.c hello.i hello.o hello-E.stderr hello-c.stdout hello-c.stderr \
    $out/share/darwin-bootstrap/
''
