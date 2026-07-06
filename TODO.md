# TODO — smalltalk-polycall

Status: implemented GNU Smalltalk adapter and npm source distribution.

- [x] Add the generated libpolycall FFI contract and exported native shim.
- [x] Forward exactly once to `polycall_ffi_run_config(config_path, 1)`.
- [x] Add GNU Smalltalk `Polycall` and `PolycallError` APIs.
- [x] Add an example, native mock tests, and optional `gst` parse verification.
- [x] Add public npm metadata and recursive relative-directory indexes.
- [x] Add mandatory native, package, and thin-boundary prepack checks.
- [ ] Run the dialect parse/example on a host with GNU Smalltalk installed.
- [ ] Exercise the adapter against a production libpolycall 1.5 shared library.
- [ ] Add separate Pharo/Squeak adapters if those dialects are required.
- [ ] Publish `@obinexusltd/smalltalk-polycall` after npm authentication is confirmed.
