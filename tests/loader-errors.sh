#!/bin/sh
# Loader behaviour of smalltalk-polycall (GNU Smalltalk, Linux):
#   POLYCALL_LIBRARY first, then the platform name libpolycall.so.1; every ABI
#   v1 symbol resolved up front; ABI checked; failures are PolycallLoadError.
# Runs tests/loader-check.st in separate gst processes against: the real
# library (explicit and by default name), a missing library, a 1.0-era
# library without the ABI v1 symbols, and a library reporting ABI 2; then the
# documented `Polycall loadLibrary: 'dist/smalltalk_polycall'` example.
#
# Usage: tests/loader-errors.sh <libdir of the real libpolycall> [dist dir with the shim]
set -u
LIBDIR=${1:?usage: tests/loader-errors.sh <libdir of the real libpolycall>}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CC=${CC:-cc}
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/none" "$T/old" "$T/abi2"
"$CC" -shared -fPIC -Wl,-soname,libpolycall.so.1 -o "$T/old/libpolycall.so.1" "$ROOT/tests/fixtures/fake_polycall_v10.c" || exit 1
"$CC" -shared -fPIC -Wl,-soname,libpolycall.so.1 -o "$T/abi2/libpolycall.so.1" "$ROOT/tests/fixtures/fake_polycall_abi2.c" || exit 1

# check LABEL WANT_RC PATTERN -- env...
check() {
  label=$1; want=$2; pattern=$3; shift 3
  (cd "$ROOT" && env "$@" gst -q src/Polycall.st tests/loader-check.st) >"$T/out" 2>&1
  rc=$?
  msg=$(tr '\n' ' ' <"$T/out")
  if [ "$rc" -ge 128 ]; then bad "$label: crashed (exit $rc): $msg"
  elif [ "$rc" -ne "$want" ]; then bad "$label: exit $rc (want $want): $msg"
  elif ! grep -q -- "$pattern" "$T/out"; then bad "$label: output lacks '$pattern': $msg"
  else ok "$label -> exit $rc: $msg"; fi
}

check "explicit POLYCALL_LIBRARY (real core)" 0 "binding ABI 1" \
  POLYCALL_LIBRARY="$LIBDIR/libpolycall.so.1" LD_LIBRARY_PATH="$LIBDIR"
check "default name libpolycall.so.1 via the loader path" 0 "loaded libpolycall.so.1" \
  POLYCALL_LIBRARY= LD_LIBRARY_PATH="$LIBDIR"
check "missing library (explicit path)" 1 "cannot load the Polycall library" \
  POLYCALL_LIBRARY=/nonexistent/libpolycall.so.1 LD_LIBRARY_PATH="$T/none"
check "missing library (default name, nothing in the loader path)" 1 "cannot load the Polycall library 'libpolycall.so.1'" \
  POLYCALL_LIBRARY= LD_LIBRARY_PATH="$T/none"
check "1.0 library without ABI v1 symbols" 1 "lacks binding ABI v1 symbols" \
  POLYCALL_LIBRARY="$T/old/libpolycall.so.1" LD_LIBRARY_PATH="$T/none"
check "library reporting binding ABI 2" 1 "binding ABI mismatch: .* implements binding ABI 2" \
  POLYCALL_LIBRARY="$T/abi2/libpolycall.so.1" LD_LIBRARY_PATH="$T/none"
grep -q "API call without a usable library -> PolycallLoadError" "$T/out" \
  && ok "API use after a failed load signals PolycallLoadError" \
  || bad "API use after a failed load: $(cat "$T/out")"

# the documented example: Polycall loadLibrary: 'dist/smalltalk_polycall'
DIST=${2:-$ROOT/dist}
if [ -f "$DIST/smalltalk_polycall.so" ]; then
  (cd "$ROOT" && LD_LIBRARY_PATH="$LIBDIR" POLYCALL_LIBRARY= gst -q src/Polycall.st examples/run.st) >"$T/out" 2>&1
  rc=$?
  grep -q "libpolycall status: 0" "$T/out" && [ "$rc" -eq 0 ] \
    && ok "examples/run.st via the dist/smalltalk_polycall shim: $(tr '\n' ' ' <"$T/out")" \
    || bad "examples/run.st (exit $rc): $(cat "$T/out")"
else
  printf 'SKIP  examples/run.st: %s/smalltalk_polycall.so not built\n' "$DIST"
fi

echo "--- loader-errors: $PASS passed, $FAIL failed ---"
[ "$FAIL" -eq 0 ]
