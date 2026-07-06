'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const native = fs.readFileSync(path.join(root, 'src', 'smalltalk_polycall.c'), 'utf8');
const smalltalk = fs.readFileSync(path.join(root, 'src', 'Polycall.st'), 'utf8');

assert.equal((native.match(/polycall_ffi_run_config\s*\(/g) || []).length, 1);
assert.match(native, /polycall_ffi_run_config\s*\(\s*config_path\s*,\s*1\s*\)/);
assert.match(smalltalk, /<cCall:\s*'smalltalk_polycall_run_config'/);
assert.match(smalltalk, /returning:\s*#int/);
assert.match(smalltalk, /args:\s*#\(#string\)/);
assert.match(smalltalk, /PolycallError status:\s*status/);

for (const forbidden of ['fopen(', 'CreateFile', 'curl_', 'Socket', 'JSON']) {
  assert.ok(!native.includes(forbidden), `native shim must not contain ${forbidden}`);
}

console.log('smalltalk-polycall thin-adapter source test: PASS');
