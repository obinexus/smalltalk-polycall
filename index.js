'use strict';

const fs = require('node:fs');
const path = require('node:path');

const relativeDirectories = Object.freeze({
  src: 'src', include: 'include', dist: 'dist',
  examples: 'examples', tests: 'tests', scripts: 'scripts'
});

function walkFiles(root, current = root) {
  return fs.readdirSync(current, { withFileTypes: true })
    .sort((left, right) => left.name.localeCompare(right.name))
    .flatMap((entry) => {
      const absolute = path.join(current, entry.name);
      return entry.isDirectory() ? walkFiles(root, absolute) : [absolute];
    });
}

function indexDirectory(relative) {
  const root = path.join(__dirname, relative);
  const files = walkFiles(root);
  return Object.freeze({
    relative,
    root,
    files: Object.freeze(files),
    relativeFiles: Object.freeze(
      files.map((file) => path.relative(root, file).split(path.sep).join('/'))
    )
  });
}

const directories = Object.freeze(Object.fromEntries(
  Object.entries(relativeDirectories).map(([name, relative]) => [name, indexDirectory(relative)])
));

function resolve(directoryName, ...segments) {
  const directory = directories[directoryName];
  if (!directory) {
    throw new RangeError(`unknown smalltalk-polycall directory: ${directoryName}`);
  }
  const resolved = path.resolve(directory.root, ...segments);
  const prefix = `${directory.root}${path.sep}`;
  if (resolved !== directory.root && !resolved.startsWith(prefix)) {
    throw new RangeError(`path escapes smalltalk-polycall ${directoryName} directory`);
  }
  return resolved;
}

module.exports = Object.freeze({
  packageName: '@obinexusltd/smalltalk-polycall',
  projectRoot: __dirname,
  directories,
  resolve,
  smalltalkSource: path.join(__dirname, 'src', 'Polycall.st'),
  nativeSource: path.join(__dirname, 'src', 'smalltalk_polycall.c'),
  nativeHeader: path.join(__dirname, 'include', 'smalltalk_polycall.h'),
  testSuite: path.join(__dirname, 'tests', 'PolycallTest.st'),
  config: path.join(__dirname, 'smalltalk-polycallrc'),
  manifest: path.join(__dirname, 'polycall-binding.json')
});
