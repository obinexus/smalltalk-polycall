'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const api = require('..');
const pkg = require('../package.json');

assert.equal(pkg.name, '@obinexusltd/smalltalk-polycall');
assert.equal(pkg.version, '1.0.0');
assert.equal(pkg.author, 'Nnamdi Michael Okpala <okpalan@protonmail.com>');
assert.equal(pkg.license, 'MIT');
assert.equal(pkg.publishConfig.access, 'public');
assert.equal(api.packageName, pkg.name);

const directoryKeys = {
  src: 'src', include: 'include', dist: 'dist',
  examples: 'example', tests: 'test', scripts: 'scripts'
};
for (const [apiKey, packageKey] of Object.entries(directoryKeys)) {
  const directory = api.directories[apiKey];
  assert.equal(directory.relative, pkg.directories[packageKey]);
  assert.ok(path.isAbsolute(directory.root));
  assert.ok(directory.files.length > 0, `${apiKey} must contain files`);
  directory.files.forEach((file) => assert.ok(fs.statSync(file).isFile()));
}

assert.ok(api.directories.src.relativeFiles.includes('Polycall.st'));
assert.ok(api.directories.src.relativeFiles.includes('smalltalk_polycall.c'));
assert.ok(api.directories.examples.relativeFiles.includes('run.st'));
for (const file of [api.smalltalkSource, api.nativeSource, api.nativeHeader,
  api.testSuite, api.config, api.manifest]) {
  assert.ok(fs.statSync(file).isFile(), `${file} must exist`);
}
assert.throws(() => api.resolve('src', '..', 'package.json'), RangeError);
assert.throws(() => api.resolve('unknown'), RangeError);

console.log('smalltalk-polycall npm package and relative-directory index test: PASS');
