#!/usr/bin/env bash
# Source this file from a Darwin Nix builder before a high-exec-rate build.
#
# x86_64 bootstrap tools in the Nix store can be unsigned.  On Apple Silicon,
# every launch of such a tool asks taskgated to consult DetachedSignatures.
# On the reviewed macOS 26.3 host, a sufficiently large parallel launch storm
# on that path precipitated an XNU voucher-cache exhaustion panic; surviving
# evidence does not identify taskgated as the component retaining the earlier
# voucher values.  Ad-hoc signing a writable copy changes only Mach-O execution
# metadata; the copied program remains the exact compiler/build-tool input
# selected by the derivation.  This is a host execution-compatibility boundary,
# not a source translator or a replacement compiler.

prepare_signed_build_tool() {
  tool_name="$1"
  source_tool="$2"
  target_tool="$DARWIN_SIGNED_BUILD_TOOLS/$tool_name"

  test -x "$source_tool"
  "$DARWIN_SIGNED_COPY" -L "$source_tool" "$target_tool"
  "$DARWIN_SIGNED_CHMOD" u+w,go-w "$target_tool"
  /usr/bin/codesign --force --sign - --timestamp=none "$target_tool" >/dev/null
  /usr/bin/codesign --verify --strict "$target_tool"
}

prepare_signed_path_tool() {
  path_tool_name="$1"
  source_path_tool="$(command -v "$path_tool_name")"
  case "$source_path_tool" in
    /*) ;;
    *)
      echo "signed build-tool preparation did not resolve $path_tool_name to an executable path" >&2
      return 1
      ;;
  esac
  prepare_signed_build_tool "$path_tool_name" "$source_path_tool"
}

prepare_signed_coreutils_path_tools() {
  # Nixpkgs Coreutils is a multicall binary whose applet symlinks all resolve
  # to bin/coreutils.  Sign that exact stdenv-selected binary once, then use
  # the signed multicall binary itself to reproduce every applet name.  This
  # also covers names hidden by Bash builtins (for example test, true, printf,
  # and echo), which cannot reliably be discovered with `command -v`.
  source_coreutils_bin="${DARWIN_SIGNED_COREUTILS_BIN:-${DARWIN_SIGNED_COPY%/*}}"
  source_coreutils="$source_coreutils_bin/coreutils"
  test -x "$source_coreutils"
  prepare_signed_build_tool coreutils "$source_coreutils"

  for source_tool in "$source_coreutils_bin"/*; do
    coreutils_tool_name="${source_tool##*/}"
    test "$coreutils_tool_name" = coreutils && continue
    if ! test "$source_tool" -ef "$source_coreutils"; then
      echo "Coreutils applet $source_tool does not resolve to $source_coreutils" >&2
      return 1
    fi
    "$DARWIN_SIGNED_BUILD_TOOLS/coreutils" --coreutils-prog=ln \
      --symbolic coreutils "$DARWIN_SIGNED_BUILD_TOOLS/$coreutils_tool_name"
    test -x "$DARWIN_SIGNED_BUILD_TOOLS/$coreutils_tool_name"
  done
}

DARWIN_SIGNED_BUILD_TOOLS="${DARWIN_SIGNED_BUILD_TOOLS:-$PWD/.darwin-signed-build-tools}"
export DARWIN_SIGNED_BUILD_TOOLS
DARWIN_SIGNED_COPY="${DARWIN_SIGNED_COPY:-/bin/cp}"
DARWIN_SIGNED_CHMOD="${DARWIN_SIGNED_CHMOD:-/bin/chmod}"
DARWIN_SIGNED_MKDIR="${DARWIN_SIGNED_MKDIR:-/bin/mkdir}"
"$DARWIN_SIGNED_MKDIR" -p "$DARWIN_SIGNED_BUILD_TOOLS"

# These are the exact stdenv tools already selected for this derivation.  A
# private directory avoids mutating their immutable Nix-store inputs.
if test "${DARWIN_SIGNED_PREPARE_PATH_TOOLS:-1}" = 1; then
  for path_tool_name in \
    bash sh make sed awk gawk grep cmp
  do
    prepare_signed_path_tool "$path_tool_name"
  done
  prepare_signed_coreutils_path_tools
fi
