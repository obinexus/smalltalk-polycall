/*
 * MOCK of polycall_ffi_run_config for the adapter unit test of the C shim
 * (tests/smalltalk_polycall_adapter_test.c). It is NOT the core: the real
 * library is exercised by tests/PolycallTest.st. The declaration comes from
 * the real <polycall.h>, so the shim is compiled against the real signature.
 */
#include "polycall_ffi_mock.h"

#include <polycall.h>

#include <stdio.h>
#include <string.h>

static int calls;
static int run_flag;
static char path[512];

void polycall_ffi_mock_reset(void) {
    calls = 0;
    run_flag = -1;
    path[0] = '\0';
}

int polycall_ffi_mock_calls(void) {
    return calls;
}

int polycall_ffi_mock_run_flag(void) {
    return run_flag;
}

const char *polycall_ffi_mock_path(void) {
    return path;
}

int polycall_ffi_run_config(const char *config_path, int run) {
    calls += 1;
    run_flag = run;
    (void)snprintf(path, sizeof(path), "%s", config_path == NULL ? "" : config_path);
    return config_path != NULL && strcmp(config_path, "__status_13__") == 0 ? POLYCALL_E_CONFIG : POLYCALL_OK;
}
