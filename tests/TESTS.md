# Tests

- `test-native.js` compiles the C shim with a mock libpolycall ABI and verifies
  exact path/run forwarding plus nonzero-status preservation.
- `package.test.js` checks npm metadata, recursive directory indexes, required
  source files, and traversal protection.
- `source.test.js` enforces the one-call native boundary and GNU Smalltalk FFI
  and error declarations.
- `test-smalltalk-if-available.js` parses `Polycall.st` when `gst` is installed.

No test duplicates libpolycall runtime or configuration behavior.
