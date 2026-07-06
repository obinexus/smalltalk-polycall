'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const build = path.join(root, 'build');
const executable = path.join(build, `smalltalk_polycall_adapter_test${process.platform === 'win32' ? '.exe' : ''}`);
fs.mkdirSync(build, { recursive: true });

const result = spawnSync(process.env.CC || 'gcc', [
  `-I${path.join(root, 'include')}`,
  `-I${path.join(root, 'generated')}`,
  `-I${path.join(root, 'tests')}`,
  '-std=c11', '-Wall', '-Wextra', '-Wpedantic',
  path.join(root, 'src', 'smalltalk_polycall.c'),
  path.join(root, 'tests', 'polycall_ffi_mock.c'),
  path.join(root, 'tests', 'smalltalk_polycall_adapter_test.c'),
  '-o', executable
], { cwd: root, stdio: 'inherit' });
if (result.error || result.status !== 0) {
  process.exit(result.status || 1);
}
const test = spawnSync(executable, [], { cwd: root, stdio: 'inherit' });
process.exit(test.error ? 1 : (test.status || 0));
