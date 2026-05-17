#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: scripts/impure/build-gcc-phase.sh phase44|phase45|phase46

Runs the GCC bootstrap phase in a persistent local work directory so failures can
be reproduced and fixed without replaying a full Nix derivation each time.

Environment overrides:
  IMPURE_ROOT     Local work root, default: $PWD/work/impure
  PHASE34         phase34 tinycc Darwin cc store path
  PHASE35         phase35 GCC 4.6 all-gcc store path
  PHASE37         phase37 GCC 4.6 bootstrap store path
  PHASE39         phase39 GNU make store path
  PHASE42         phase42 GCC 10 source store path
  PHASE43         phase43 latest GCC source store path
  PHASE44_OUT     local phase44 output path
  PHASE45_OUT     local phase45 output path
  CCTOOLS         cctools store path
EOF
}

if [ "$#" -ne 1 ]; then
  usage
  exit 2
fi

phase=$1
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
impure_root=${IMPURE_ROOT:-"$repo_root/work/impure"}

system=$(nix eval --raw --impure --expr builtins.currentSystem)
attr_path() {
  nix build --no-link --print-out-paths ".#packages.$system.$1"
}

nixpkgs_path() {
  local attr=$1
  nix eval --raw --impure --expr \
    "let flake = builtins.getFlake (toString $repo_root); pkgs = import flake.inputs.nixpkgs { system = builtins.currentSystem; }; in pkgs.$attr.outPath"
}

phase34=${PHASE34:-}
phase35=${PHASE35:-}
phase37=${PHASE37:-}
phase39=${PHASE39:-}
phase42=${PHASE42:-}
phase43=${PHASE43:-}
cctools=${CCTOOLS:-}

mkdir -p "$impure_root"

if [ -z "$phase34" ]; then phase34=$(attr_path phase34-tinycc-darwin-cc); fi
if [ -z "$phase39" ]; then phase39=$(attr_path phase39-gnumake); fi
if [ -z "$cctools" ]; then cctools=$(nixpkgs_path cctools); fi

case "$phase" in
  phase44)
    if [ -z "$phase35" ]; then phase35=$(attr_path phase35-gcc46-all-gcc); fi
    if [ -z "$phase37" ]; then phase37=$(attr_path phase37-gcc46-bootstrap); fi
    work_dir="$impure_root/phase44-gcc46-cxx"
    out=${PHASE44_OUT:-"$work_dir/out"}
    mkdir -p "$work_dir"
    cd "$work_dir"
    "$repo_root/scripts/gcc46/phase44-cxx.sh" \
      "$phase35" \
      "$phase37" \
      "$phase39" \
      "$phase34" \
      "$cctools" \
      "$out" \
      4.6.4
    ;;
  phase45)
    if [ -z "$phase42" ]; then phase42=$(attr_path phase42-gcc10-source); fi
    phase44_out=${PHASE44_OUT:-"$impure_root/phase44-gcc46-cxx/out"}
    work_dir="$impure_root/phase45-gcc10"
    out=${PHASE45_OUT:-"$work_dir/out"}
    mkdir -p "$work_dir"
    cd "$work_dir"
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
    if [ -z "$phase43" ]; then phase43=$(attr_path phase43-gcc-latest-source); fi
    phase45_out=${PHASE45_OUT:-"$impure_root/phase45-gcc10/out"}
    work_dir="$impure_root/phase46-gcc-latest"
    out=${PHASE46_OUT:-"$work_dir/out"}
    mkdir -p "$work_dir"
    cd "$work_dir"
    "$repo_root/scripts/gcc-modern/bootstrap-gcc.sh" \
      "$phase43" \
      "$phase45_out" \
      "$phase39" \
      "$phase34" \
      "$cctools" \
      "$out" \
      latest \
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
