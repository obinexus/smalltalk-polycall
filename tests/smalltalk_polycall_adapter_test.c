/*
 * Adapter unit test of the C shim against a MOCK core
 * (tests/polycall_ffi_mock.c): exact forwarding only. The real library is
 * tested by tests/PolycallTest.st (tests/run-real-core.sh).
 */
#include "smalltalk_polycall.h"
#include "polycall_ffi_mock.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    polycall_ffi_mock_reset();
    assert(smalltalk_polycall_run_config("smalltalk-polycallrc") == 0);
    assert(polycall_ffi_mock_calls() == 1);
    assert(polycall_ffi_mock_run_flag() == 1);
    assert(strcmp(polycall_ffi_mock_path(), "smalltalk-polycallrc") == 0);

    assert(smalltalk_polycall_run_config("__status_13__") == -13);
    assert(polycall_ffi_mock_calls() == 2);

    puts("smalltalk-polycall native adapter unit test (mock core): PASS");
    return 0;
}
