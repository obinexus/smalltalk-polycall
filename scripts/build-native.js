'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const libraryDirectory = process.env.POLYCALL_LIB_DIR;
if (!libraryDirectory) {
  console.error('POLYCALL_LIB_DIR must point to the directory containing libpolycall');
  process.exit(1);
}

const suffix = process.platform === 'win32' ? '.dll' : process.platform === 'darwin' ? '.dylib' : '.so';
const output = path.join(root, 'dist', `smalltalk_polycall${suffix}`);
const args = [
  '-shared',
  `-I${path.join(root, 'include')}`,
  `-I${path.join(root, 'generated')}`,
  `-L${path.resolve(libraryDirectory)}`,
  '-std=c11', '-Wall', '-Wextra', '-Wpedantic'
];
if (process.platform !== 'win32') {
  args.push('-fPIC');
}
args.push(
  path.join(root, 'src', 'smalltalk_polycall.c'),
  `-l${process.env.POLYCALL_LIB_NAME || 'polycall'}`,
  '-o', output
);
fs.mkdirSync(path.dirname(output), { recursive: true });
const result = spawnSync(process.env.CC || 'gcc', args, { cwd: root, stdio: 'inherit' });
if (result.error || result.status !== 0) {
  process.exit(result.status || 1);
}
console.log(`built ${output}`);
