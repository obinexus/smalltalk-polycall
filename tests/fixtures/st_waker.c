/*
 * Test fixture (never installed): wakes a peer receive from a NATIVE thread.
 *
 * GNU Smalltalk runs every Smalltalk process on one OS thread, and a C
 * call-out blocks that thread, so while a Smalltalk receive is blocked no
 * Smalltalk code can call cancel/close. The tests use this helper to start a
 * detached pthread that calls polycall_peer_cancel / polycall_peer_close on
 * the handle after `ms` milliseconds, which is exactly what another thread of
 * a multi-threaded host would do.
 *
 *   int st_waker_after(int32_t handle, unsigned ms, int what);  what: 0 cancel, 1 close
 */
#include <polycall.h>

#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>

typedef struct {
    int32_t handle;
    unsigned ms;
    int what;
} waker_job;

static void *waker_run(void *arg)
{
    waker_job *job = (waker_job *)arg;
    struct timespec ts;
    ts.tv_sec = (time_t)(job->ms / 1000u);
    ts.tv_nsec = (long)(job->ms % 1000u) * 1000000L;
    nanosleep(&ts, NULL);
    if (job->what == 0) polycall_peer_cancel(job->handle);
    else polycall_peer_close(job->handle);
    free(job);
    return NULL;
}

int st_waker_after(int32_t handle, unsigned ms, int what)
{
    pthread_t thread;
    waker_job *job = (waker_job *)malloc(sizeof *job);
    if (!job) return -2;
    job->handle = handle;
    job->ms = ms;
    job->what = what;
    if (pthread_create(&thread, NULL, waker_run, job) != 0) {
        free(job);
        return -18;
    }
    pthread_detach(thread);
    return 0;
}
