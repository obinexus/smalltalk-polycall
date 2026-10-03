'use strict';

// Compiler/linker flags for the Polycall core, shared by build-native.js and
// test-native.js:
//   POLYCALL_LIB_DIR (+ optional POLYCALL_INCLUDE_DIR, POLYCALL_LIB_NAME), or
//   `pkg-config --cflags --libs polycall` (set PKG_CONFIG_PATH as needed).
// Answers null when neither is available.

const path = require('node:path');
const { spawnSync } = require('node:child_process');

function polycallFlags() {
  const libDir = process.env.POLYCALL_LIB_DIR;
  if (libDir) {
    const includeDir = process.env.POLYCALL_INCLUDE_DIR
      || path.join(path.resolve(libDir), '..', 'include', 'polycall');
    return {
      source: 'POLYCALL_LIB_DIR',
      cflags: [`-I${includeDir}`],
      libs: [`-L${path.resolve(libDir)}`, `-l${process.env.POLYCALL_LIB_NAME || 'polycall'}`]
    };
  }
  const run = (flag) => spawnSync(process.env.PKG_CONFIG || 'pkg-config', [flag, 'polycall'],
    { encoding: 'utf8' });
  const cflags = run('--cflags');
  const libs = run('--libs');
  if (cflags.error || cflags.status !== 0 || libs.error || libs.status !== 0) {
    return null;
  }
  const split = (text) => text.trim().split(/\s+/).filter(Boolean);
  return { source: 'pkg-config', cflags: split(cflags.stdout), libs: split(libs.stdout) };
}

module.exports = { polycallFlags };
