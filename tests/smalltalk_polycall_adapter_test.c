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

    assert(smalltalk_polycall_run_config("__status_37__") == 37);
    assert(polycall_ffi_mock_calls() == 2);

    puts("smalltalk-polycall native adapter test: PASS");
    return 0;
}
