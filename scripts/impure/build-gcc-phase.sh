#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: scripts/impure/build-gcc-phase.sh phase44|phase45|phase46

Runs the GCC bootstrap phase in a persistent local work directory so failures can
be reproduced and fixed without replaying a full Nix derivation each time.

Environment overrides:
  IMPURE_ROOT     Local work root, default: $PWD/work/impure
  BOOTSTRAP_MAKE  Make executable, default: host make for impure speed
  BOOTSTRAP_JOBS  Parallel jobs, default: min(host CPUs, 8)
  GCC46_CXX_RESUME  If 1, reuse existing phase44 build/gcc Makefiles
  GCC46_CXX_MAKE_DIR Make subdirectory for phase44 target iteration, e.g. gcc
  GCC46_CXX_TARGETS Make targets for phase44, e.g. "c-lang.o c-family/stub-objc.o"
  GCC46_CXX_SKIP_INSTALL If 1, stop after phase44 make targets
  TCC_OUT         phase34 tinycc Darwin cc store path
  ALL_GCC_OUT         phase35 GCC 4.6 all-gcc store path
  GCC46_OUT         phase37 GCC 4.6 bootstrap store path
  MAKE_OUT         phase39 GNU make store path
  GCC10_SRC_OUT         phase42 GCC 10 source store path
  GCC_LATEST_SRC_OUT         phase43 latest GCC source store path
  GCC46_CXX_OUT     local phase44 output path
  GCC10_OUT     local phase45 output path
  CCTOOLS         cctools store path
  BOOTSTRAP_SYSTEM flake package system, default: x86_64-darwin
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

phase=$1
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
impure_root=${IMPURE_ROOT:-"$repo_root/work/impure"}

system=${BOOTSTRAP_SYSTEM:-x86_64-darwin}
attr_path() {
  nix build --no-link --print-out-paths ".#packages.$system.$1"
}

nixpkgs_path() {
  local attr=$1
  nix eval --raw --impure --expr \
    "let flake = builtins.getFlake (toString $repo_root); pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; }; in pkgs.$attr.outPath"
}

phase34=${TCC_OUT:-}
phase35=${ALL_GCC_OUT:-}
phase37=${GCC46_OUT:-}
phase39=${MAKE_OUT:-}
phase42=${GCC10_SRC_OUT:-}
phase43=${GCC_LATEST_SRC_OUT:-}
cctools=${CCTOOLS:-}

mkdir -p "$impure_root"

if [ -z "${BOOTSTRAP_MAKE:-}" ]; then
  export BOOTSTRAP_MAKE=$(command -v gmake || command -v make)
fi
if [ -z "${BOOTSTRAP_JOBS:-}" ]; then
  host_cpus=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
  if [ "$host_cpus" -gt 8 ]; then
    export BOOTSTRAP_JOBS=8
  else
    export BOOTSTRAP_JOBS=$host_cpus
  fi
fi

if [ -z "$phase39" ]; then phase39=$(attr_path bootstrap-gnumake); fi
if [ -z "$cctools" ]; then cctools=$(nixpkgs_path cctools); fi

case "$phase" in
  phase44)
    if [ -z "$phase34" ]; then phase34=$(attr_path tinycc-darwin-cc); fi
    if [ -z "$phase35" ]; then phase35=$(attr_path gcc46-all-gcc); fi
    if [ -z "$phase37" ]; then phase37=$(attr_path gcc46); fi
    work_dir="$impure_root/phase44-gcc46-cxx"
    out=${GCC46_CXX_OUT:-"$work_dir/out"}
    mkdir -p "$work_dir"
    cd "$work_dir"
    "$repo_root/scripts/gcc-4.6/cxx.sh" \
      "$phase35" \
      "$phase37" \
      "$phase39" \
      "$phase34" \
      "$cctools" \
      "$out" \
      4.6.4
    ;;
  phase45)
    if [ -z "$phase42" ]; then phase42=$(attr_path gcc10-source); fi
    phase44_out=${GCC46_CXX_OUT:-"$impure_root/phase44-gcc46-cxx/out"}
    if [ -z "$phase34" ]; then phase34="$phase44_out"; fi
    work_dir="$impure_root/phase45-gcc10"
    out=${GCC10_OUT:-"$work_dir/out"}
    mkdir -p "$work_dir"
    cd "$work_dir"
    export GCC_MODERN_TARGETS=${GCC_MODERN_TARGETS:-all-gcc}
    export GCC_MODERN_COMPILER_ONLY=${GCC_MODERN_COMPILER_ONLY:-1}
    "$repo_root/scripts/gcc-modern/bootstrap-gcc.sh" \
      "$phase42" \
      "$phase44_out" \
      "$phase39" \
      "$phase34" \
      "$cctools" \
      "$out" \
      10.4.0 \
      gcc10
    ;;
  phase46)
    if [ -z "$phase43" ]; then phase43=$(attr_path gcc-latest-source); fi
    phase45_out=${GCC10_OUT:-"$impure_root/phase45-gcc10/out"}
    if [ -z "$phase34" ]; then phase34="$phase45_out"; fi
    work_dir="$impure_root/phase46-gcc-latest"
    out=${GCC_LATEST_OUT:-"$work_dir/out"}
    mkdir -p "$work_dir"
    cd "$work_dir"
    export GCC_MODERN_TARGETS=${GCC_MODERN_TARGETS:-all-gcc}
    export GCC_MODERN_COMPILER_ONLY=${GCC_MODERN_COMPILER_ONLY:-1}
    "$repo_root/scripts/gcc-modern/bootstrap-gcc.sh" \
      "$phase43" \
      "$phase45_out" \
      "$phase39" \
      "$phase34" \
      "$cctools" \
      "$out" \
      "${GCC_LATEST_VERSION:-15.2.0}" \
      gcc-latest
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
esac
