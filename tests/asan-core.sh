#!/bin/sh
# Memory check for smalltalk-polycall.
#
# valgrind cannot host GNU Smalltalk 3.2 (the VM aborts during image load
# under memcheck), so instead the SUnit suite runs with an
# AddressSanitizer-instrumented libpolycall loaded into gst (libasan
# preloaded). GNU Smalltalk copies #byteArrayOut / #string arguments into
# malloc'd memory of exactly the Smalltalk object's size, so a capacity or
# length the binding overstates is caught inside the core. A negative control
# (tests/asan-control.st passes a 4-byte buffer with capacity 128) must be
# reported, proving the instrumentation is live.
#
# Usage: tests/asan-core.sh <Polycall core source dir>
set -u
SRC=${1:?usage: tests/asan-core.sh <Polycall core source dir>}
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CC=${CC:-cc}
command -v cmake >/dev/null 2>&1 || { echo "SKIP: cmake not found"; exit 77; }
LIBASAN=$("$CC" -print-file-name=libasan.so)
[ -f "$LIBASAN" ] || { echo "SKIP: libasan not found for $CC"; exit 77; }
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

cp -a "$SRC" "$T/src" || exit 1
rm -rf "$T/src/build" "$T/src/CMakeCache.txt" "$T/src/CMakeFiles"
cmake -S "$T/src" -B "$T/build" -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=OFF \
      -DCMAKE_INSTALL_PREFIX="$T/asan" -DCMAKE_INSTALL_LIBDIR=lib \
      "-DCMAKE_C_FLAGS=-fsanitize=address -fno-omit-frame-pointer -g" \
      -DCMAKE_SHARED_LINKER_FLAGS=-fsanitize=address -DCMAKE_EXE_LINKER_FLAGS=-fsanitize=address \
      >"$T/cmake.log" 2>&1 && cmake --build "$T/build" -j4 >>"$T/cmake.log" 2>&1 \
      && cmake --install "$T/build" >>"$T/cmake.log" 2>&1 || { tail -20 "$T/cmake.log"; exit 1; }
nm -D "$T/asan/lib/libpolycall.so.1" | grep -q __asan_report || { echo "FAIL: core not instrumented"; exit 1; }
echo "== ASan core: $T/asan/lib/libpolycall.so.1 (preload $LIBASAN)"

export ASAN_OPTIONS=detect_leaks=0:handle_segv=0:allow_user_segv_handler=1
cd "$ROOT" || exit 1
POLYCALL_LIBRARY="$T/asan/lib/libpolycall.so.1" LD_LIBRARY_PATH="$T/asan/lib" LD_PRELOAD="$LIBASAN" \
  gst-sunit -v -f src/Polycall.st -f tests/PolycallTest.st \
    PolycallLibraryTest PolycallConfigTest PolycallCallTest PolycallPeerTest PolycallInteropTest >"$T/suite.log" 2>&1
suite=$?
cat "$T/suite.log"
reports=$(grep -c "ERROR: AddressSanitizer" "$T/suite.log")
echo "== suite under ASan: exit $suite, $reports AddressSanitizer reports"

POLYCALL_LIBRARY="$T/asan/lib/libpolycall.so.1" LD_LIBRARY_PATH="$T/asan/lib" LD_PRELOAD="$LIBASAN" \
  gst -q src/Polycall.st tests/asan-control.st >"$T/control.log" 2>&1
if grep -q "ERROR: AddressSanitizer: heap-buffer-overflow" "$T/control.log"; then
  echo "== negative control: ASan reported the deliberate overflow ($(grep -m1 'in polycall_' "$T/control.log" | sed 's/^ *//'))"
  control=0
else
  echo "== negative control: NOT reported -- instrumentation not effective"; cat "$T/control.log"; control=1
fi
if [ "$suite" -eq 0 ] && [ "$reports" -eq 0 ] && [ "$control" -eq 0 ]; then
  echo "== memory check (ASan core): PASS"; exit 0
fi
echo "== memory check (ASan core): FAIL"; exit 1
