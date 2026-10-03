# @obinexusltd/smalltalk-polycall

GNU Smalltalk binding for [Polycall](https://github.com/obinexus/polycall):
the binding ABI v1 of the Polycall C library (`polycall.h`, `libpolycall`),
called directly through GNU Smalltalk C call-outs.

The adapter performs no configuration parsing, networking, or runtime work —
those stay in the core. `src/Polycall.st` declares every call-out with the
exact `polycall.h` signature (`int` → `#int`, `uint32_t` → `#uInt`,
`size_t` → `#uLong` on LP64, caller-owned buffers → `#byteArrayOut`) and maps
failures to Smalltalk exceptions.

## Dialect and requirements

- **GNU Smalltalk** 3.2 or newer (`gst`, `gst-sunit`; Ubuntu 22.04 package
  `gnu-smalltalk` 3.2.5 is what is tested). Pharo, Squeak and VisualWorks
  have different FFIs (UFFI / FFI / DLLCC); porting needs dialect-specific
  call-out declarations while the C ABI stays the same — not provided here.
- The Polycall core **1.1.0 or newer (binding ABI 1)**: `libpolycall.so.1`
  (Linux), `libpolycall.1.dylib` (macOS), `polycall.dll` / `libpolycall.dll`
  (Windows).

Tested: Linux x86_64 (GNU Smalltalk 3.2.5 on Ubuntu 22.04). GNU Smalltalk
for Windows and macOS was not available for testing; on Windows only the
optional C shim has been built and tested (MinGW-w64 UCRT64 via
`npm run build`, and MSVC).

## Smalltalk API

```smalltalk
"Load libpolycall: $POLYCALL_LIBRARY first, then the platform name. Every
 ABI v1 symbol is resolved up front and the ABI must be 1, otherwise
 PolycallLoadError is signalled (never a crash). Every API call loads
 automatically when needed."
Polycall load.
Polycall loadLibrary: '/opt/polycall/lib/libpolycall.so.1'.   "explicit path"
Polycall version.        "'1.1.0'"
Polycall abiVersion.     "1"

"Configuration -- the documented entry points are strict (run = 1)."
Polycall runConfigStatus: 'smalltalk-polycallrc'.        "exact core status"
Polycall runConfig: 'smalltalk-polycallrc'.              "PolycallError unless 0"
Polycall runConfig: 'smalltalk-polycallrc' strict: false. "unknown keys warn"
Polycall describe: 'Polycallfile'.                       "JSON text"

"RPC to `polycall daemon start` / `polycall start` (one round trip, never retried)"
Polycall call: '127.0.0.1:8084' service: 'inventory' operation: 'get'
    input: '{"item_id":"widget-a"}' timeout: 2000.

"Peer nodes (polycall-peer/1, no broker)"
alpha := PolycallPeer open: 'alpha' bind: '127.0.0.1:0' token: token.
beta := PolycallPeer open: 'beta' bind: '127.0.0.1:0' token: token.
alpha register: 'beta' endpoint: beta endpoint.
alpha ping: 'beta' timeout: 2000.
alpha send: #[0 1 2 255] to: 'beta' id: 'm-1' timeout: 2000.
m := beta recv: 2000.          "a PolycallMessage: sender, messageId, payload (ByteArray), text"
beta cancel.                   "wakes receives blocked on beta (POLYCALL_E_CANCELLED)"
beta close.                    "a second close signals POLYCALL_E_INVALID_HANDLE"
```

`PolycallPeer` also answers `nodeId`, `unregister:`, `listJson`, `healthJson`,
`recv:capacity:` and `handle`. Payloads are `ByteArray`s (a `String` is sent
as its bytes; GNU Smalltalk source strings hold UTF-8 bytes).

### Errors

`PolycallError` (an `Error`) answers `status` (the negative `POLYCALL_E_*`
code), `statusName` (`polycall_strerror`), `detail` (`polycall_last_error`,
captured without letting another Smalltalk process run in between), `output`
(the remote error object of a failed call) and `requiredSize` (after
`POLYCALL_E_TOO_LARGE`); `messageText` combines them. `PolycallError status:`
from the original API is kept. A string containing a NUL character cannot
cross the C ABI unchanged and is refused (`POLYCALL_E_INVALID_ARGUMENT`).
`PolycallLoadError` reports an unusable library and names it.

### Blocking and concurrency — honest limits of GNU Smalltalk

GNU Smalltalk runs every Smalltalk process on one OS thread, and a C call-out
blocks that thread until it returns. Consequently:

- `recv:` blocks **the whole VM** (all Smalltalk processes) for up to its
  timeout. Use short timeouts, or `recv: 0` to poll.
- `cancel` / `close` cannot wake a blocked `recv:` from another *Smalltalk*
  process (none can run). They do wake it from another OS thread — the tests
  prove this with a native helper thread (`tests/fixtures/st_waker.c`).
- Calls from several Smalltalk processes are safe but serialized at each
  call-out. Meanwhile the core's own threads keep serving: a peer node keeps
  receiving messages from other processes while Smalltalk is busy.

Each `PolycallPeer` closes its handle exactly once (`close`, or finalization
if it was never closed); nothing the library returns is ever freed by the
binding.

## Optional native shim

`src/smalltalk_polycall.c` exports `smalltalk_polycall_run_config(path)`
(→ `polycall_ffi_run_config(path, 1)`) for C callers and for the original
`Polycall loadLibrary: 'dist/smalltalk_polycall'` usage (the shim links
libpolycall, so every ABI symbol resolves through it). Build it against the
core:

```bash
PKG_CONFIG_PATH=/opt/polycall/lib/pkgconfig npm run build      # pkg-config, or:
POLYCALL_LIB_DIR=/opt/polycall/lib npm run build                # + POLYCALL_INCLUDE_DIR if not ../include/polycall
```

```powershell
$env:POLYCALL_LIB_DIR = 'C:\path\to\polycall\lib'   # libpolycall.dll.a (MinGW)
npm run build                                       # dist/smalltalk_polycall.dll
```

Run the included example from the project root:

```bash
npm run build && gst -q src/Polycall.st examples/run.st
```

## Install the npm source package

```bash
npm install @obinexusltd/smalltalk-polycall
```

The CommonJS entry point indexes the source distribution without executing it:

```js
const smalltalkPolycall = require('@obinexusltd/smalltalk-polycall');
console.log(smalltalkPolycall.directories.src.relativeFiles);
console.log(smalltalkPolycall.resolve('examples', 'run.st'));
```

## Verification

```bash
npm test          # shim adapter unit test (mock core), package/source audits, gst parse
                  # (missing gst or core headers print SKIP, not PASS)
npm run test:real # REAL core: SUnit suite, loader errors, example (tests/run-real-core.sh)
```

`tests/run-real-core.sh` needs gst, gst-sunit, a C compiler, `pkg-config
polycall` and the `polycall` CLI; it exits 77 (SKIP) when one is missing. With
`POLYCALL_CORE_SRC=<core source>` it also runs the AddressSanitizer check
(`tests/asan-core.sh`). See [tests/TESTS.md](tests/TESTS.md).

Author: Nnamdi Michael Okpala <okpalan@protonmail.com>

License: MIT
