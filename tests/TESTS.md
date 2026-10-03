# Tests

| Command | What it runs | Core |
| --- | --- | --- |
| `node scripts/test-native.js` | `smalltalk_polycall_adapter_test.c`: exact forwarding of the C shim against `polycall_ffi_mock.c` | **mock** (adapter unit test only; SKIP without a compiler/headers) |
| `node tests/package.test.js` | npm metadata, recursive directory indexes, traversal protection | none |
| `node tests/source.test.js` | thin boundary: shim includes `<polycall.h>` and forwards once; every call-out has the exact `polycall.h` signature and is resolved up front | none |
| `node scripts/test-smalltalk-if-available.js` | files in `src/Polycall.st` with `gst` (SKIP without gst) | none |
| `gst-sunit … PolycallTest.st` | SUnit, 54 tests: library/ABI, run_config, describe, `call` against a `polycall daemon` (success, errors, deadline, bounds, too-small buffer, several Smalltalk processes), two peers both directions (empty, UTF-8, binary, 1 MiB, 1 MiB + 1), registry ownership, duplicates, auth, dead peer, backpressure, double close / use after close / invalid handles, cancel/close waking a blocked receive from a native thread (`fixtures/st_waker.c`), senders in several Smalltalk processes, interop with the C CLI (`polycall peer serve/send/recv`) both ways, 12 concurrent CLI senders | real |
| `loader-errors.sh` | `loader-check.st` against the real library (explicit and by default name), a missing library, a 1.0 library without ABI v1 symbols, a library reporting ABI 2 (`fixtures/`); the documented `examples/run.st` via `dist/smalltalk_polycall` | real + fixtures |
| `asan-core.sh` | the SUnit suite with an AddressSanitizer-instrumented libpolycall, plus a negative control (`asan-control.st`) that must be reported | real (ASan build) |
| `run-real-core.sh` | all real-core checks above (exit 77 = prerequisite missing) | real |
| `npm-pack.sh` | `npm pack`, install into a clean project, load the entry point, `npm run build` in the installed copy (and the real-core suite when gst is present) | real |

valgrind cannot host GNU Smalltalk 3.2 (the VM aborts while loading its
image under memcheck), hence the ASan-core check for memory safety.
