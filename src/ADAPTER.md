# GNU Smalltalk adapter boundary

`Polycall.st` declares the GNU Smalltalk FFI call and maps a nonzero status to
`PolycallError`. `smalltalk_polycall.c` exports a stable, one-argument C symbol
that forwards exactly once to `polycall_ffi_run_config(config_path, 1)`.

The Smalltalk layer owns type/error idioms only. The C shim owns no parser,
filesystem, networking, configuration, or runtime behavior.
