'use strict';

const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const probe = spawnSync('gst', ['--version'], { stdio: 'ignore' });
if (probe.error || probe.status !== 0) {
  console.log('GNU Smalltalk (gst) not found; skipping dialect parse test');
  process.exit(0);
}

const result = spawnSync('gst', ['-q', path.join('src', 'Polycall.st')], {
  cwd: root,
  stdio: 'inherit'
});
process.exit(result.error ? 1 : (result.status || 0));
