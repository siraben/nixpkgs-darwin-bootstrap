#!/bin/sh
# Time the Nix-track bootstrap chain stage by stage through the GNU Hello gate.

set -eu

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
. "$ROOT/scripts/benchmark-lib.sh"
benchmark_lock_power_mode
SYSTEM="${SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}"
FLAKE_REF="${FLAKE_REF:-.}"
MODE="${MODE:-rebuild}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${LOGDIR:-/private/tmp/nixpkgs-darwin-bootstrap-e2e-${SYSTEM}-${STAMP}}"
CHECK_INTERVAL_SECONDS="${CHECK_INTERVAL_SECONDS:-1200}"
ALLOW_DELETE_FAILURES="${ALLOW_DELETE_FAILURES:-0}"
NIX_SANDBOX="${NIX_SANDBOX:-true}"
NIX_SUBSTITUTE="${NIX_SUBSTITUTE:-false}"
NIX_MAX_JOBS="${NIX_MAX_JOBS:-1}"
NIX_CORES="${NIX_CORES:-$(sysctl -n hw.ncpu)}"
NIX_EXTRA_PLATFORM="${NIX_EXTRA_PLATFORM:-x86_64-darwin}"
NIX_PRINT_BUILD_LOGS="${NIX_PRINT_BUILD_LOGS:-0}"

case "$MODE" in
  build|fresh|rebuild) ;;
  *)
    echo "MODE must be 'build', 'fresh', or 'rebuild' (got '$MODE')" >&2
    exit 2
    ;;
esac

case "$NIX_PRINT_BUILD_LOGS" in
  0) NIX_LOG_ARGS= ;;
  1) NIX_LOG_ARGS=--print-build-logs ;;
  *) echo "NIX_PRINT_BUILD_LOGS must be 0 or 1" >&2; exit 2 ;;
esac

case "$CHECK_INTERVAL_SECONDS" in
  ''|*[!0-9]*)
    echo "CHECK_INTERVAL_SECONDS must be a positive integer (got '$CHECK_INTERVAL_SECONDS')" >&2
    exit 2
    ;;
  0)
    echo "CHECK_INTERVAL_SECONDS must be greater than zero" >&2
    exit 2
    ;;
esac

for boolean_setting in "$NIX_SANDBOX" "$NIX_SUBSTITUTE"; do
  case "$boolean_setting" in
    true|false) ;;
    *) echo "NIX_SANDBOX and NIX_SUBSTITUTE must be true or false" >&2; exit 2 ;;
  esac
done
for numeric_setting in "$NIX_MAX_JOBS" "$NIX_CORES"; do
  case "$numeric_setting" in
    ''|*[!0-9]*|0) echo "NIX_MAX_JOBS and NIX_CORES must be positive integers" >&2; exit 2 ;;
  esac
done

mkdir -p "$LOGDIR/stages"

