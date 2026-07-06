# @obinexusltd/smalltalk-polycall

GNU Smalltalk FFI source binding for libpolycall 1.5. The package provides a
Smalltalk API and a one-function native shim:

```text
Polycall class >> runConfigStatus:
  -> smalltalk_polycall_run_config(path)
  -> polycall_ffi_run_config(path, 1)
```

The adapter performs no configuration parsing, networking, or runtime work.
Those responsibilities remain in libpolycall.

## Dialect

Smalltalk dialects do not share one FFI syntax. This implementation targets
GNU Smalltalk (`gst`) and its `<cCall:...>` declarations. Porting to Pharo,
Squeak, or VisualWorks requires a dialect-specific FFI declaration while the
native C ABI remains unchanged.

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

`src`, `include`, `generated`, `dist`, `examples`, `tests`, and `scripts` are
recursively available as absolute and package-relative paths.

## Build the native shim

Build libpolycall first, then provide its library directory:

```powershell
$env:POLYCALL_LIB_DIR = 'C:\path\to\libpolycall\lib'
$env:POLYCALL_LIB_NAME = 'polycall' # optional default
npm run build
```

The output is `dist/smalltalk_polycall.dll`, `.so`, or `.dylib` according to
the platform. Ensure the libpolycall shared library is also discoverable by the
operating system loader, or link against a compatible static library.

## Smalltalk API

```smalltalk
Polycall loadLibrary: 'dist/smalltalk_polycall'.

"Return the exact core status."
Polycall runConfigStatus: 'smalltalk-polycallrc'.

"Raise PolycallError when the status is nonzero."
Polycall runConfig: 'smalltalk-polycallrc'.
```

Run the included example from the project root:

```bash
gst -q src/Polycall.st examples/run.st
```

`PolycallError>>status` exposes the unchanged libpolycall status code.

## Verification and publishing

```bash
npm test
npm pack --dry-run
npm publish --access public
```

The mandatory suite compiles the C shim against a mock libpolycall ABI, checks
status/path forwarding, validates npm metadata and source indexes, and enforces
the thin boundary. When `gst` is installed it also parses `src/Polycall.st`;
otherwise that dialect-specific check is reported as skipped.

Author: Nnamdi Michael Okpala <okpalan@protonmail.com>

License: MIT
