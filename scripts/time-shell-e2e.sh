#!/usr/bin/env bash
# Repeated, clean, stage-by-stage timing for the shell bootstrap track.
# This harness is not part of the bootstrap trust path; it may use host tools
# for measurement, hashing, and report generation.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
source "$ROOT/scripts/benchmark-lib.sh"
benchmark_lock_power_mode
trap benchmark_stop_monitor EXIT
RUNS="${RUNS:-3}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-$((RUNS * 3))}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${LOGDIR:-/private/tmp/nixpkgs-darwin-bootstrap-shell-e2e-$STAMP}"
TARGET_ROOT="${TARGET_ROOT:-/private/tmp/nixpkgs-darwin-bootstrap-shell-benchmark-target}"
KEEP_TARGET="${KEEP_TARGET:-0}"

case "$RUNS" in
  ''|*[!0-9]*|0)
    echo "RUNS must be a positive integer (got '$RUNS')" >&2
    exit 2
    ;;
esac
case "$MAX_ATTEMPTS" in
  ''|*[!0-9]*|0) echo "MAX_ATTEMPTS must be a positive integer" >&2; exit 2 ;;
esac
[ "$MAX_ATTEMPTS" -ge "$RUNS" ] || { echo "MAX_ATTEMPTS must be at least RUNS" >&2; exit 2; }
case "$KEEP_TARGET" in
  0|1) ;;
  *) echo "KEEP_TARGET must be 0 or 1 (got '$KEEP_TARGET')" >&2; exit 2 ;;
esac
case "$TARGET_ROOT" in
  /private/tmp/nixpkgs-darwin-bootstrap-shell-*) ;;
  *)
    echo "TARGET_ROOT must be a dedicated /private/tmp/nixpkgs-darwin-bootstrap-shell-* path" >&2
    exit 2
    ;;
esac

mkdir -p "$LOGDIR/accepted"
benchmark_record_harness_files "$LOGDIR/harness-files.tsv" \
  "$ROOT/scripts/benchmark-lib.sh" \
  "$ROOT/scripts/time-shell-e2e.sh" \
  "$ROOT/scripts/summarize-timings.py" \
  "$ROOT/scripts/summarize-process-snapshots.py" \
  "$ROOT/build.sh" \
  "$ROOT/scripts/fetch-sources.sh" \
  "$ROOT/scripts/tarball-sha256s.sh" \
  "$ROOT/scripts/gcc10-goal-test.sh"
benchmark_record_input_tree "$LOGDIR/shell-input-files.tsv" \
  "$ROOT/build.sh" "$ROOT/seed" "$ROOT/sources" "$ROOT/steps" \
  "$ROOT/scripts/boot-ar" \
  "$ROOT/scripts/boot-ranlib" \
  "$ROOT/scripts/fetch-sources.sh" \
  "$ROOT/scripts/gcc10-build-libgcc.sh" \
  "$ROOT/scripts/gcc10-env.sh" \
  "$ROOT/scripts/gcc10-goal-test.sh" \
  "$ROOT/scripts/gcc10-link-cc1.sh" \
  "$ROOT/scripts/gcc10-relink-xgcc.sh" \
  "$ROOT/scripts/gxx-cpp" \
  "$ROOT/scripts/phase13-patch-assert-fail.sh" \
  "$ROOT/scripts/phase39-patch-job.sh" \
  "$ROOT/scripts/tarball-sha256s.sh" \
  "$ROOT/scripts/tcc-cpp"

record_environment() {
  local output="$1"
  {
    echo "started=$(date -Iseconds)"
    echo "commit=$(git -C "$ROOT" rev-parse HEAD)"
    echo "describe=$(git -C "$ROOT" describe --always --dirty)"
    echo "root=$ROOT"
    echo "runs=$RUNS"
    echo "target_root=$TARGET_ROOT"
    echo "uname=$(uname -a)"
    echo "macos=$(sw_vers -productVersion) build=$(sw_vers -buildVersion)"
    echo "cpu=$(sysctl -n machdep.cpu.brand_string)"
    echo "model=$(sysctl -n hw.model)"
    echo "mem_bytes=$(sysctl -n hw.memsize)"
    echo "ncpu=$(sysctl -n hw.ncpu) physical=$(sysctl -n hw.physicalcpu) logical=$(sysctl -n hw.logicalcpu)"
    echo "active_power_mode=$(benchmark_power_mode)"
    echo "required_power_mode=${BENCHMARK_REQUIRED_POWER_MODE:-unlocked}"
    pmset -g therm 2>/dev/null | sed 's/^/thermal_/' || true
  } > "$output"
}

