# GNU Smalltalk adapter boundary

`Polycall.st` declares a GNU Smalltalk call-out for every function of the
Polycall binding ABI v1 with its exact `polycall.h` signature, resolves all of
them up front in the loaded library (`DLD linkFile:` / `library:getFunc:`),
checks `polycall_ffi_abi_version() = 1`, and binds the call-outs to exactly
those addresses. It maps a non-zero status to `PolycallError` (status,
`polycall_strerror` name, `polycall_last_error` detail).

`smalltalk_polycall.c` is an optional, stable one-argument C symbol that
forwards exactly once to `polycall_ffi_run_config(config_path, 1)`.

The Smalltalk layer owns type/error idioms only. Neither layer owns a parser,
filesystem, networking, configuration, or runtime behavior.
