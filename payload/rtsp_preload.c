/*
 * rtsp_preload.c
 *
 * Small LD_PRELOAD payload for Tuya / SmartLife Ingenic T23 feeder firmware.
 *
 * It does not implement an RTSP server.
 * It only calls the vendor RTSP initialization function that already exists
 * in the original firmware.
 */

#define _GNU_SOURCE

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>

#ifndef RTSP_INIT_DELAY_SECONDS
#define RTSP_INIT_DELAY_SECONDS 15
#endif

typedef int (*framework_media_rtsp_init_fn)(void);

static int is_tuya_test_process(void)
{
    char exe[128];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof(exe) - 1);

    if (n <= 0) {
        return 0;
    }

    exe[n] = '\0';

    return strstr(exe, "/tuya_test") != NULL;
}

static void *rtsp_init_thread(void *arg)
{
    (void)arg;

    fprintf(stderr, "rtsp_preload: waiting before RTSP init...\n");
    sleep(RTSP_INIT_DELAY_SECONDS);

    framework_media_rtsp_init_fn rtsp_init =
        (framework_media_rtsp_init_fn)dlsym(RTLD_DEFAULT, "FRAMEWORK_MEDIA_RtspInit");

    if (!rtsp_init) {
        fprintf(stderr,
                "rtsp_preload: FRAMEWORK_MEDIA_RtspInit not found: %s\n",
                dlerror());
        return NULL;
    }

    fprintf(stderr, "rtsp_preload: calling FRAMEWORK_MEDIA_RtspInit...\n");
    rtsp_init();
    fprintf(stderr, "rtsp_preload: RTSP init call done\n");

    return NULL;
}

__attribute__((constructor))
static void rtsp_preload_init(void)
{
    pthread_t tid;

    /*
     * Safety guard:
     * If LD_PRELOAD accidentally reaches /bin/sh, busybox, app.sh, etc.,
     * do nothing. The RTSP init must run only inside the real tuya_test process.
     */
    if (!is_tuya_test_process()) {
        return;
    }

    if (pthread_create(&tid, NULL, rtsp_init_thread, NULL) == 0) {
        pthread_detach(tid);
    } else {
        fprintf(stderr, "rtsp_preload: pthread_create failed\n");
    }
}
