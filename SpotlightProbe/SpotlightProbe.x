#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdarg.h>

static void runeLog(const char *fmt, ...) {
    if (!fmt) return;
    va_list ap;
    va_start(ap, fmt);
    char buf[2048];
    vsnprintf(buf, sizeof(buf), fmt, ap);
    va_end(ap);
    int fd = open("/var/mobile/Library/rune_spotlight5.log", O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd >= 0) {
        dprintf(fd, "%s\n", buf);
        close(fd);
    }
}

__attribute__((constructor))
static void runeSpotlightProbeInit5(void) {
    runeLog("=== Spotlight probe v5 (SearchUI classes) ===");
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    if (!classes) {
        runeLog("objc_copyClassList failed");
        return;
    }
    runeLog("Total classes: %d", count);
    for (unsigned int i = 0; i < count; i++) {
        const char *name = class_getName(classes[i]);
        if (!name) continue;
        if (strncmp(name, "SearchUI", 8) == 0) {
            runeLog("FOUND CLASS: %s", name);
            unsigned int mcount = 0;
            Method *methods = class_copyMethodList(classes[i], &mcount);
            if (methods) {
                for (unsigned int j = 0; j < mcount && j < 60; j++) {
                    runeLog("  %s", sel_getName(method_getName(methods[j])));
                }
                free(methods);
            }
        }
    }
    free(classes);
    runeLog("=== SearchUI class scan done ===");
}
