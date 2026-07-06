#!/bin/sh
# Time the Nix-track bootstrap chain stage by stage through the GNU Hello gate.

set -eu

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
SYSTEM="${SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}"
MODE="${MODE:-rebuild}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${LOGDIR:-/private/tmp/nixpkgs-darwin-bootstrap-e2e-${SYSTEM}-${STAMP}}"
CHECK_INTERVAL_SECONDS="${CHECK_INTERVAL_SECONDS:-1200}"
ALLOW_DELETE_FAILURES="${ALLOW_DELETE_FAILURES:-0}"

case "$MODE" in
  build|fresh|rebuild) ;;
  *)
    echo "MODE must be 'build', 'fresh', or 'rebuild' (got '$MODE')" >&2
    exit 2
    ;;
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

mkdir -p "$LOGDIR/stages"

{
  echo "started=$(date -Iseconds)"
  echo "system=$SYSTEM"
  echo "mode=$MODE"
  echo "root=$ROOT"
  echo "uname=$(uname -a)"
  echo "macos=$(sw_vers -productVersion) build=$(sw_vers -buildVersion)"
  echo "cpu=$(sysctl -n machdep.cpu.brand_string)"
  echo "model=$(sysctl -n hw.model)"
  echo "mem_bytes=$(sysctl -n hw.memsize)"
  echo "ncpu=$(sysctl -n hw.ncpu) physical=$(sysctl -n hw.physicalcpu) logical=$(sysctl -n hw.logicalcpu)"
  echo "check_interval_seconds=$CHECK_INTERVAL_SECONDS"
  echo "allow_delete_failures=$ALLOW_DELETE_FAILURES"
  echo "nix=$(nix --version)"
  nix config show 2>/dev/null |
    grep -E '^(build-poll-interval|max-silent-time|timeout|substituters|trusted-substituters) =' |
    sed 's/^/nix_config_/' || true
} > "$LOGDIR/hardware.txt"

if [ -n "${STAGES_FILE:-}" ]; then
  cp "$STAGES_FILE" "$LOGDIR/stages.txt"
else
  cat > "$LOGDIR/stages.txt" <<'EOF'
hex0
hex1
hex2-0
catm
m0
macho-patcher-early
cc-arch
m2
blood-macho-0
m1-0
hex2-1
m1
hex2
kaem
m1-to-hex2
hex2-data-relocs
cc-arch-helper
elf64-to-m1
macho-patcher
m1-split
synth-inject
m2-planet
mes-source
mes-m2-probe
mes-macho-link-probe
mes-m2
mescc-macho-probe
mescc-libc-mini-probe
tinycc-mescc-m1-probe
mescc-libmescc-probe
mescc-libc-probe
mescc-libc-tcc-probe
tinycc-mescc-link-probe
tinycc-compile-probe
tinycc-self-object-probe
tinycc-elf-to-macho-probe
tinycc-self-m1-probe
tinycc-sysv-libc-probe
tinycc-self-link-candidate
tinycc-self-compile-probe
tinycc-boot1-object-probe
tinycc-boot1-link-candidate
tinycc-darwin-cc
tinycc-boot2-object-probe
tinycc-boot2-link-candidate
tinycc-boot3-object-probe
tinycc-boot3-link-candidate
bootstrap-gnumake
gnupatch
coreutils-boot
gcc46-source
gcc46-darwin-bootstrap-src
gcc46-all-gcc
gcc46-libgcc
gcc46
gcc46-cxx
gcc10-source
gcc10
gcc-latest-source
gcc-latest
bootstrap-gmp
bootstrap-mpfr
bootstrap-mpc
bootstrap-isl
gcc-latest-strict
cctools-ar
gnu-hello-gcc-latest-bootstrap
gnu-hello-gcc-latest-strict
gnu-hello-nixpkgs-gcc-latest
gnu-hello-hash-comparison
EOF
fi

printf 'index\tstage\tstarted\tended\telapsed_seconds\texit_code\tlog\n' > "$LOGDIR/stages.tsv"

if [ "$MODE" = fresh ]; then
  delete_paths="$LOGDIR/delete-paths.txt"
  delete_log="$LOGDIR/delete.log"
  : > "$delete_paths"
  : > "$delete_log"

  while IFS= read -r stage; do
    [ -n "$stage" ] || continue
    ref=".#packages.${SYSTEM}.${stage}"
    drv="$(nix path-info --derivation "$ref")"
    nix-store -q --outputs "$drv" |
    while IFS= read -r out_path; do
      [ -n "$out_path" ] || continue
      echo "$out_path"
      nix-store -q --deriver "$out_path" 2>/dev/null || true
      nix-store -q --referrers "$out_path" 2>/dev/null |
      while IFS= read -r referrer; do
        case "$referrer" in
          *.drv) echo "$referrer" ;;
        esac
      done
    done >> "$delete_paths"
    echo "$drv" >> "$delete_paths"
  done < "$LOGDIR/stages.txt"

  awk '!seen[$0]++ { lines[++n] = $0 } END { for (i = n; i >= 1; i--) print lines[i] }' "$delete_paths" |
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if nix-store --check-validity "$path" >/dev/null 2>&1; then
      {
        echo "deleting $path"
        nix-store --delete "$path"
      } >> "$delete_log" 2>&1 || {
        echo "could not delete $path" >> "$delete_log"
        if [ "$ALLOW_DELETE_FAILURES" != 1 ]; then
          echo "fresh mode could not delete $path; see $delete_log" >&2
          exit 1
        fi
      }
    else
      echo "not valid: $path" >> "$delete_log"
    fi
  done
fi

index=0
total_start="$(date +%s)"
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
  ref=".#packages.${SYSTEM}.${stage}"
  started="$(date -Iseconds)"
  start_epoch="$(date +%s)"

  echo "== [$index] $stage =="
  echo "   log: $log"

  if [ "$MODE" = rebuild ]; then
    command="nix build $ref --no-link --rebuild --print-build-logs"
    if run_logged_build "$log" "$stage" "$ref" "$started" "$start_epoch" "$command" \
      nix build "$ref" --no-link --rebuild --print-build-logs; then
      rc=0
    else
      rc=$?
    fi
  else
    command="nix build $ref --no-link --print-build-logs"
    if run_logged_build "$log" "$stage" "$ref" "$started" "$start_epoch" "$command" \
      nix build "$ref" --no-link --print-build-logs; then
      rc=0
    else
      rc=$?
    fi
  fi

  ended="$(date -Iseconds)"
  end_epoch="$(date +%s)"
  elapsed=$((end_epoch - start_epoch))
  {
    echo "ended=$ended"
    echo "exit_code=$rc"
    echo "elapsed_seconds=$elapsed"
  } >> "$log"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$index" "$stage" "$started" "$ended" "$elapsed" "$rc" "$log" >> "$LOGDIR/stages.tsv"

  if [ "$rc" -ne 0 ]; then
    echo "stage failed: $stage (exit $rc)" >&2
    echo "log: $log" >&2
    tail -n 80 "$log" >&2 || true
    exit "$rc"
  fi
done < "$LOGDIR/stages.txt"

total_end="$(date +%s)"
{
  echo "ended=$(date -Iseconds)"
  echo "total_elapsed_seconds=$((total_end - total_start))"
  echo "stage_count=$index"
} >> "$LOGDIR/hardware.txt"

echo "logs: $LOGDIR"
echo "summary: $LOGDIR/stages.tsv"
