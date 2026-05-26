#!/usr/bin/env bash
## Rewrite Mes's __assert_fail to use nested ifs instead of `&&` so that
## bootstrap M2-Planet-class compilers (without short-circuit `&&`) get
## the right behavior.
set -eu

target="$out/lib/mes/__assert_fail.c"

perl -i -0pe '
  my $a1 = "  if (file && *file)\n    {\n      eputs (file);\n      eputs (\":\");\n    }\n";
  my $b1 = "  if (file)\n    if (*file)\n      {\n        eputs (file);\n        eputs (\":\");\n      }\n";
  my $a2 = "  if (function && *function)\n    {\n      eputs (function);\n      eputs (\":\");\n    }\n";
  my $b2 = "  if (function)\n    if (*function)\n      {\n        eputs (function);\n        eputs (\":\");\n      }\n";
  s/\Q$a1\E/$b1/g;
  s/\Q$a2\E/$b2/g;
' "$target"
