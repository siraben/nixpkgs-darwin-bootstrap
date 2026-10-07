#!/bin/sh
# Maintainer-only, clean unsigned/signed shell bootstrap comparisons.
# Usage: sh scripts/bench-shell-e2e.sh /absolute/new/results-directory
# BOOT_BENCH_SAMPLES defaults to one descriptive pair (not a significance
# claim). Use >=5 pairs for timing conclusions; order alternates by pair.
# Preserve all targets, full logs and an isolated committed-source worktree.
set -eu
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
results=${1:?provide a new absolute results directory}
case "$results" in /*) ;; *) echo "results directory must be absolute" >&2; exit 1 ;; esac
[ ! -e "$results" ] || { echo "results directory already exists" >&2; exit 1; }
samples=${BOOT_BENCH_SAMPLES:-1}
case "$samples" in ''|*[!0-9]*) echo "invalid sample count" >&2; exit 1 ;; esac
[ "$samples" -gt 0 ] || { echo "sample count must be positive" >&2; exit 1; }
git -C "$ROOT" diff --quiet
git -C "$ROOT" diff --cached --quiet
revision=$(git -C "$ROOT" rev-parse HEAD)
mkdir -p "$results"
printf '%s\n' "$revision" > "$results/revision"
uname -a > "$results/host.txt"
sysctl hw.model hw.memsize hw.ncpu >> "$results/host.txt"
git -C "$ROOT" worktree add --detach "$results/source" "$revision"
source_root="$results/source"
for input in hex1_AMD64_darwin.hex0 hex2_AMD64_darwin.hex0; do
  if grep -q '^version https://git-lfs.github.com/spec/v1' "$source_root/nix/hex0/sources/$input"; then
    echo "unmaterialized LFS input: $input; install git-lfs before benchmarking" >&2
    exit 1
  fi
done
# Fetch/verify before timing; every variant reads the same pinned inputs.
BOOT_TARBALL_DIR="$ROOT/tarballs" sh "$source_root/scripts/fetch-sources.sh" > "$results/fetch.log" 2>&1

# Do not inherit resume controls, external caches, make overrides or the debug
# runtime fallback. Each build gets fresh TARGET-local objects and caches.
unset BOOT_START_FROM BOOT_STOP_AFTER BOOT_METRICS_DIR MAKE GCC10_BUILD
unset TCC_DARWIN_CACHE_DIR ROOT TARGET
unset SDKROOT MACOSX_DEPLOYMENT_TARGET CONFIG_SITE CC CXX CPP CXXCPP
unset CFLAGS CXXFLAGS AR RANLIB CFLAGS_FOR_TARGET
export BOOT_ALLOW_STUB_LIBGCC=0 BOOT_METRICS=1
export PATH=/usr/bin:/bin
printf 'sample\tvariant\tbuild_exit\tgoal_exit\n' > "$results/runs.tsv"
sample=1
while [ "$sample" -le "$samples" ]; do
  if [ "$((sample % 2))" = 1 ]; then order='unsigned signed'; else order='signed unsigned'; fi
  for variant in $order; do
    # Preserve headroom for archives and linker scratch data. Never run GC or
    # delete other builds implicitly; let the operator choose what to reclaim.
    free_kib=$(df -Pk "$results" | awk 'END { print $4 }')
    [ "$free_kib" -ge 26214400 ] || { echo "less than 25 GiB free; stopping" >&2; exit 1; }
    run="$results/$sample-$variant"
    mkdir -p "$run"
    export TARGET="$run/target"
    if [ "$variant" = signed ]; then BOOT_SIGN_EXECUTABLES=1; else BOOT_SIGN_EXECUTABLES=0; fi
    export BOOT_SIGN_EXECUTABLES
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$run/started"
    pmset -g therm > "$run/thermal.txt" 2>&1
    printf 'Starting sample %s %s; full log: %s/build.log\n' "$sample" "$variant" "$run"
    set +e
    /usr/bin/time -l -o "$run/build.time" /bin/sh "$source_root/build.sh" > "$run/build.log" 2>&1
    build_rc=$?
    goal_rc=not-run
    if [ "$build_rc" -eq 0 ]; then
      /usr/bin/time -l -o "$run/goal.time" /bin/sh "$source_root/scripts/gcc10-goal-test.sh" > "$run/goal.log" 2>&1
      goal_rc=$?
    fi
    set -e
    printf '%s\t%s\t%s\t%s\n' "$sample" "$variant" "$build_rc" "$goal_rc" >> "$results/runs.tsv"
    date -u '+%Y-%m-%dT%H:%M:%SZ' > "$run/ended"
    [ "$build_rc" -eq 0 ] || exit "$build_rc"
    [ "$goal_rc" -eq 0 ] || exit "$goal_rc"
    /bin/sh "$source_root/scripts/boot-metrics-report.sh" "$TARGET/metrics" > "$run/stages.txt"
    git -C "$source_root" diff --exit-code > "$run/source.diff"
    printf 'Passed sample %s %s\n' "$sample" "$variant"
  done
  sample=$((sample + 1))
done
