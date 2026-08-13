#!/usr/bin/env bash
# Interleaved A/B timing of the GCC 4.6 C++ backend-object reuse optimization.

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
source "$ROOT/scripts/benchmark-lib.sh"
benchmark_lock_power_mode
trap benchmark_stop_monitor EXIT
RUNS="${RUNS:-3}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-$((RUNS * 3))}"
SYSTEM="${SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}"
FLAKE_REF="${FLAKE_REF:-.}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${LOGDIR:-/private/tmp/nixpkgs-darwin-bootstrap-gcc46-reuse-ab-$STAMP}"
NIX_CORES="${NIX_CORES:-$(sysctl -n hw.ncpu)}"
NIX_EXTRA_PLATFORM="${NIX_EXTRA_PLATFORM:-x86_64-darwin}"
NIX_PRINT_BUILD_LOGS="${NIX_PRINT_BUILD_LOGS:-0}"

case "$RUNS" in
  ''|*[!0-9]*|0) echo "RUNS must be a positive integer" >&2; exit 2 ;;
esac
case "$MAX_ATTEMPTS" in
  ''|*[!0-9]*|0) echo "MAX_ATTEMPTS must be a positive integer" >&2; exit 2 ;;
esac
[ "$MAX_ATTEMPTS" -ge "$RUNS" ] || { echo "MAX_ATTEMPTS must be at least RUNS" >&2; exit 2; }
case "$NIX_PRINT_BUILD_LOGS" in
  0) nix_log_args=() ;;
  1) nix_log_args=(--print-build-logs) ;;
  *) echo "NIX_PRINT_BUILD_LOGS must be 0 or 1" >&2; exit 2 ;;
esac

mkdir -p "$LOGDIR/logs" "$LOGDIR/correctness"
benchmark_record_harness_files "$LOGDIR/harness-files.tsv" \
  "$ROOT/scripts/benchmark-lib.sh" \
  "$ROOT/scripts/time-gcc46-reuse-ab.sh" \
  "$ROOT/scripts/summarize-timings.py" \
  "$ROOT/scripts/summarize-ab.py" \
  "$ROOT/scripts/summarize-process-snapshots.py"

