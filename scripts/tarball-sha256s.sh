#!/bin/sh
## Shared SHA-256 verifier for shell-track upstream tarballs.
## Sourced by fetch-sources.sh and the extraction steps.

boot_tarball_sha256() {
  case "$1" in
    mes-0.27.1.tar.gz) echo 183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d ;;
    nyacc-1.09.1.tar.gz) echo 0ec9ae537e0d951781a50de3c7929ac97a85c1d4b5e85e5d51542e3751022717 ;;
    make-4.4.1.tar.gz) echo dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3 ;;
    gcc-4.6.4.tar.bz2) echo 35af16afa0b67af9b8eb15cafb76d2bc5f568540552522f5dc2c88dd45d977e8 ;;
    gmp-4.3.2.tar.bz2) echo 936162c0312886c21581002b79932829aa048cfaf9937c6265aeaa14f1cd1775 ;;
    mpfr-2.4.2.tar.bz2) echo c7e75a08a8d49d2082e4caee1591a05d11b9d5627514e678f02d66a124bcf2ba ;;
    mpc-0.8.1.tar.gz) echo e664603757251fd8a352848276497a4c79b7f8b21fd8aedd5cc0598a38fee3e4 ;;
    gcc-10.4.0.tar.xz) echo c9297d5bcd7cb43f3dfc2fed5389e948c9312fd962ef6a4ce455cff963ebe4f1 ;;
    gmp-6.2.1.tar.xz) echo fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2 ;;
    mpfr-4.2.2.tar.xz) echo b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01 ;;
    mpc-1.3.1.tar.gz) echo ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8 ;;
    isl-0.24.tar.bz2) echo fcf78dd9656c10eb8cf9fbd5f59a0b6b01386205fe1934b3b287a0a1898145c0 ;;
    *) return 1 ;;
  esac
}

boot_verify_tarball() {
  path=$1
  name=$(basename "$path")
  expected=$(boot_tarball_sha256 "$name") || {
    echo "no pinned SHA-256 for $name" >&2
    return 1
  }
  if [ ! -f "$path" ]; then
    echo "missing $path; run scripts/fetch-sources.sh first" >&2
    return 1
  fi
  actual=$(/usr/bin/shasum -a 256 "$path" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    echo "$path: SHA256 mismatch (got $actual, expected $expected)" >&2
    return 1
  fi
}
