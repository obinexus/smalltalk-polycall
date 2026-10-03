#!/bin/sh
# smalltalk-polycall test matrix against the REAL installed Polycall core
# (GNU Smalltalk 3.2+, Linux).
#
# Prerequisites: gst + gst-sunit (Debian/Ubuntu package gnu-smalltalk), a C
# compiler, and the core installed so that
#   pkg-config --cflags --libs polycall   works (set PKG_CONFIG_PATH),
#   the `polycall` CLI is on PATH         (daemon + C peer interop tests).
# In the QA image: sh /qa/build-linux-core.sh, then
#   PATH=/opt/polycall/bin:$PATH PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig \
#   sh tests/run-real-core.sh
# Set POLYCALL_CORE_SRC=<core source dir> to add the AddressSanitizer run
# (tests/asan-core.sh). A missing prerequisite is reported as SKIP with exit
# status 77 -- never as success.
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT" || exit 1
CC=${CC:-cc}

skip() { echo "SKIP: $1"; exit 77; }
command -v gst >/dev/null 2>&1 || skip "GNU Smalltalk (gst) not found"
command -v gst-sunit >/dev/null 2>&1 || skip "gst-sunit not found (package gnu-smalltalk)"
command -v "$CC" >/dev/null 2>&1 || skip "C compiler $CC not found (needed for the test-only waker fixture)"
pkg-config --exists polycall 2>/dev/null || skip "pkg-config cannot find polycall (install the core, set PKG_CONFIG_PATH)"
command -v polycall >/dev/null 2>&1 || skip "polycall CLI not on PATH (needed for daemon and C-peer interop tests)"

LIBDIR=$(pkg-config --variable=libdir polycall)
POLYCALL_LIBRARY=${POLYCALL_LIBRARY:-$LIBDIR/libpolycall.so.1}
export POLYCALL_LIBRARY
echo "== $(gst --version | head -1); compiler: $($CC --version | head -1)"
echo "== core: $(polycall --version) via pkg-config $(pkg-config --modversion polycall); POLYCALL_LIBRARY=$POLYCALL_LIBRARY"
FAIL=0
run() { echo "== $*"; "$@" || { echo "FAILED: $*"; FAIL=1; }; }

mkdir -p build dist
# test-only native waker (wakes a blocked receive from a native thread)
run "$CC" -shared -fPIC -Wall -Wextra tests/fixtures/st_waker.c $(pkg-config --cflags --libs polycall) -lpthread \
    -o build/libst_waker.so
POLYCALL_ST_WAKER=$ROOT/build/libst_waker.so
export POLYCALL_ST_WAKER
# the optional shim, built exactly like `npm run build` does
run "$CC" -shared -fPIC -Iinclude $(pkg-config --cflags polycall) -std=c11 -Wall -Wextra -Wpedantic \
    src/smalltalk_polycall.c $(pkg-config --libs polycall) -o dist/smalltalk_polycall.so
# adapter unit test of the shim against the MOCK core
run "$CC" -Iinclude -Itests $(pkg-config --cflags polycall) -std=c11 -Wall -Wextra -Wpedantic \
    src/smalltalk_polycall.c tests/polycall_ffi_mock.c tests/smalltalk_polycall_adapter_test.c \
    -o build/smalltalk_polycall_adapter_test
run build/smalltalk_polycall_adapter_test

# the SUnit suite against the real core
run gst-sunit -v -f src/Polycall.st -f tests/PolycallTest.st \
    PolycallLibraryTest PolycallConfigTest PolycallCallTest PolycallPeerTest PolycallInteropTest
# loader rules and errors, and the documented dist/smalltalk_polycall example
run sh tests/loader-errors.sh "$LIBDIR" "$ROOT/dist"
if [ -n "${POLYCALL_CORE_SRC:-}" ]; then
  run sh tests/asan-core.sh "$POLYCALL_CORE_SRC"
else
  echo "SKIP: AddressSanitizer run (set POLYCALL_CORE_SRC to the core source dir)"
fi

[ "$FAIL" -eq 0 ] && echo "== smalltalk-polycall real-core matrix: PASS" || echo "== smalltalk-polycall real-core matrix: FAIL"
exit "$FAIL"
