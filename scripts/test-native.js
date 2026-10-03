'use strict';

// Adapter unit test of the C shim against a MOCK core (no libpolycall is
// linked; the real <polycall.h> provides the declaration). A missing C
// compiler or missing core headers is reported as SKIP, never as PASS.

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { polycallFlags } = require('./native-flags');

const root = path.resolve(__dirname, '..');
const flags = polycallFlags();
if (!flags) {
  console.log('SKIP: native adapter unit test not run -- Polycall core headers not found '
    + '(set POLYCALL_LIB_DIR/POLYCALL_INCLUDE_DIR or PKG_CONFIG_PATH)');
  process.exit(0);
}
const build = path.join(root, 'build');
const executable = path.join(build, `smalltalk_polycall_adapter_test${process.platform === 'win32' ? '.exe' : ''}`);
fs.mkdirSync(build, { recursive: true });

const result = spawnSync(process.env.CC || 'gcc', [
  `-I${path.join(root, 'include')}`,
  `-I${path.join(root, 'tests')}`,
  ...flags.cflags,
  '-std=c11', '-Wall', '-Wextra', '-Wpedantic',
  path.join(root, 'src', 'smalltalk_polycall.c'),
  path.join(root, 'tests', 'polycall_ffi_mock.c'),
  path.join(root, 'tests', 'smalltalk_polycall_adapter_test.c'),
  '-o', executable
], { cwd: root, stdio: 'inherit' });
if (result.error && result.error.code === 'ENOENT') {
  console.log(`SKIP: native adapter unit test not run -- C compiler '${process.env.CC || 'gcc'}' not found`);
  process.exit(0);
}
if (result.error || result.status !== 0) {
  process.exit(result.status || 1);
}
const test = spawnSync(executable, [], { cwd: root, stdio: 'inherit' });
process.exit(test.error ? 1 : (test.status || 0));
