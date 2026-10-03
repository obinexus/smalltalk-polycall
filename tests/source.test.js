'use strict';

// Thin-adapter source audit: the native shim forwards once to the core, the
// Smalltalk classes declare call-outs with the exact polycall.h signatures,
// and no configuration/network logic lives in this repository.

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
// audit the code, not its comments
const native = fs.readFileSync(path.join(root, 'src', 'smalltalk_polycall.c'), 'utf8')
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/\/\/.*$/gm, '');
const smalltalk = fs.readFileSync(path.join(root, 'src', 'Polycall.st'), 'utf8');

assert.match(native, /#include <polycall\.h>/);
assert.equal((native.match(/polycall_ffi_run_config\s*\(/g) || []).length, 1);
assert.match(native, /polycall_ffi_run_config\s*\(\s*config_path\s*,\s*1\s*\)/);
assert.ok(!fs.existsSync(path.join(root, 'generated', 'polycall', 'polycall_ffi.h')),
  'the stub generated/polycall/polycall_ffi.h must not come back; use <polycall.h>');

const callouts = {
  polycall_ffi_abi_version: /returning: #int args: #\(\)/,
  polycall_ffi_version: /returning: #int args: #\(#byteArrayOut #int\)/,
  polycall_strerror: /returning: #string args: #\(#int\)/,
  polycall_last_error: /returning: #int args: #\(#byteArrayOut #uLong\)/,
  polycall_ffi_run_config: /returning: #int args: #\(#string #int\)/,
  polycall_ffi_describe: /returning: #int args: #\(#string #byteArrayOut #int\)/,
  polycall_call: /returning: #int args: #\(#string #string #string #string #uInt #byteArrayOut #uLong #byteArrayOut\)/,
  polycall_peer_open: /returning: #int args: #\(#string #string #string #byteArrayOut\)/,
  polycall_peer_close: /returning: #int args: #\(#int\)/,
  polycall_peer_endpoint: /returning: #int args: #\(#int #byteArrayOut #uLong\)/,
  polycall_peer_node_id: /returning: #int args: #\(#int #byteArrayOut #uLong\)/,
  polycall_peer_register: /returning: #int args: #\(#int #string #string\)/,
  polycall_peer_unregister: /returning: #int args: #\(#int #string\)/,
  polycall_peer_list: /returning: #int args: #\(#int #byteArrayOut #uLong #byteArrayOut\)/,
  polycall_peer_ping: /returning: #int args: #\(#int #string #uInt\)/,
  polycall_peer_send: /returning: #int args: #\(#int #string #byteArray #uLong #string #uInt\)/,
  polycall_peer_recv: /returning: #int args: #\(#int #uInt #byteArrayOut #uLong #byteArrayOut #uLong #byteArrayOut #uLong #byteArrayOut\)/,
  polycall_peer_cancel: /returning: #int args: #\(#int\)/,
  polycall_peer_health: /returning: #int args: #\(#int #byteArrayOut #uLong #byteArrayOut\)/
};
for (const [name, signature] of Object.entries(callouts)) {
  const declaration = new RegExp(`<cCall: '${name}'\\s+([^>]*)>`).exec(smalltalk);
  assert.ok(declaration, `missing call-out for ${name}`);
  assert.match(declaration[1], signature, `wrong signature for ${name}`);
  assert.ok(smalltalk.includes(`'${name}'`), `${name} must be resolved up front (abiSymbols)`);
}
assert.match(smalltalk, /Polycall class >> runConfigStatus: configPath \[/);
assert.match(smalltalk, /Polycall class >> runConfig: configPath \[/);
assert.match(smalltalk, /Polycall class >> loadLibrary: aPath \[/);
assert.match(smalltalk, /getenv: 'POLYCALL_LIBRARY'/);
assert.match(smalltalk, /Error subclass: PolycallError/);
assert.match(smalltalk, /Error subclass: PolycallLoadError/);

for (const forbidden of ['fopen(', 'CreateFile', 'curl_', 'Socket', 'JSON']) {
  assert.ok(!native.includes(forbidden), `native shim must not contain ${forbidden}`);
}
for (const forbidden of ['FileStream', 'SocketStream', 'Socket ']) {
  assert.ok(!smalltalk.includes(forbidden), `Polycall.st must not contain ${forbidden}`);
}

console.log('smalltalk-polycall thin-adapter source test: PASS');
