#!/bin/sh
## 19-nyacc — stage the nyacc Scheme parser library.
##
## nyacc provides the C99 parser mescc.scm loads (via
## GUILE_LOAD_PATH) to parse C source; steps 20-21 put its module/
## directory on the mes load path.  Extraction only.
##
## Runs:     Apple tar, mkdir, test; /bin/sh orchestrates.
## Inputs:   tarballs/nyacc-1.09.1.tar.gz (fetched against a pinned
##           SHA-256 by scripts/fetch-sources.sh).
## Outputs:  target/nyacc/share/nyacc-1.09.1 (Scheme source tree).
## Verifies: the module/nyacc directory exists after extraction.
## Trust:    upstream release text pinned by hash; no translation or
##           binary layout in this step.
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
