#!/bin/sh
## Fetch upstream tarballs needed for the chain phases beyond stage0.
##
## All downloads verified by SHA256 against pinned hashes (the same
## ones Nix uses).  Falls back to user-provided $BOOT_TARBALL_DIR if
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

    if [ -n "${BOOT_TARBALL_DIR:-}" ] && [ -f "$BOOT_TARBALL_DIR/$name" ]; then
        printf '  %s: copying from $BOOT_TARBALL_DIR\n' "$name"
        cp "$BOOT_TARBALL_DIR/$name" "$target"
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

## gcc-4.6 + its in-tree deps (gmp, mpfr, mpc)
fetch gcc-4.6.4.tar.bz2 \
    "https://ftp.gnu.org/gnu/gcc/gcc-4.6.4/gcc-4.6.4.tar.bz2" \
    35af16afa0b67af9b8eb15cafb76d2bc5f568540552522f5dc2c88dd45d977e8

fetch gmp-4.3.2.tar.bz2 \
    "https://ftp.gnu.org/gnu/gmp/gmp-4.3.2.tar.bz2" \
    936162c0312886c21581002b79932829aa048cfaf9937c6265aeaa14f1cd1775

fetch mpfr-2.4.2.tar.bz2 \
    "https://www.mpfr.org/mpfr-2.4.2/mpfr-2.4.2.tar.bz2" \
    c7e75a08a8d49d2082e4caee1591a05d11b9d5627514e678f02d66a124bcf2ba

fetch mpc-0.8.1.tar.gz \
    "https://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz" \
    e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4

## gcc-10 + its in-tree deps (gmp/mpfr/mpc/isl), built by our gcc-4.6 g++.
fetch gcc-10.4.0.tar.xz \
    "https://ftp.gnu.org/gnu/gcc/gcc-10.4.0/gcc-10.4.0.tar.xz" \
    c9297d5bcd7cb43f3dfc2fed5389e948c9312fd962ef6a4ce455cff963ebe4f1

fetch gmp-6.2.1.tar.xz \
    "https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz" \
    fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2

fetch mpfr-4.2.2.tar.xz \
    "https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.2.tar.xz" \
    b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01

fetch mpc-1.3.1.tar.gz \
    "https://ftp.gnu.org/gnu/mpc/mpc-1.3.1.tar.gz" \
    ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8

fetch isl-0.24.tar.bz2 \
    "https://gcc.gnu.org/pub/gcc/infrastructure/isl-0.24.tar.bz2" \
    fcf78dd9656c10eb8cf9fbd5f59a0b6b01386205fe1934b3b287a0a1898145c0
printf '\n== done ==\n'
