#!/usr/bin/env bash
# Generate a fail-closed static provenance bundle for both bootstrap tracks.
# Dynamic execution tracing is collected separately during full builds.

set -euo pipefail

TOOL_ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
ROOT="${AUDIT_ROOT:-$TOOL_ROOT}"
AUDIT_GIT_TREE="${AUDIT_GIT_TREE:-HEAD}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-/private/tmp/nixpkgs-darwin-bootstrap-audit-$STAMP}"
SYSTEM="${SYSTEM:-x86_64-darwin}"
FLAKE_REF="${FLAKE_REF:-.}"

usage() {
  cat <<'EOF'
usage: audit-bootstrap.sh [options]
  --root DIR       repository worktree to audit
  --out DIR        audit bundle destination
  --git-tree TREE  Git tree or INDEX used for committed-blob checks
  --system SYSTEM  Nix system used for stage evaluation
  --flake-ref REF  flake reference used for stage evaluation
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --out) OUTPUT_DIR="$2"; shift 2 ;;
    --git-tree) AUDIT_GIT_TREE="$2"; shift 2 ;;
    --system) SYSTEM="$2"; shift 2 ;;
    --flake-ref) FLAKE_REF="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

ROOT="$(cd -- "$ROOT" && pwd)"
tmp_dir="$(mktemp -d /private/tmp/nixpkgs-darwin-bootstrap-audit-tmp.XXXXXX)"
trap 'rm -rf -- "$tmp_dir"' EXIT

mkdir -p "$OUTPUT_DIR/derivations" "$OUTPUT_DIR/closures"
cp "$ROOT/scripts/trust-policy.tsv" "$OUTPUT_DIR/trust-policy.tsv"

failures=0
fail() {
  echo "FAIL: $*" | tee -a "$OUTPUT_DIR/failures.txt" >&2
  failures=$((failures + 1))
}

{
  echo "started=$(date -Iseconds)"
  echo "commit=$(git -C "$ROOT" rev-parse HEAD)"
  echo "describe=$(git -C "$ROOT" describe --always --dirty)"
  echo "system=$SYSTEM"
  echo "flake_ref=$FLAKE_REF"
  echo "audit_root=$ROOT"
  echo "audit_git_tree=$AUDIT_GIT_TREE"
  echo "uname=$(uname -a)"
  echo "macos=$(sw_vers -productVersion) build=$(sw_vers -buildVersion)"
  echo "nix=$(nix --version)"
  echo "cpu=$(sysctl -n machdep.cpu.brand_string)"
  echo "model=$(sysctl -n hw.model)"
  echo "mem_bytes=$(sysctl -n hw.memsize)"
} > "$OUTPUT_DIR/environment.txt"
git -C "$ROOT" status --short > "$OUTPUT_DIR/git-status.txt"

