#ifndef SMALLTALK_POLYCALL_H
#define SMALLTALK_POLYCALL_H

#include <stdint.h>

#if defined(_WIN32)
#define SMALLTALK_POLYCALL_EXPORT __declspec(dllexport)
#else
#define SMALLTALK_POLYCALL_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

SMALLTALK_POLYCALL_EXPORT int32_t smalltalk_polycall_run_config(
    const char *config_path
);

#ifdef __cplusplus
}
#endif

#endif
