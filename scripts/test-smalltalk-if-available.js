'use strict';

// Parse (file in) the GNU Smalltalk sources when `gst` is installed. Without
// gst this prints SKIP -- it is not a pass. The real-core SUnit suite is
// tests/run-real-core.sh (npm run test:real).

const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const probe = spawnSync('gst', ['--version'], { stdio: 'ignore' });
if (probe.error || probe.status !== 0) {
  console.log('SKIP: GNU Smalltalk (gst) not found -- Smalltalk sources were not parsed');
  process.exit(0);
}

const result = spawnSync('gst', ['-q', path.join('src', 'Polycall.st')], {
  cwd: root,
  encoding: 'utf8'
});
const output = `${result.stdout || ''}${result.stderr || ''}`;
process.stdout.write(output);
if (result.error || result.status !== 0 || /error|doesNotUnderstand/i.test(output)) {
  console.error('GNU Smalltalk could not file in src/Polycall.st');
  process.exit(1);
}
console.log('smalltalk-polycall GNU Smalltalk parse check: PASS');
