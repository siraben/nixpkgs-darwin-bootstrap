#!/usr/bin/env bash
set -euo pipefail

phase35=$1
phase36=$2
phase34=$3
awk_filter=$4
out=$5
gcc_version=$6

target=x86_64-apple-darwin
gcc_lib="$out/lib/gcc/$target/$gcc_version"
gcc_exec="$out/libexec/gcc/$target/$gcc_version"
bootstrap_share="$out/share/darwin-bootstrap"

mkdir -p "$out/bin" "$gcc_lib/include" "$gcc_exec" "$bootstrap_share"
cp "$phase35/share/darwin-bootstrap/work/build/gcc/xgcc" "$gcc_exec/xgcc"
cp "$phase35/share/darwin-bootstrap/work/build/gcc/cc1" "$gcc_exec/cc1"
cp "$phase35/share/darwin-bootstrap/work/build/gcc/cpp" "$gcc_exec/cpp"
cp -R "$phase35/share/darwin-bootstrap/work/build/gcc/include/." "$gcc_lib/include/"
cp "$phase36/lib/gcc/$target/$gcc_version/libgcc.a" "$gcc_lib/libgcc.a"
cp "$phase36/lib/gcc/$target/$gcc_version/libgcov.a" "$gcc_lib/libgcov.a"

cat > "$out/bin/gcc46-bootstrap-as" <<EOF_AS
#!/usr/bin/env bash
set -euo pipefail

out=
input=
while [ "\$#" -gt 0 ]; do
  case "\$1" in
    -o) shift; out="\$1" ;;
    -arch) shift ;;
    -force_cpusubtype_ALL|-mmacosx-version-min=*|-march=*|-mtune=*|-Qy|-Qn|--32|--64) ;;
    -) input=- ;;
    *.s|*.S) input="\$1" ;;
    *) ;;
  esac
  shift || true
done

if [ -z "\$out" ]; then
  echo "gcc46-bootstrap-as: missing -o" >&2
  exit 1
fi

tmpdir="\$(mktemp -d "\${TMPDIR:-/tmp}/gcc46-bootstrap-as.XXXXXX")"
trap 'rm -rf "\$tmpdir"' EXIT HUP INT TERM
if [ -z "\$input" ] || [ "\$input" = - ]; then
  cat > "\$tmpdir/input.s"
  input="\$tmpdir/input.s"
fi
awk -f "$awk_filter" "\$input" > "\$tmpdir/filtered.s"
exec "$phase34/bin/tcc-darwin-cc" -c "\$tmpdir/filtered.s" -o "\$out"
EOF_AS
chmod +x "$out/bin/gcc46-bootstrap-as"

cat > "$out/bin/gcc" <<EOF_GCC
#!/usr/bin/env bash
set -euo pipefail

xgcc="$gcc_exec/xgcc"
gcc_exec="$gcc_exec"
assembler="$out/bin/gcc46-bootstrap-as"
linker="$phase34/bin/tcc-darwin-cc"
sysroot="$phase34/include/tcc-darwin-bootstrap"
libgcc="$gcc_lib/libgcc.a"

mode=link
out_file=
explicit_output=0
compiler_args=()
link_args=()
sources=()
asm_sources=()
objects=()

while [ "\$#" -gt 0 ]; do
  case "\$1" in
    --version|-dump*|-print*|-v)
      exec "\$xgcc" -B"\$gcc_exec/" "\$@"
      ;;
    -c)
      mode=object
      shift
      ;;
    -S)
      mode=asm
      shift
      ;;
    -E)
      exec "\$xgcc" -B"\$gcc_exec/" --sysroot="\$sysroot" -isystem "\$sysroot" "\$@"
      ;;
    -o)
      out_file="\$2"
      explicit_output=1
      shift 2
      ;;
    -o*)
      out_file="\${1#-o}"
      explicit_output=1
      shift
      ;;
    -I|-isystem|-iquote|-idirafter|-include|-D|-U|-MF|-MT|-MQ)
      compiler_args+=("\$1" "\$2")
      shift 2
      ;;
    -I*|-D*|-U*|-O*|-g*|-f*|-m*|-W*|-std=*|-ansi|-pedantic|-nostdinc)
      compiler_args+=("\$1")
      shift
      ;;
    -L|-l*|*.a)
      link_args+=("\$1")
      if [ "\$1" = -L ]; then
        link_args+=("\$2")
        shift 2
      else
        shift
      fi
      ;;
    *.c)
      sources+=("\$1")
      shift
      ;;
    *.s|*.S)
      asm_sources+=("\$1")
      shift
      ;;
    *.o)
      objects+=("\$1")
      shift
      ;;
    *)
      compiler_args+=("\$1")
      shift
      ;;
  esac
done