case "$FLAKE_REF" in
  .) GET_FLAKE_REF="$ROOT" ;;
  /*|*:* ) GET_FLAKE_REF="$FLAKE_REF" ;;
  *) GET_FLAKE_REF="$ROOT/$FLAKE_REF" ;;
esac

reuse_expr="
let
  flake = builtins.getFlake \"$GET_FLAKE_REF\";
  package = flake.packages.\"$SYSTEM\".\"gcc46-cxx\";
in package.overrideAttrs (old: {
  name = old.name + \"-experimental-object-reuse\";
  GCC46_CXX_REUSE_ALL_GCC_OBJECTS = \"1\";
})
"

common_args=(
  "${nix_log_args[@]}"
  --no-link
  --option sandbox true
  --option substitute false
  --option extra-platforms "$NIX_EXTRA_PLATFORM"
  --option max-jobs 1
  --option cores "$NIX_CORES"
)

build_variant() {
  local variant="$1"
  local rebuild="$2"
  local log="$3"
  local rebuild_args=()
  if [[ "$rebuild" == 1 ]]; then
    rebuild_args=(--rebuild)
  fi
  if [[ "$variant" == reuse ]]; then
    /usr/bin/time -l nix build --impure --expr "$reuse_expr" \
      "${common_args[@]}" "${rebuild_args[@]}" > "$log" 2>&1
  else
    /usr/bin/time -l nix build \
      "${FLAKE_REF}#packages.${SYSTEM}.gcc46-cxx" \
      "${common_args[@]}" "${rebuild_args[@]}" > "$log" 2>&1
  fi
}

variant_output() {
  local variant="$1"
  if [[ "$variant" == reuse ]]; then
    nix path-info --impure --expr "$reuse_expr"
  else
    nix path-info "${FLAKE_REF}#packages.${SYSTEM}.gcc46-cxx"
  fi
}

variant_drv() {
  local variant="$1"
  if [[ "$variant" == reuse ]]; then
    nix path-info --derivation --impure --expr "$reuse_expr"
  else
    nix path-info --derivation "${FLAKE_REF}#packages.${SYSTEM}.gcc46-cxx"
  fi
}

export_variant_log() {
  local variant="$1"
  local destination="$2"
  nix log "$(variant_drv "$variant")" > "$destination" 2>&1 || true
}

{
  echo "started=$(date -Iseconds)"
  echo "commit=$(git -C "$ROOT" rev-parse HEAD)"
  echo "describe=$(git -C "$ROOT" describe --always --dirty)"
  echo "flake_ref=$FLAKE_REF"
  echo "system=$SYSTEM"
  echo "runs_per_variant=$RUNS"
  echo "cores=$NIX_CORES"
  echo "nix_extra_platform=$NIX_EXTRA_PLATFORM"
  echo "print_build_logs=$NIX_PRINT_BUILD_LOGS"
  echo "uname=$(uname -a)"
  echo "macos=$(sw_vers -productVersion) build=$(sw_vers -buildVersion)"
  echo "cpu=$(sysctl -n machdep.cpu.brand_string)"
  echo "model=$(sysctl -n hw.model)"
  echo "mem_bytes=$(sysctl -n hw.memsize)"
  echo "active_power_mode=$(benchmark_power_mode)"
  echo "required_power_mode=${BENCHMARK_REQUIRED_POWER_MODE:-unlocked}"
  pmset -g therm 2>/dev/null | sed 's/^/thermal_/' || true
} > "$LOGDIR/environment.txt"

# Both outputs must already be valid before --rebuild can measure just the
# selected derivation.  These are warm-ups, not samples.
build_variant reuse 0 "$LOGDIR/logs/warmup-reuse.log"
export_variant_log reuse "$LOGDIR/logs/warmup-reuse.log.builder"
build_variant no-reuse 0 "$LOGDIR/logs/warmup-no-reuse.log"
export_variant_log no-reuse "$LOGDIR/logs/warmup-no-reuse.log.builder"

reuse_out="$(variant_output reuse)"
no_reuse_out="$(variant_output no-reuse)"
printf '%s\n' "$reuse_out" > "$LOGDIR/correctness/reuse-output.txt"
printf '%s\n' "$no_reuse_out" > "$LOGDIR/correctness/no-reuse-output.txt"

fixture="$LOGDIR/correctness/template.cc"
printf '%s\n' \
  'template <typename T> T mix(T x) { return x * x + T(3); }' \
  'struct Base { virtual ~Base() {} virtual int get() const = 0; };' \
  'struct Pair : Base { int x; int y; Pair(int a) : x(a), y(a + 1) {} int get() const { return x + y; } };' \
  'int evaluate(int n) { Pair p(n); Base *b = &p; return mix(p.x) + b->get(); }' \
  'double folded_cxx() { return 0x1.8p+1 * 0x1.0p+1 + 0x1.0p-2; }' \
  'int main() { return evaluate(2) == 12 && folded_cxx() == 6.25 ? 0 : 1; }' \
  > "$fixture"

c_fixture="$LOGDIR/correctness/control-flow.c"
printf '%s\n' \
  'struct Bits { unsigned a:5; unsigned b:7; };' \
  'static unsigned rotate(unsigned x, unsigned n) { return (x << (n & 31)) | (x >> ((32 - n) & 31)); }' \
  'unsigned evaluate_c(unsigned n) {' \
  '  struct Bits bits = { n & 31, (n * 3) & 127 };' \
  '  switch (n & 3) { case 0: return rotate(bits.a + bits.b, 3); case 1: return n * n; default: return n ^ 0x5a5aU; }' \
  '}' \
  'static double folded_c(void) { return 0x1.8p+1 * 0x1.0p+2 + 0x1.0p-2; }' \
  'int main(void) { return evaluate_c(1) == 1 && evaluate_c(2) == 0x5a58U && folded_c() == 12.25 ? 0 : 1; }' \
  > "$c_fixture"

for variant in reuse no-reuse; do
  if [[ "$variant" == reuse ]]; then out="$reuse_out"; else out="$no_reuse_out"; fi
  compiler="$out/bin/g++"
  c_compiler="$out/bin/gcc"
  test -x "$compiler"
  test -x "$c_compiler"
  for optimization in O0 O2 Os; do
    GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 "$compiler" "-$optimization" -S "$fixture" \
      -o "$LOGDIR/correctness/$variant-cxx-$optimization.s"
    GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 "$compiler" "-$optimization" -c "$fixture" \
      -o "$LOGDIR/correctness/$variant-cxx-$optimization.o"
    GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 "$c_compiler" "-$optimization" -S "$c_fixture" \
      -o "$LOGDIR/correctness/$variant-c-$optimization.s"
    GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 "$c_compiler" "-$optimization" -c "$c_fixture" \
      -o "$LOGDIR/correctness/$variant-c-$optimization.o"
  done
  GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 "$compiler" -O2 "$fixture" \
    -o "$LOGDIR/correctness/$variant-fixture"
  "$LOGDIR/correctness/$variant-fixture"
  GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0 "$c_compiler" -O2 "$c_fixture" \
    -o "$LOGDIR/correctness/$variant-c-fixture"
  "$LOGDIR/correctness/$variant-c-fixture"
  "$compiler" --version > "$LOGDIR/correctness/$variant-version.txt" 2>&1
  (
    cd "$out"
    find . -type f -print | LC_ALL=C sort | while IFS= read -r path; do
      sha256sum "$path"
    done
  ) > "$LOGDIR/correctness/$variant-tree-sha256.txt"
done

for language in c cxx; do
  for optimization in O0 O2 Os; do
    cmp "$LOGDIR/correctness/reuse-$language-$optimization.s" \
      "$LOGDIR/correctness/no-reuse-$language-$optimization.s"
    cmp "$LOGDIR/correctness/reuse-$language-$optimization.o" \
      "$LOGDIR/correctness/no-reuse-$language-$optimization.o"
  done
done

printf 'attempt\taccepted_pair\taccepted\torder\tstage\tstarted\tended\telapsed_seconds\texit_code\treal_seconds\tuser_seconds\tsys_seconds\tclient_max_rss_bytes\toutput_path\tnar_hash\tlog\tquality\n' \
  > "$LOGDIR/samples.tsv"
printf 'pair\torder\tstage\tstarted\tended\telapsed_seconds\texit_code\treal_seconds\tuser_seconds\tsys_seconds\tclient_max_rss_bytes\toutput_path\tnar_hash\tlog\n' \
  > "$LOGDIR/accepted-samples.tsv"

sample=0
attempt=0
accepted_pairs=0
while ((accepted_pairs < RUNS)); do
  attempt=$((attempt + 1))
  if ((attempt > MAX_ATTEMPTS)); then
    echo "only $accepted_pairs/$RUNS A/B pairs were accepted after $MAX_ATTEMPTS attempts" >&2
    exit 1
  fi
  # Keep the order balance tied to accepted-pair slots, not attempts.  A noisy
  # rejection retries the same slot and therefore cannot skew the accepted
  # accepted pairs toward whichever treatment happened to run first.
  if ((accepted_pairs % 2 == 0)); then
    order=(reuse no-reuse)
  else
    order=(no-reuse reuse)
  fi
  position=0
  pair_clean=1
  pair_rows=()
  accepted_rows=()
  for variant in "${order[@]}"; do
    position=$((position + 1))
    sample=$((sample + 1))
    log="$LOGDIR/logs/$(printf '%02d' "$sample")-$variant.log"
    benchmark_require_disk_headroom \
      "$LOGDIR/logs/$(printf '%02d' "$sample")-$variant-disk-headroom.tsv" \
      /nix/store
    benchmark_wait_for_quiet "$LOGDIR/logs/$(printf '%02d' "$sample")-$variant-quiet.tsv"
    benchmark_record_memory_state "$log.memory-before.txt"
    /bin/df -k /nix/store > "$log.disk-before.txt"
    BENCHMARK_EXPECTED_NIX_BUILD_CLIENTS=1
    benchmark_start_monitor "$LOGDIR/logs/$(printf '%02d' "$sample")-$variant-workload.tsv"
    started="$(date -Iseconds)"
    start_ns="$(date +%s%N)"
    set +e
    build_variant "$variant" 1 "$log"
    rc=$?
    end_ns="$(date +%s%N)"
    ended="$(date -Iseconds)"
    benchmark_stop_monitor
    set -e
    benchmark_record_memory_state "$log.memory-after.txt"
    /bin/df -k /nix/store > "$log.disk-after.txt"
    quality="$LOGDIR/logs/$(printf '%02d' "$sample")-$variant-quality.txt"
    if ! benchmark_assess_monitor \
      "$LOGDIR/logs/$(printf '%02d' "$sample")-$variant-workload.tsv" "$quality"; then
      pair_clean=0
    fi
    export_variant_log "$variant" "$log.builder"
    elapsed="$(awk -v start="$start_ns" -v end="$end_ns" 'BEGIN { printf "%.9f", (end - start) / 1000000000 }')"
    real="$(awk '/ real .* user .* sys/ { value=$1 } END { print value }' "$log")"
    user="$(awk '/ real .* user .* sys/ { value=$3 } END { print value }' "$log")"
    sys="$(awk '/ real .* user .* sys/ { value=$5 } END { print value }' "$log")"
    rss="$(awk '/maximum resident set size/ { value=$1 } END { print value }' "$log")"
    output_path=
    nar_hash=
    if [[ "$rc" == 0 ]]; then
      output_path="$(variant_output "$variant")"
      nar_hash="$(nix hash path "$output_path")"
    fi
    pair_rows+=("$position\t$variant\t$started\t$ended\t$elapsed\t$rc\t$real\t$user\t$sys\t$rss\t$output_path\t$nar_hash\t$log\t$quality")
    accepted_rows+=("$position\t$variant\t$started\t$ended\t$elapsed\t$rc\t$real\t$user\t$sys\t$rss\t$output_path\t$nar_hash\t$log")
    if [[ "$rc" != 0 ]]; then
      tail -n 120 "$log" >&2 || true
      exit "$rc"
    fi
  done
  accepted_pair=
  accepted_flag=0
  if ((pair_clean)); then
    accepted_pairs=$((accepted_pairs + 1))
    accepted_pair="$accepted_pairs"
    accepted_flag=1
  fi
  for row in "${pair_rows[@]}"; do
    printf '%s\t%s\t%s\t%b\n' "$attempt" "$accepted_pair" "$accepted_flag" "$row" \
      >> "$LOGDIR/samples.tsv"
  done
  if ((pair_clean)); then
    for row in "${accepted_rows[@]}"; do
      printf '%s\t%b\n' "$accepted_pairs" "$row" >> "$LOGDIR/accepted-samples.tsv"
    done
  else
    echo "A/B attempt $attempt was noisy and was rejected; retrying the pair" >&2
  fi
done

python3 "$ROOT/scripts/summarize-timings.py" \
  --input-glob "$LOGDIR/accepted-samples.tsv" \
  --output "$LOGDIR/summary.tsv" \
  --expected-samples "$RUNS"
python3 "$ROOT/scripts/summarize-ab.py" \
  --input "$LOGDIR/accepted-samples.tsv" \
  --pairs-output "$LOGDIR/paired-samples.tsv" \
  --summary-output "$LOGDIR/paired-summary.tsv" \
  --expected-pairs "$RUNS"

echo "logs: $LOGDIR"
echo "samples: $LOGDIR/samples.tsv"
echo "summary: $LOGDIR/summary.tsv"
trap - EXIT
