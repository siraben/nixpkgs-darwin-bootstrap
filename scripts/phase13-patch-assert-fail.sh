#!/bin/sh
## Rewrite Mes's __assert_fail.c to use nested ifs instead of `&&` so
## that bootstrap M2-Planet-class compilers (without short-circuit
## `&&`) get the right behavior.
##
## Invoked by step 15-mes-source.sh with the extracted mes source tree
## as $1; edits lib/mes/__assert_fail.c in place.  No other env contract.
## Trust: host /usr/bin/perl — trust boundary (an anchored, auditable
## C source text substitution; no code generation).
set -eu

target="$1/lib/mes/__assert_fail.c"

/usr/bin/perl -i -0pe '
  my $n = 0;
  my $a1 = "  if (file && *file)\n    {\n      eputs (file);\n      eputs (\":\");\n    }\n";
  my $b1 = "  if (file)\n    if (*file)\n      {\n        eputs (file);\n        eputs (\":\");\n      }\n";
  my $a2 = "  if (function && *function)\n    {\n      eputs (function);\n      eputs (\":\");\n    }\n";
  my $b2 = "  if (function)\n    if (*function)\n      {\n        eputs (function);\n        eputs (\":\");\n      }\n";
  $n += s/\Q$a1\E/$b1/g;
  $n += s/\Q$a2\E/$b2/g;
  die "no __assert_fail substitutions applied\n" if eof && $n == 0;
' "$target"