hash_tree() {
  local tree="$1"
  local output="$2"
  (
    cd "$tree"
    find . -type f -print | LC_ALL=C sort |
      while IFS= read -r path; do
        shasum -a 256 "$path" | awk -v path="$path" '{ print $1 "  " path }'
      done
  ) > "$output"
}

manifest_tree() {
  local tree="$1"
  local output="$2"
  (
    cd "$tree"
    printf 'type\tmode_octal\tbytes\tsha256\tlink_target\tpath\n'
    find . -mindepth 1 -print | LC_ALL=C sort |
      while IFS= read -r path; do
        local type mode bytes hash link_target
        mode="$(/usr/bin/stat -f '%OLp' "$path")"
        bytes="$(/usr/bin/stat -f '%z' "$path")"
        hash=
        link_target=
        if [[ -L "$path" ]]; then
          type="symlink"
          link_target="$(readlink "$path")"
        elif [[ -f "$path" ]]; then
          type="file"
          hash="$(shasum -a 256 "$path" | awk '{ print $1 }')"
        elif [[ -d "$path" ]]; then
          type="directory"
        else
          type="other"
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
          "$type" "$mode" "$bytes" "$hash" "$link_target" "$path"
      done
  ) > "$output"
}

record_environment "$LOGDIR/environment.txt"

echo "== prefetched source verification =="
sh "$ROOT/scripts/fetch-sources.sh"
sh "$ROOT/scripts/tarball-sha256s.sh" > "$LOGDIR/tarball-sha256s.txt"

printf 'attempt\taccepted_sample\taccepted\tstarted\tended\tworkload_elapsed_seconds\tsummed_stage_seconds\tinstrumentation_gap_seconds\texit_code\tgoal_exit_code\treal_seconds\tuser_seconds\tsys_seconds\tmax_rss_bytes\ttarget_bytes\ttarget_manifest\tstage_tsv\tbuild_log\n' > "$LOGDIR/runs.tsv"