printf 'path\tbytes\tsha256\tfile_type\n' > "$OUTPUT_DIR/seeds.tsv"
for seed in "$ROOT"/seed/*; do
  [ -f "$seed" ] || continue
  bytes="$(/usr/bin/stat -f %z "$seed")"
  sha="$(shasum -a 256 "$seed" | awk '{ print $1 }')"
  type="$(/usr/bin/file -b "$seed" | tr '\t' ' ')"
  printf '%s\t%s\t%s\t%s\n' "${seed#"$ROOT/"}" "$bytes" "$sha" "$type" >> "$OUTPUT_DIR/seeds.tsv"
done

amd64_seed="$ROOT/seed/hex0-amd64-darwin"
amd64_source="$ROOT/nix/hex0/hex0-amd64-darwin.hex0"
[ "$(/usr/bin/stat -f %z "$amd64_seed")" -eq 4096 ] || fail "amd64 seed is not exactly 4096 bytes"
"$amd64_seed" "$amd64_source" "$tmp_dir/hex0-self" || fail "amd64 seed could not assemble its committed source"
cmp "$amd64_seed" "$tmp_dir/hex0-self" || fail "amd64 seed is not byte-identical to its self-assembled source"
otool -hv "$amd64_seed" > "$OUTPUT_DIR/seed-macho-header.txt"
otool -l "$amd64_seed" > "$OUTPUT_DIR/seed-load-commands.txt"

: > "$OUTPUT_DIR/lfs-pointers.txt"
if rg -l '^version https://git-lfs.github.com/spec/' "$ROOT/nix/hex0/sources" >> "$OUTPUT_DIR/lfs-pointers.txt"; then
  fail "Git LFS pointer files are present in the materialized stage0 worktree"
fi

# Nix's git flake fetcher imports Git blobs, not Git LFS-smudged worktree
# content.  Audit the committed representation independently so a locally
# materialized checkout cannot hide an unusable clean-source bootstrap.
: > "$OUTPUT_DIR/git-blob-lfs-pointers.txt"
while IFS= read -r tracked; do
  case "$tracked" in
    nix/hex0/sources/*)
      if [ "$AUDIT_GIT_TREE" = INDEX ]; then
        first_line="$(git -C "$ROOT" show ":$tracked" | sed -n '1p')"
      else
        first_line="$(git -C "$ROOT" show "$AUDIT_GIT_TREE:$tracked" | sed -n '1p')"
      fi
      if [ "$first_line" = 'version https://git-lfs.github.com/spec/v1' ]; then
        echo "$tracked" >> "$OUTPUT_DIR/git-blob-lfs-pointers.txt"
      fi
      ;;
  esac
done <<EOF
$(git -C "$ROOT" ls-files nix/hex0/sources)
EOF
if [ -s "$OUTPUT_DIR/git-blob-lfs-pointers.txt" ]; then
  fail "committed stage0 Git blobs are LFS pointers and fail through a clean git flake source"
fi

if [ -d "$ROOT/tarballs" ]; then
  if ! sh "$ROOT/scripts/tarball-sha256s.sh" > "$OUTPUT_DIR/tarballs.txt" 2>&1; then
    fail "one or more shell-track tarballs failed hash verification"
  fi
else
  echo "tarballs directory absent; source fetch verification not run" > "$OUTPUT_DIR/tarballs.txt"
fi

{
  find "$ROOT"/steps "$ROOT"/scripts "$ROOT"/nix -type f \
    ! -path '*/vendor/*' \
    ! -path '*/scripts/impure/*' \
    ! -path '*/scripts/refactor/*' \
    ! -path '*/scripts/stage0/legacy/*' \
    ! -name 'audit-bootstrap.sh' \
    ! -name 'time-nix-e2e.sh' \
    ! -name 'time-nix-suite.sh' \
    ! -name 'time-shell-e2e.sh' \
    ! -name 'time-gcc46-reuse-ab.sh' \
    ! -name 'benchmark-lib.sh' \
    ! -name 'collect-gcc46-provenance.py' \
    ! -name 'summarize-ab.py' \
    ! -name 'summarize-process-snapshots.py' \
    ! -name 'summarize-system-state.py' \
    ! -name 'summarize-timings.py' \
    -print
  printf '%s\n' "$ROOT/build.sh" "$ROOT/default.nix" "$ROOT/flake.nix"
} | LC_ALL=C sort -u > "$OUTPUT_DIR/active-files.txt"

host_pattern='(/usr/bin/(cc|c\+\+|clang|gcc|as|ld|ar|ranlib|awk|perl|python3?|patch|sed)|(^|[^A-Za-z0-9_])(GCC_MODERN_HOST_(CC|CXX)|GCC46_BOOTSTRAP_(HOST_CC|MACHO_CC)|host_compiler|wrapper_host_(cc|cxx|ld))([^A-Za-z0-9_]|$))'
: > "$OUTPUT_DIR/host-tool-candidates.txt"
while IFS= read -r source; do
  rg -n --with-filename --no-heading "$host_pattern" "$source" >> "$OUTPUT_DIR/host-tool-candidates.txt" || true
done < "$OUTPUT_DIR/active-files.txt"

source_transform_pattern='(perl .*-[0-9]*p|python[0-9]* .*patch|awk .*(:ELF_data|:HEX2_data|symbol)|sed -i|patch -p|GNUPATCH)'
: > "$OUTPUT_DIR/semantic-transform-candidates.txt"
while IFS= read -r source; do
  rg -n --with-filename --no-heading "$source_transform_pattern" "$source" >> "$OUTPUT_DIR/semantic-transform-candidates.txt" || true
done < "$OUTPUT_DIR/active-files.txt"

for strict_file in "$ROOT/nix/gcc-10/default.nix" "$ROOT/nix/gcc-latest/default.nix" "$ROOT/nix/gcc-latest/strict.nix"; do
  rg -q 'GCC_MODERN_WRAPPER_HOST_SHORTCUTS=0' "$strict_file" || fail "$strict_file does not disable wrapper host shortcuts"
  rg -q 'GCC_MODERN_HOST_BUILD_CC=0' "$strict_file" || fail "$strict_file does not disable host build compiler use"
done
rg -q 'GCC46_BOOTSTRAP_HOST_CC_SOURCES=0' "$ROOT/nix/gcc-4.6/cxx.nix" || fail "gcc46-cxx does not forbid host compilation of source"
rg -q 'GCC46_BOOTSTRAP_HOST_CC_GENERATED=0' "$ROOT/nix/gcc-4.6/cxx.nix" || fail "gcc46-cxx does not forbid host compilation of generated source"
rg -q 'GCC46_CXX_REUSE_ALL_GCC_OBJECTS:-0' "$ROOT/nix/scripts/gcc-4.6/cxx.sh" || \
  fail "unproved cross-compiler GCC 4.6 backend-object reuse is enabled by default"
for direct_compiler in CC CXX CPP CXXCPP; do
  rg -q "^[[:space:]]+$direct_compiler=\"[^\"]*-nostdinc[^\"]*-isystem "'\$target_include' \
    "$ROOT/nix/scripts/gcc-4.6/cxx.sh" || \
    fail "gcc46-cxx direct libstdc++ $direct_compiler probes can reach compiled-in host include defaults"
done

printf 'index\tstage\tscript\tsha256\n' > "$OUTPUT_DIR/shell-stages.tsv"
index=0
for step in "$ROOT"/steps/*.sh; do
  index=$((index + 1))
  printf '%s\t%s\t%s\t%s\n' "$index" "$(basename "$step" .sh)" "${step#"$ROOT/"}" \
    "$(shasum -a 256 "$step" | awk '{ print $1 }')" >> "$OUTPUT_DIR/shell-stages.tsv"
done

printf 'stage\tderivation\toutputs_valid\tclosure_file\n' > "$OUTPUT_DIR/nix-stages.tsv"
while IFS= read -r stage; do
  [ -n "$stage" ] || continue
  ref="${FLAKE_REF}#packages.${SYSTEM}.${stage}"
  safe_stage="$(printf '%s' "$stage" | tr -c 'A-Za-z0-9._-' '_')"
  eval_stderr="$OUTPUT_DIR/derivations/$safe_stage.eval.stderr"
  if ! drv="$(cd "$ROOT" && nix path-info --derivation "$ref" 2> "$eval_stderr")"; then
    cat "$eval_stderr" >&2
    fail "could not evaluate Nix stage $stage"
    continue
  fi
  if rg -q 'without a proper context|will not have a correct store reference' "$eval_stderr"; then
    fail "Nix stage $stage contains a store reference without dependency context"
  fi
  nix derivation show "$drv" > "$OUTPUT_DIR/derivations/$safe_stage.json"
  valid=1
  while IFS= read -r output; do
    nix-store --check-validity "$output" >/dev/null 2>&1 || valid=0
  done <<EOF
$(nix-store -q --outputs "$drv")
EOF
  nix-store -qR "$drv" > "$OUTPUT_DIR/closures/$safe_stage.txt" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\n' "$stage" "$drv" "$valid" "closures/$safe_stage.txt" >> "$OUTPUT_DIR/nix-stages.tsv"
done < "$ROOT/scripts/nix-bootstrap-stages.txt"

{
  echo "completed=$(date -Iseconds)"
  echo "failure_count=$failures"
  echo "host_candidate_count=$(wc -l < "$OUTPUT_DIR/host-tool-candidates.txt" | tr -d ' ')"
  echo "semantic_transform_candidate_count=$(wc -l < "$OUTPUT_DIR/semantic-transform-candidates.txt" | tr -d ' ')"
  echo "shell_stage_count=$(($(wc -l < "$OUTPUT_DIR/shell-stages.tsv") - 1))"
  echo "nix_stage_count=$(($(wc -l < "$OUTPUT_DIR/nix-stages.tsv") - 1))"
} > "$OUTPUT_DIR/summary.txt"

echo "audit bundle: $OUTPUT_DIR"
cat "$OUTPUT_DIR/summary.txt"
if [ "$failures" -ne 0 ]; then
  exit 1
fi
