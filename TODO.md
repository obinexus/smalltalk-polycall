# TODO — smalltalk-polycall

Status: GNU Smalltalk binding over the real Polycall binding ABI v1
(`polycall >= 1.1.0`), tested on Linux with GNU Smalltalk 3.2.5.

- [x] Call the real libpolycall directly with exact `polycall.h` call-out
      signatures (stub `generated/polycall_ffi.h` removed).
- [x] Loader: `POLYCALL_LIBRARY`, platform names, all symbols resolved up
      front, ABI check, `PolycallLoadError`.
- [x] `Polycall` (version/ABI, run_config strict/lenient, describe, call),
      `PolycallPeer`, `PolycallMessage`, `PolycallError` (status, name, detail).
- [x] Keep `runConfigStatus:` / `runConfig:` / `loadLibrary:` and the C shim
      `smalltalk_polycall_run_config` (built against `<polycall.h>`).
- [x] SUnit suite against the real core, loader checks, ASan-core memory check.
- [x] Public npm metadata and recursive relative-directory indexes.
- [ ] Run on GNU Smalltalk for Windows / macOS (not available for testing).
- [ ] Add separate Pharo/Squeak adapters if those dialects are required.
- [ ] Publish `@obinexusltd/smalltalk-polycall` after npm authentication is confirmed.
