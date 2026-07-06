#ifndef SMALLTALK_POLYCALL_FFI_MOCK_H
#define SMALLTALK_POLYCALL_FFI_MOCK_H

void polycall_ffi_mock_reset(void);
int polycall_ffi_mock_calls(void);
int polycall_ffi_mock_run_flag(void);
const char *polycall_ffi_mock_path(void);

#endif