{
  echo "started=$(date -Iseconds)"
  echo "system=$SYSTEM"
  echo "mode=$MODE"
  echo "root=$ROOT"
  echo "flake_ref=$FLAKE_REF"
  echo "uname=$(uname -a)"
  echo "macos=$(sw_vers -productVersion) build=$(sw_vers -buildVersion)"
  echo "cpu=$(sysctl -n machdep.cpu.brand_string)"
  echo "model=$(sysctl -n hw.model)"
  echo "mem_bytes=$(sysctl -n hw.memsize)"
  echo "ncpu=$(sysctl -n hw.ncpu) physical=$(sysctl -n hw.physicalcpu) logical=$(sysctl -n hw.logicalcpu)"
  echo "check_interval_seconds=$CHECK_INTERVAL_SECONDS"
  echo "allow_delete_failures=$ALLOW_DELETE_FAILURES"
  echo "nix_sandbox=$NIX_SANDBOX"
  echo "nix_substitute=$NIX_SUBSTITUTE"
  echo "nix_max_jobs=$NIX_MAX_JOBS"
  echo "nix_cores=$NIX_CORES"
  echo "nix_extra_platform=$NIX_EXTRA_PLATFORM"
  echo "print_build_logs=$NIX_PRINT_BUILD_LOGS"
  echo "active_power_mode=$(benchmark_power_mode)"
  echo "required_power_mode=${BENCHMARK_REQUIRED_POWER_MODE:-unlocked}"
  pmset -g therm 2>/dev/null | sed 's/^/thermal_/' || true
  echo "nix=$(nix --version)"
  nix config show \
    --option sandbox "$NIX_SANDBOX" \
    --option substitute "$NIX_SUBSTITUTE" \
    --option max-jobs "$NIX_MAX_JOBS" \
    --option cores "$NIX_CORES" 2>/dev/null |
    grep -E '^(build-poll-interval|cores|max-jobs|max-silent-time|sandbox|substitute|substituters|timeout|trusted-substituters) =' |
    sed 's/^/nix_config_/' || true
} > "$LOGDIR/hardware.txt"
uptime > "$LOGDIR/uptime-before.txt"
ps -axo pid,ppid,etime,%cpu,%mem,state,command > "$LOGDIR/processes-before.txt"

DEFAULT_STAGES_FILE="$ROOT/scripts/nix-bootstrap-stages.txt"
if [ -n "${STAGES_FILE:-}" ]; then
  cp "$STAGES_FILE" "$LOGDIR/stages.txt"
else
  cp "$DEFAULT_STAGES_FILE" "$LOGDIR/stages.txt"
fi
if [ -n "${DELETE_STAGES_FILE:-}" ]; then
  cp "$DELETE_STAGES_FILE" "$LOGDIR/delete-stages.txt"
else
  cp "$LOGDIR/stages.txt" "$LOGDIR/delete-stages.txt"
fi
benchmark_record_harness_files "$LOGDIR/harness-files.tsv" \
  "$ROOT/scripts/benchmark-lib.sh" \
  "$ROOT/scripts/time-nix-e2e.sh" \
  "$LOGDIR/stages.txt" \
  "$LOGDIR/delete-stages.txt"

printf 'index\tstage\tstarted\tended\telapsed_seconds\texit_code\tclient_real_seconds\tclient_user_seconds\tclient_sys_seconds\tclient_max_rss_bytes\toutput_bytes\toutput_paths\tnar_hashes\tlog\n' > "$LOGDIR/stages.tsv"

if [ "$MODE" = fresh ]; then
  delete_output_paths="$LOGDIR/delete-output-paths.txt"
  delete_derivation_paths="$LOGDIR/delete-derivation-paths.txt"
  delete_paths="$LOGDIR/delete-paths.txt"
  delete_paths_dedup="$LOGDIR/delete-paths-dedup.txt"
  external_referrers="$LOGDIR/delete-external-referrers.txt"
  delete_log="$LOGDIR/delete.log"
  : > "$delete_output_paths"
  : > "$delete_derivation_paths"
  : > "$delete_paths"
  : > "$external_referrers"
  : > "$delete_log"

  while IFS= read -r stage; do
    [ -n "$stage" ] || continue
    ref="${FLAKE_REF}#packages.${SYSTEM}.${stage}"
    drv="$(nix path-info --derivation "$ref")"
    printf '%s\n' "$drv" >> "$delete_derivation_paths"
    nix-store -q --outputs "$drv" >> "$delete_output_paths"
  done < "$LOGDIR/delete-stages.txt"

  # Nix will not delete an output while its own .drv still refers to it.  Treat
  # the exact evaluated plans as part of the same closed deletion set, then
  # recreate them during the clean-state proof below.  They are build-plan
  # metadata, not timed compiler artifacts.
  cat "$delete_output_paths" "$delete_derivation_paths" > "$delete_paths"
  awk '!seen[$0]++' "$delete_paths" > "$delete_paths_dedup"

  # The deletion set is deliberately closed: never learn new deletion targets
  # from referrers.  An outside output or derivation referrer means this sample
  # cannot safely prove a fresh project build, so retain the evidence and fail.
  # shellcheck disable=SC2094 # Both accesses to the set are read-only.
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    nix-store -q --referrers "$path" 2>/dev/null |
    while IFS= read -r referrer; do
      [ -n "$referrer" ] || continue
      if ! grep -Fqx "$referrer" "$delete_paths_dedup"; then
        printf '%s\t%s\n' "$path" "$referrer"
      fi
    done
  done < "$delete_paths_dedup" > "$external_referrers"

  if [ -s "$external_referrers" ]; then
    echo "fresh mode found referrers outside the explicit output/derivation deletion set:" >&2
    cat "$external_referrers" >&2
    exit 1
  fi

  if ! {
    echo "batch deleting only paths enumerated in $delete_paths_dedup"
    xargs nix-store --delete < "$delete_paths_dedup"
  } > "$delete_log" 2>&1; then
    if [ "$ALLOW_DELETE_FAILURES" != 1 ]; then
      echo "fresh mode could not delete the explicit project paths; see $delete_log" >&2
      exit 1
    fi
    echo "warning: allowing explicit project path deletion failures" >&2
  fi