tmpdir="\$(mktemp -d "\${TMPDIR:-/tmp}/gcc46-bootstrap.XXXXXX")"
trap 'rm -rf "\$tmpdir"' EXIT HUP INT TERM

compile_to_asm() {
  local input="\$1"
  local asm_out="\$2"
  MACOSX_DEPLOYMENT_TARGET=10.6 "\$xgcc" -B"\$gcc_exec/" \\
    --sysroot="\$sysroot" -isystem "\$sysroot" \\
    -fno-asynchronous-unwind-tables -fno-unwind-tables \\
    "\${compiler_args[@]}" -S "\$input" -o "\$asm_out"
}

assemble_to_object() {
  local input="\$1"
  local object_out="\$2"
  "\$assembler" "\$input" -o "\$object_out"
}

if [ "\$mode" = asm ]; then
  if [ "\${#sources[@]}" -ne 1 ]; then
    echo "gcc: bootstrap -S currently expects exactly one C input" >&2
    exit 1
  fi
  if [ -z "\$out_file" ]; then
    base="\$(basename "\${sources[0]}")"
    out_file="\${base%.c}.s"
  fi
  compile_to_asm "\${sources[0]}" "\$out_file"
  exit 0
fi

if [ "\$mode" = object ]; then
  total_inputs=\$((\${#sources[@]} + \${#asm_sources[@]}))
  if [ "\$total_inputs" -ne 1 ]; then
    echo "gcc: bootstrap -c currently expects exactly one input" >&2
    exit 1
  fi
  if [ -z "\$out_file" ]; then
    if [ "\${#sources[@]}" -eq 1 ]; then
      base="\$(basename "\${sources[0]}")"
      out_file="\${base%.c}.o"
    else
      base="\$(basename "\${asm_sources[0]}")"
      out_file="\${base%.*}.o"
    fi
  fi
  if [ "\${#sources[@]}" -eq 1 ]; then
    compile_to_asm "\${sources[0]}" "\$tmpdir/input.s"
    assemble_to_object "\$tmpdir/input.s" "\$out_file"
  else
    assemble_to_object "\${asm_sources[0]}" "\$out_file"
  fi
  exit 0
fi

object_index=0
for source in "\${sources[@]}"; do
  asm_file="\$tmpdir/source-\$object_index.s"
  object_file="\$tmpdir/source-\$object_index.o"
  compile_to_asm "\$source" "\$asm_file"
  assemble_to_object "\$asm_file" "\$object_file"
  objects+=("\$object_file")
  object_index=\$((object_index + 1))
done

for source in "\${asm_sources[@]}"; do
  object_file="\$tmpdir/asm-\$object_index.o"
  assemble_to_object "\$source" "\$object_file"
  objects+=("\$object_file")
  object_index=\$((object_index + 1))
done

if [ -z "\$out_file" ]; then
  out_file=a.out
fi

exec "\$linker" "\${objects[@]}" "\${link_args[@]}" "\$libgcc" -o "\$out_file"
EOF_GCC
chmod +x "$out/bin/gcc"
ln -s gcc "$out/bin/cc"
ln -s gcc "$out/bin/gcc-4.6"

cat > smoke.c <<'C'
extern int puts(const char *);
int helper(int x) { return x + 40; }
int main(void) { puts("gcc46 bootstrap smoke"); return helper(2); }
C

"$out/bin/gcc" -S smoke.c -o "$bootstrap_share/smoke.s"
grep -q '^_main:' "$bootstrap_share/smoke.s"
"$out/bin/gcc" -c smoke.c -o smoke.o
test "$(od -An -tx1 -N4 smoke.o | tr -d ' \n')" = "7f454c46"
set +e
"$out/bin/gcc" smoke.c -o smoke > "$bootstrap_share/smoke-link.stdout" 2> "$bootstrap_share/smoke-link.stderr"
link_status=$?
set -e
test "$link_status" = 0
set +e
./smoke > "$bootstrap_share/smoke-run.stdout" 2> "$bootstrap_share/smoke-run.stderr"
smoke_status=$?
set -e
test "$smoke_status" = 42

cat > int128.c <<'C'
typedef __int128 ti;
ti product(ti x, ti y) { return x * y; }
int main(void) { return (int) product(6, 7); }
C
set +e
"$out/bin/gcc" int128.c -o int128 > "$bootstrap_share/int128-link.stdout" 2> "$bootstrap_share/int128-link.stderr"
int128_link_status=$?
set -e
test "$int128_link_status" = 0
set +e
./int128 > "$bootstrap_share/int128-run.stdout" 2> "$bootstrap_share/int128-run.stderr"
int128_status=$?
set -e
test "$int128_status" = 42

cp smoke.c smoke.o smoke int128.c int128 "$bootstrap_share/"
