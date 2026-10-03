#!/bin/sh
# Packaging check: `npm pack` this source package (never published), install
# the tarball into a clean temporary project, load its CommonJS entry point,
# and build the native shim from the INSTALLED copy against the real core.
# With KEEP_INSTALL_DIR=<dir> the installed package is copied there, so the
# GNU Smalltalk suite can be run from it in an image that has gst
# (sh <dir>/tests/run-real-core.sh).
set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
command -v npm >/dev/null 2>&1 || { echo "SKIP: npm not installed"; exit 77; }
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

cd "$ROOT" || exit 1
echo "== node $(node --version), npm $(npm --version)"
echo "== npm pack (runs prepack: npm test)"
npm pack --pack-destination "$T" >"$T/pack.out" || { cat "$T/pack.out"; exit 1; }
TGZ=$(tail -1 "$T/pack.out")
echo "== packed $TGZ ($(wc -c <"$T/$TGZ") bytes)"
tar -tzf "$T/$TGZ" | sed 's/^/   /'

mkdir "$T/app" && cd "$T/app" || exit 1
npm init -y >/dev/null || exit 1
npm install --no-audit --no-fund "$T/$TGZ" || exit 1
node -e '
const assert = require("node:assert/strict");
const fs = require("node:fs");
const pkg = require("@obinexusltd/smalltalk-polycall");
const meta = require("@obinexusltd/smalltalk-polycall/package.json");
assert.equal(pkg.packageName, meta.name);
assert.ok(pkg.directories.src.relativeFiles.includes("Polycall.st"));
assert.equal(pkg.directories.generated, undefined, "the stub generated/ directory is gone");
for (const f of [pkg.smalltalkSource, pkg.nativeSource, pkg.testSuite, pkg.config]) assert.ok(fs.existsSync(f), f);
console.log("installed entry point OK:", meta.name, meta.version);
' || exit 1
cd "$T/app/node_modules/@obinexusltd/smalltalk-polycall" || exit 1
echo "== npm run build in the installed package"
npm run build || exit 1
if [ -n "${KEEP_INSTALL_DIR:-}" ]; then
  mkdir -p "$KEEP_INSTALL_DIR" && cp -a . "$KEEP_INSTALL_DIR/" && echo "== installed package copied to $KEEP_INSTALL_DIR"
fi
if command -v gst >/dev/null 2>&1; then
  echo "== real-core suite from the installed package"
  sh tests/run-real-core.sh
fi