fi

if [ "$MODE" = fresh ]; then
  clean_state_failures="$LOGDIR/clean-state-failures.txt"
  : > "$clean_state_failures"
  while IFS= read -r stage; do
    [ -n "$stage" ] || continue
    ref="${FLAKE_REF}#packages.${SYSTEM}.${stage}"
    drv="$(nix path-info --derivation "$ref")"
    nix-store -q --outputs "$drv" |
      while IFS= read -r out_path; do
        [ -n "$out_path" ] || continue
        if nix-store --check-validity "$out_path" >/dev/null 2>&1; then
          echo "$stage	$out_path" >> "$clean_state_failures"
        fi
      done
  done < "$LOGDIR/delete-stages.txt"
  if [ -s "$clean_state_failures" ]; then
    echo "fresh-mode clean-state proof failed; outputs remain valid:" >&2
    cat "$clean_state_failures" >&2
    exit 1
  fi
fi

if [ "$MODE" = rebuild ]; then
  rebuild_invalid_outputs="$LOGDIR/rebuild-invalid-outputs.txt"
  : > "$rebuild_invalid_outputs"
  while IFS= read -r stage; do
    [ -n "$stage" ] || continue
    ref="${FLAKE_REF}#packages.${SYSTEM}.${stage}"
    drv="$(nix path-info --derivation "$ref")"
    outputs="$(nix-store -q --outputs "$drv")"
    if [ -z "$outputs" ]; then
      echo "rebuild preflight found no outputs for $stage ($drv)" >&2
      exit 1
    fi
    while IFS= read -r out_path; do
      [ -n "$out_path" ] || continue
      if ! nix-store --check-validity "$out_path" >/dev/null 2>&1; then
        printf '%s\t%s\n' "$stage" "$out_path"
      fi
    done <<EOF
$outputs
EOF
  done < "$LOGDIR/stages.txt" > "$rebuild_invalid_outputs"
  if [ -s "$rebuild_invalid_outputs" ]; then
    echo "rebuild mode requires every measured output to be valid before timing:" >&2
    cat "$rebuild_invalid_outputs" >&2
    exit 1
  fi
fi

# Fresh-mode deletion can itself create CPU and filesystem activity.  Establish
# the quiet baseline only after deletion and its clean-state proof, immediately
# before the measured build workload.
benchmark_require_disk_headroom "$LOGDIR/disk-headroom.tsv" /nix/store
benchmark_wait_for_quiet "$LOGDIR/quiet-wait.tsv"
BENCHMARK_EXPECTED_NIX_BUILD_CLIENTS=1
benchmark_start_monitor "$LOGDIR/workload-monitor.tsv"
trap benchmark_stop_monitor EXIT
trap 'benchmark_stop_monitor; exit 130' HUP INT TERM

