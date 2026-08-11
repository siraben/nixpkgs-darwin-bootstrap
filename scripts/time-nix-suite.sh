#!/usr/bin/env bash
# Repeat either isolated stage timings or a true end-to-end Nix build.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
source "$ROOT/scripts/benchmark-lib.sh"
RUNS="${RUNS:-5}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-$((RUNS * 3))}"
PROFILE="${PROFILE:-stages}"
SYSTEM="${SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${LOGDIR:-/private/tmp/nixpkgs-darwin-bootstrap-nix-$PROFILE-$SYSTEM-$STAMP}"

case "$RUNS" in
  ''|*[!0-9]*|0) echo "RUNS must be a positive integer" >&2; exit 2 ;;
esac
case "$MAX_ATTEMPTS" in
  ''|*[!0-9]*|0) echo "MAX_ATTEMPTS must be a positive integer" >&2; exit 2 ;;
esac
[ "$MAX_ATTEMPTS" -ge "$RUNS" ] || { echo "MAX_ATTEMPTS must be at least RUNS" >&2; exit 2; }
case "$PROFILE" in
  stages|e2e) ;;
  *) echo "PROFILE must be stages or e2e" >&2; exit 2 ;;
esac

mkdir -p "$LOGDIR/accepted"
benchmark_record_harness_files "$LOGDIR/harness-files.tsv" \
  "$ROOT/scripts/benchmark-lib.sh" \
  "$ROOT/scripts/time-nix-suite.sh" \
  "$ROOT/scripts/time-nix-e2e.sh" \
  "$ROOT/scripts/summarize-timings.py" \
  "$ROOT/scripts/summarize-process-snapshots.py" \
  "$ROOT/scripts/nix-bootstrap-stages.txt"
final_stage_file="$LOGDIR/final-stage.txt"
printf '%s\n' gnu-hello-hash-comparison > "$final_stage_file"

printf 'attempt\taccepted_sample\taccepted\tprofile\tstarted\tended\tworkload_elapsed_seconds\tharness_elapsed_seconds\texit_code\tlogdir\n' > "$LOGDIR/runs.tsv"
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
  started="$(date -Iseconds)"
  start_ns="$(date +%s%N)"
  echo "== Nix $PROFILE attempt $attempt (accepted $accepted/$RUNS) =="

  set +e
  if [ "$PROFILE" = e2e ]; then
    MODE=fresh \
    SYSTEM="$SYSTEM" \
    LOGDIR="$run_dir" \
    STAGES_FILE="$final_stage_file" \
    DELETE_STAGES_FILE="$ROOT/scripts/nix-bootstrap-stages.txt" \
    NIX_MAX_JOBS="${NIX_MAX_JOBS:-$(sysctl -n hw.ncpu)}" \
    NIX_CORES="${NIX_CORES:-$(sysctl -n hw.ncpu)}" \
      sh "$ROOT/scripts/time-nix-e2e.sh"
    rc=$?
  else
    MODE=rebuild \
    SYSTEM="$SYSTEM" \
    LOGDIR="$run_dir" \
    NIX_MAX_JOBS="${NIX_MAX_JOBS:-1}" \
    NIX_CORES="${NIX_CORES:-$(sysctl -n hw.ncpu)}" \
      sh "$ROOT/scripts/time-nix-e2e.sh"
    rc=$?
  fi
  set -e

  ended="$(date -Iseconds)"
  end_ns="$(date +%s%N)"
  harness_elapsed="$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { printf "%.9f", (end - start) / 1000000000 }')"
  workload_elapsed=
  if [ -f "$run_dir/stages.tsv" ]; then
    workload_elapsed="$(awk -F '\t' 'NR > 1 { total += $5 } END { printf "%.9f", total + 0 }' "$run_dir/stages.tsv")"
  fi
  accepted_flag=0
  accepted_sample=
  if [ "$rc" -eq 0 ]; then
    accepted=$((accepted + 1))
    accepted_flag=1
    accepted_sample="$accepted"
    cp "$run_dir/stages.tsv" "$LOGDIR/accepted/$(printf '%02d' "$accepted").tsv"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$attempt" "$accepted_sample" "$accepted_flag" "$PROFILE" "$started" "$ended" \
    "$workload_elapsed" "$harness_elapsed" "$rc" "$run_dir" >> "$LOGDIR/runs.tsv"
  if [ "$rc" -eq 75 ]; then
    echo "Nix $PROFILE attempt $attempt was noisy and was rejected; retrying" >&2
    continue
  fi
  if [ "$rc" -ne 0 ]; then
    echo "Nix $PROFILE attempt $attempt failed; evidence retained in $run_dir" >&2
    exit "$rc"
  fi
done

python3 "$ROOT/scripts/summarize-timings.py" \
  --input-glob "$LOGDIR/accepted/*.tsv" \
  --output "$LOGDIR/stage-summary.tsv" \
  --expected-samples "$RUNS" \
  --one-sample-per-input

echo "logs: $LOGDIR"
echo "run summary: $LOGDIR/runs.tsv"
echo "stage summary: $LOGDIR/stage-summary.tsv"
