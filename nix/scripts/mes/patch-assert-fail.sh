#!/usr/bin/env bash
## Rewrite Mes's __assert_fail to use nested ifs instead of `&&` so that
## bootstrap M2-Planet-class compilers (without short-circuit `&&`) get
## the right behavior.  Pure bash fixed-string substitution: this phase
## precedes the chain gnupatch, and the build uses no perl/awk/python.
set -eu

target="$out/lib/mes/__assert_fail.c"

a1=$'  if (file && *file)\n    {\n      eputs (file);\n      eputs (":");\n    }\n'
b1=$'  if (file)\n    if (*file)\n      {\n        eputs (file);\n        eputs (":");\n      }\n'
a2=$'  if (function && *function)\n    {\n      eputs (function);\n      eputs (":");\n    }\n'
b2=$'  if (function)\n    if (*function)\n      {\n        eputs (function);\n        eputs (":");\n      }\n'

content="$(cat "$target")"$'\n'
new="${content//"$a1"/$b1}"
new="${new//"$a2"/$b2}"
if [ "$new" = "$content" ]; then
  echo "-patch-assert-fail: no substitution applied to $target" >&2
  exit 1
fi
printf '%s' "$new" > "$target"