index=0
total_start_ns="$(date +%s%N)"
run_logged_build() {
  log="$1"
  stage="$2"
  ref="$3"
  started="$4"
  start_epoch="$5"
  command="$6"
  shift 6

  set +e
  {
    echo "started=$started"
    echo "stage=$stage"
    echo "ref=$ref"
    echo "command=$command"
    /usr/bin/time -l "$@"
  } > "$log" 2>&1 &
  build_pid=$!
  next_heartbeat=$((start_epoch + CHECK_INTERVAL_SECONDS))
  while kill -0 "$build_pid" 2>/dev/null; do
    now_epoch="$(date +%s)"
    if [ "$now_epoch" -ge "$next_heartbeat" ]; then
      now="$(date -Iseconds)"
      running=$((now_epoch - start_epoch))
      msg="still running: stage=$stage elapsed_seconds=$running log=$log"
      echo "   $msg"
      echo "heartbeat=$now elapsed_seconds=$running" >> "$log"
      next_heartbeat=$((next_heartbeat + CHECK_INTERVAL_SECONDS))
    fi
    sleep_for=5
    remaining=$((next_heartbeat - now_epoch))
    if [ "$remaining" -lt "$sleep_for" ]; then
      sleep_for="$remaining"
    fi
    if [ "$sleep_for" -lt 1 ]; then
      sleep_for=1
    fi
    sleep "$sleep_for"
  done
  wait "$build_pid"
  rc=$?
  set -e
  return "$rc"
}

while IFS= read -r stage; do
  [ -n "$stage" ] || continue
  index=$((index + 1))
  safe_stage="$(printf '%s' "$stage" | tr -c 'A-Za-z0-9._-' '_')"
  log="$LOGDIR/stages/$(printf '%02d' "$index")-$safe_stage.log"
  ref="${FLAKE_REF}#packages.${SYSTEM}.${stage}"
  started="$(date -Iseconds)"
  start_epoch="$(date +%s)"
  /bin/df -k /nix/store > "$log.disk-before.txt"
  benchmark_record_memory_state "$log.memory-before.txt"
  start_ns="$(date +%s%N)"

  echo "== [$index] $stage =="
  echo "   log: $log"

  if [ "$MODE" = rebuild ]; then
    command="nix build $ref --no-link --rebuild${NIX_LOG_ARGS:+ $NIX_LOG_ARGS} --option sandbox $NIX_SANDBOX --option substitute $NIX_SUBSTITUTE --option extra-platforms $NIX_EXTRA_PLATFORM --option max-jobs $NIX_MAX_JOBS --option cores $NIX_CORES"
    if run_logged_build "$log" "$stage" "$ref" "$started" "$start_epoch" "$command" \
      nix build "$ref" --no-link --rebuild $NIX_LOG_ARGS \
        --option sandbox "$NIX_SANDBOX" \
        --option substitute "$NIX_SUBSTITUTE" \
        --option extra-platforms "$NIX_EXTRA_PLATFORM" \
        --option max-jobs "$NIX_MAX_JOBS" \
        --option cores "$NIX_CORES"; then
      rc=0
    else
      rc=$?
    fi
  else
    command="nix build $ref --no-link${NIX_LOG_ARGS:+ $NIX_LOG_ARGS} --option sandbox $NIX_SANDBOX --option substitute $NIX_SUBSTITUTE --option extra-platforms $NIX_EXTRA_PLATFORM --option max-jobs $NIX_MAX_JOBS --option cores $NIX_CORES"
    if run_logged_build "$log" "$stage" "$ref" "$started" "$start_epoch" "$command" \
      nix build "$ref" --no-link $NIX_LOG_ARGS \
        --option sandbox "$NIX_SANDBOX" \
        --option substitute "$NIX_SUBSTITUTE" \
        --option extra-platforms "$NIX_EXTRA_PLATFORM" \
        --option max-jobs "$NIX_MAX_JOBS" \
        --option cores "$NIX_CORES"; then
      rc=0
    else
      rc=$?
    fi
  fi

  ended="$(date -Iseconds)"
  end_ns="$(date +%s%N)"
  benchmark_record_memory_state "$log.memory-after.txt"
  /bin/df -k /nix/store > "$log.disk-after.txt"
  # Nix retains daemon-side builder logs.  Export the selected derivation's
  # log after stopping the clock so log transport and disk I/O do not perturb
  # the default timing measurement.
  drv="$(nix path-info --derivation "$ref" 2>/dev/null || true)"
  if [ -n "$drv" ]; then
    nix log "$drv" > "$log.builder" 2>&1 || true
  fi
  elapsed="$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { printf "%.9f", (end - start) / 1000000000 }')"
  client_real="$(awk '/ real .* user .* sys/ { value=$1 } END { print value }' "$log")"
  client_user="$(awk '/ real .* user .* sys/ { value=$3 } END { print value }' "$log")"
  client_sys="$(awk '/ real .* user .* sys/ { value=$5 } END { print value }' "$log")"
  client_rss="$(awk '/maximum resident set size/ { value=$1 } END { print value }' "$log")"
  output_paths=
  output_bytes=0
  nar_hashes=
  if [ "$rc" -eq 0 ]; then
    drv="$(nix path-info --derivation "$ref")"
    while IFS= read -r out_path; do
      [ -n "$out_path" ] || continue
      path_bytes="$(du -sk "$out_path" | awk '{ print $1 * 1024 }')"
      output_bytes=$((output_bytes + path_bytes))
      path_hash="$(nix hash path "$out_path")"
      if [ -n "$output_paths" ]; then
        output_paths="$output_paths,$out_path"
        nar_hashes="$nar_hashes,$path_hash"
      else
        output_paths="$out_path"
        nar_hashes="$path_hash"
      fi
    done <<EOF
