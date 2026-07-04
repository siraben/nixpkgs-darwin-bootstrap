#!/bin/sh
# Time the Nix-track bootstrap chain stage by stage through the GNU Hello gate.

set -eu

ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
SYSTEM="${SYSTEM:-$(nix eval --impure --raw --expr builtins.currentSystem)}"
MODE="${MODE:-rebuild}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${LOGDIR:-/private/tmp/nixpkgs-darwin-bootstrap-e2e-${SYSTEM}-${STAMP}}"

case "$MODE" in
  build|rebuild) ;;
  *)
    echo "MODE must be 'build' or 'rebuild' (got '$MODE')" >&2
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
  echo "nix=$(nix --version)"
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

index=0
total_start="$(date +%s)"
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
    set +e
    {
      echo "started=$started"
      echo "stage=$stage"
      echo "ref=$ref"
      echo "command=$command"
      /usr/bin/time -l nix build "$ref" --no-link --rebuild --print-build-logs
    } > "$log" 2>&1
    rc=$?
    set -e
  else
    command="nix build $ref --no-link --print-build-logs"
    set +e
    {
      echo "started=$started"
      echo "stage=$stage"
      echo "ref=$ref"
      echo "command=$command"
      /usr/bin/time -l nix build "$ref" --no-link --print-build-logs
    } > "$log" 2>&1
    rc=$?
    set -e
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
