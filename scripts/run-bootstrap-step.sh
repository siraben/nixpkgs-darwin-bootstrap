#!/bin/sh
# Run a step and account for its optional signing work inside the same timing
# boundary. The driver supplies ROOT/TARGET and closes stdin for configure.
set -eu
/bin/sh "$1"
if [ "${BOOT_SIGN_EXECUTABLES:-0}" = 1 ]; then
  for tool in "$TARGET/bin/"*; do
    # The trust-root seed stays byte-identical to its committed source.
    [ "${tool##*/}" = hex0 ] && continue
    /bin/sh "$ROOT/scripts/sign-bootstrap-tools.sh" "$tool"
  done
fi
