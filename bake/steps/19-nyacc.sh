#!/bin/sh
## 19-nyacc — extract nyacc Scheme library used by mescc.scm.
set -eu

tarball="$ROOT/tarballs/nyacc-1.09.1.tar.gz"
if [ ! -f "$tarball" ]; then
    echo "missing $tarball; run scripts/fetch-sources.sh first" >&2
    exit 1
fi

out="$TARGET/nyacc"
rm -rf "$out"
mkdir -p "$out/share"
cd "$out/share"
tar -xzf "$tarball"
test -d nyacc-1.09.1/module/nyacc
