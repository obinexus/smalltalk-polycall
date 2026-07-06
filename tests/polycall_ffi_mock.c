#include "polycall_ffi_mock.h"
#include "polycall/polycall_ffi.h"

#include <stdint.h>
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

int32_t polycall_ffi_run_config(const char *config_path, int32_t run) {
    calls += 1;
    run_flag = (int)run;
    (void)snprintf(path, sizeof(path), "%s", config_path == NULL ? "" : config_path);
    return config_path != NULL && strcmp(config_path, "__status_37__") == 0 ? 37 : 0;
}