$(nix-store -q --outputs "$drv")
EOF
  fi
  {
    echo "ended=$ended"
    echo "exit_code=$rc"
    echo "elapsed_seconds=$elapsed"
  } >> "$log"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$index" "$stage" "$started" "$ended" "$elapsed" "$rc" \
    "${client_real:-}" "${client_user:-}" "${client_sys:-}" "${client_rss:-}" \
    "$output_bytes" "$output_paths" "$nar_hashes" "$log" >> "$LOGDIR/stages.tsv"

  if [ "$rc" -ne 0 ]; then
    echo "stage failed: $stage (exit $rc)" >&2
    echo "log: $log" >&2
    tail -n 80 "$log" >&2 || true
    exit "$rc"
  fi
done < "$LOGDIR/stages.txt"

total_end_ns="$(date +%s%N)"
{
  echo "ended=$(date -Iseconds)"
  awk -v start="$total_start_ns" -v end="$total_end_ns" \
    'BEGIN { printf "total_elapsed_seconds=%.9f\n", (end - start) / 1000000000 }'
  echo "stage_count=$index"
} >> "$LOGDIR/hardware.txt"
pmset -g therm > "$LOGDIR/thermal-after.txt" 2>&1 || true
uptime > "$LOGDIR/uptime-after.txt"
ps -axo pid,ppid,etime,%cpu,%mem,state,command > "$LOGDIR/processes-after.txt"
benchmark_stop_monitor
trap - EXIT HUP INT TERM

quality_rc=0
if ! benchmark_assess_monitor "$LOGDIR/workload-monitor.tsv" "$LOGDIR/workload-quality.txt"; then
  quality_rc=75
fi

echo "logs: $LOGDIR"
echo "summary: $LOGDIR/stages.tsv"
if [ "$quality_rc" -ne 0 ]; then
  echo "measurement rejected: monitored background activity exceeded the acceptance limit" >&2
  echo "quality: $LOGDIR/workload-quality.txt" >&2
  exit "$quality_rc"
fi
