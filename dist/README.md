# Distribution notes

The npm artifact contains GNU Smalltalk and C adapter sources. The Smalltalk
classes call libpolycall directly and need nothing built. `npm run build`
optionally builds the C shim `smalltalk_polycall.{so,dylib,dll}` here, against
a Polycall core >= 1.1.0; platform-specific binaries are excluded from
publication.
