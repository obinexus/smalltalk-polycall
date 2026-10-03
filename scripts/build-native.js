'use strict';

// Build the optional C shim dist/smalltalk_polycall.{so,dylib,dll} against the
// real Polycall core (flags from POLYCALL_LIB_DIR or pkg-config, see
// native-flags.js). The Smalltalk classes do not need it: they call libpolycall
// directly. It exists for `Polycall loadLibrary: 'dist/smalltalk_polycall'` and
// for C callers of smalltalk_polycall_run_config().

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { polycallFlags } = require('./native-flags');

const root = path.resolve(__dirname, '..');
const flags = polycallFlags();
if (!flags) {
  console.error('cannot find the Polycall core: set POLYCALL_LIB_DIR (and POLYCALL_INCLUDE_DIR) '
    + 'or make `pkg-config polycall` work (PKG_CONFIG_PATH)');
  process.exit(1);
}

const suffix = process.platform === 'win32' ? '.dll' : process.platform === 'darwin' ? '.dylib' : '.so';
const output = path.join(root, 'dist', `smalltalk_polycall${suffix}`);
const args = [
  '-shared',
  `-I${path.join(root, 'include')}`,
  ...flags.cflags,
  '-std=c11', '-Wall', '-Wextra', '-Wpedantic'
];
if (process.platform !== 'win32') {
  args.push('-fPIC');
}
args.push(path.join(root, 'src', 'smalltalk_polycall.c'), ...flags.libs, '-o', output);
fs.mkdirSync(path.dirname(output), { recursive: true });
const result = spawnSync(process.env.CC || 'gcc', args, { cwd: root, stdio: 'inherit' });
if (result.error || result.status !== 0) {
  if (result.error) console.error(result.error.message);
  process.exit(result.status || 1);
}
console.log(`built ${output} (core flags from ${flags.source})`);
