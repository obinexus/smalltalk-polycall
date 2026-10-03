#include "smalltalk_polycall.h"

/* The core's installed public header (pkg-config --cflags polycall). */
#include <polycall.h>

/* Kept for C callers and for `Polycall loadLibrary: 'dist/smalltalk_polycall'`:
 * the exact status of polycall_ffi_run_config(config_path, 1). Because this
 * shim links libpolycall, loading it also makes every ABI v1 symbol
 * resolvable through it. */
int32_t smalltalk_polycall_run_config(const char *config_path) {
    return polycall_ffi_run_config(config_path, 1);
}
