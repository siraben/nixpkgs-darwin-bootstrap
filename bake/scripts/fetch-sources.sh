#!/bin/sh
## Fetch upstream tarballs needed for bake/ phases beyond stage0.
##
## All downloads verified by SHA256 against pinned hashes (the same
## ones Nix uses).  Falls back to user-provided $BAKE_TARBALL_DIR if
## set so this can be run offline.
set -eu

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TARBALLS="$ROOT/tarballs"
mkdir -p "$TARBALLS"

fetch() {
    name=$1
    url=$2
    expected_sha=$3
    target="$TARBALLS/$name"
    if [ -f "$target" ]; then
        actual=$(/usr/bin/shasum -a 256 "$target" | awk '{print $1}')
        if [ "$actual" = "$expected_sha" ]; then
            printf '  %s: cached (sha matches)\n' "$name"
            return 0
        fi
        printf '  %s: cached but sha mismatch (got %s, expected %s); refetching\n' \
            "$name" "$actual" "$expected_sha"
    fi

    if [ -n "${BAKE_TARBALL_DIR:-}" ] && [ -f "$BAKE_TARBALL_DIR/$name" ]; then
        printf '  %s: copying from $BAKE_TARBALL_DIR\n' "$name"
        cp "$BAKE_TARBALL_DIR/$name" "$target"
    else
        printf '  %s: downloading %s\n' "$name" "$url"
        /usr/bin/curl -fsSL "$url" -o "$target.tmp"
        mv "$target.tmp" "$target"
    fi

    actual=$(/usr/bin/shasum -a 256 "$target" | awk '{print $1}')
    if [ "$actual" != "$expected_sha" ]; then
        printf '  %s: SHA256 MISMATCH (got %s, expected %s)\n' \
            "$name" "$actual" "$expected_sha" >&2
        rm -f "$target"
        exit 1
    fi
    printf '  %s: ok (%s)\n' "$name" "$actual"
}

printf '== fetching tarballs into %s ==\n' "$TARBALLS"

fetch mes-0.27.1.tar.gz \
    "https://ftp.gnu.org/gnu/mes/mes-0.27.1.tar.gz" \
    183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d

## nyacc (needed by mescc.scm)
fetch nyacc-1.09.1.tar.gz \
    "https://download.savannah.nongnu.org/releases/nyacc/nyacc-1.09.1.tar.gz" \
    0ec9ae537e0d951781a50de3c7929ac97a85c1d4b5e85e5d51542e3751022717

## gnumake (built by tcc-darwin-cc, used to build gcc-4.6)
fetch make-4.4.1.tar.gz \
    "https://ftp.gnu.org/gnu/make/make-4.4.1.tar.gz" \
    dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3

## gcc-4.6/10/15 will follow once we get past gnumake
printf '\n== done ==\n'