attempt=0
accepted=0
while ((accepted < RUNS)); do
  attempt=$((attempt + 1))
  if ((attempt > MAX_ATTEMPTS)); then
    echo "only $accepted/$RUNS samples were accepted after $MAX_ATTEMPTS attempts" >&2
    exit 1
  fi
  run_name="$(printf 'attempt-%02d' "$attempt")"
  run_dir="$LOGDIR/$run_name"
  mkdir -p "$run_dir"

  rm -rf -- "$TARGET_ROOT"
  mkdir -p "$TARGET_ROOT"
  if find "$TARGET_ROOT" -mindepth 1 -print -quit | grep -q .; then
    echo "clean-state proof failed for $TARGET_ROOT" >&2
    exit 1
  fi

  echo "== shell attempt $attempt (accepted $accepted/$RUNS) =="
  benchmark_require_disk_headroom "$run_dir/disk-headroom.tsv" "$TARGET_ROOT"
  benchmark_wait_for_quiet "$run_dir/quiet-wait.tsv"
  pmset -g therm > "$run_dir/thermal-before.txt" 2>&1 || true
  uptime > "$run_dir/uptime-before.txt"
  ps -axo pid,ppid,etime,%cpu,%mem,state,command > "$run_dir/processes-before.txt"
  benchmark_record_memory_state "$run_dir/memory-before-workload.txt"
  /bin/df -k "$TARGET_ROOT" > "$run_dir/disk-before-workload.txt"
  BENCHMARK_EXPECTED_NIX_BUILD_CLIENTS=0
  benchmark_start_monitor "$run_dir/workload-monitor.tsv"
  started="$(date -Iseconds)"
  start_ns="$(date +%s%N)"
  set +e
  TARGET="$TARGET_ROOT" \
  BOOT_TIMINGS_FILE="$run_dir/stages.tsv" \
  BOOT_TIMING_DIR="$run_dir/stages" \
    /usr/bin/time -l -o "$run_dir/total.time" /bin/sh "$ROOT/build.sh" \
      > "$run_dir/build.log" 2>&1
  rc=$?
  end_ns="$(date +%s%N)"
  ended="$(date -Iseconds)"
  benchmark_stop_monitor
  set -e
  benchmark_record_memory_state "$run_dir/memory-after-workload.txt"
  /bin/df -k "$TARGET_ROOT" > "$run_dir/disk-after-workload.txt"
  elapsed="$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { printf "%.9f", (end - start) / 1000000000 }')"
  summed_stage_seconds=
  instrumentation_gap_seconds=
  if [ -f "$run_dir/stages.tsv" ]; then
    summed_stage_seconds="$(awk -F '\t' 'NR > 1 { total += $5 } END { printf "%.9f", total + 0 }' "$run_dir/stages.tsv")"
    instrumentation_gap_seconds="$(awk -v total="$elapsed" -v stages="$summed_stage_seconds" 'BEGIN { printf "%.9f", total - stages }')"
  fi
  total_real="$(awk '/ real .* user .* sys/ { value=$1 } END { print value }' "$run_dir/total.time")"
  total_user="$(awk '/ real .* user .* sys/ { value=$3 } END { print value }' "$run_dir/total.time")"
  total_sys="$(awk '/ real .* user .* sys/ { value=$5 } END { print value }' "$run_dir/total.time")"
  total_rss="$(awk '/maximum resident set size/ { value=$1 } END { print value }' "$run_dir/total.time")"
  pmset -g therm > "$run_dir/thermal-after.txt" 2>&1 || true
  uptime > "$run_dir/uptime-after.txt"
  ps -axo pid,ppid,etime,%cpu,%mem,state,command > "$run_dir/processes-after.txt"
  quality_rc=0
  if ! benchmark_assess_monitor "$run_dir/workload-monitor.tsv" "$run_dir/workload-quality.txt"; then
    quality_rc=75
  fi

  goal_rc=125
  if [ "$rc" -eq 0 ]; then
    set +e
    TARGET="$TARGET_ROOT" /usr/bin/time -l -o "$run_dir/goal.time" \
      /bin/sh "$ROOT/scripts/gcc10-goal-test.sh" \
      > "$run_dir/goal.log" 2>&1
    goal_rc=$?
    set -e
    hash_tree "$TARGET_ROOT" "$run_dir/target-sha256.txt"
    manifest_tree "$TARGET_ROOT" "$run_dir/target-manifest.tsv"
    du -sk "$TARGET_ROOT" | awk '{ print $1 * 1024 }' > "$run_dir/target-bytes.txt"
  else
    echo 0 > "$run_dir/target-bytes.txt"
  fi
  target_bytes="$(cat "$run_dir/target-bytes.txt")"

  accepted_flag=0
  accepted_sample=
  if [ "$rc" -eq 0 ] && [ "$goal_rc" -eq 0 ] && [ "$quality_rc" -eq 0 ]; then
    accepted=$((accepted + 1))
    accepted_flag=1
    accepted_sample="$accepted"
    cp "$run_dir/stages.tsv" "$LOGDIR/accepted/$(printf '%02d' "$accepted").tsv"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$attempt" "$accepted_sample" "$accepted_flag" "$started" "$ended" "$elapsed" \
    "$summed_stage_seconds" "$instrumentation_gap_seconds" "$rc" "$goal_rc" \
    "$total_real" "$total_user" "$total_sys" "$total_rss" "$target_bytes" \
    "$run_dir/target-manifest.tsv" \
    "$run_dir/stages.tsv" "$run_dir/build.log" \
    >> "$LOGDIR/runs.tsv"

  if [ "$rc" -ne 0 ]; then
    echo "shell attempt $attempt failed with exit $rc; evidence retained in $run_dir" >&2
    exit "$rc"
  fi
  if [ "$goal_rc" -ne 0 ]; then
    echo "shell goal test failed with exit $goal_rc; evidence retained in $run_dir" >&2
    exit "$goal_rc"
  fi
  if [ "$quality_rc" -ne 0 ]; then
    echo "shell attempt $attempt was noisy and was rejected; retrying" >&2
  fi
done

if [ "$KEEP_TARGET" != 1 ]; then
  rm -rf -- "$TARGET_ROOT"
fi

python3 "$ROOT/scripts/summarize-timings.py" \
  --input-glob "$LOGDIR/accepted/*.tsv" \
  --output "$LOGDIR/stage-summary.tsv" \
  --expected-samples "$RUNS" \
  --one-sample-per-input

echo "logs: $LOGDIR"
echo "run summary: $LOGDIR/runs.tsv"
echo "stage summary: $LOGDIR/stage-summary.tsv"
trap - EXIT
