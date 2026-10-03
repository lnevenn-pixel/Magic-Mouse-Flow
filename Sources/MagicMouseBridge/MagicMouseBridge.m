#import "MagicMouseBridge.h"
#import <CoreFoundation/CoreFoundation.h>
#import <dispatch/dispatch.h>
#import <dlfcn.h>
#import <stdlib.h>
#import <string.h>

typedef void *MTDeviceRef;
typedef void (*MTFrameCallbackFunction)(MTDeviceRef, MMTTouch *, size_t, double, size_t, void *);
typedef CFArrayRef (*CreateListFn)(void);
typedef void (*RegisterFn)(MTDeviceRef, MTFrameCallbackFunction, void *);
typedef int32_t (*StartFn)(MTDeviceRef, int32_t);
typedef void (*StopFn)(MTDeviceRef);
typedef bool (*IsBuiltInFn)(MTDeviceRef);

static void *frameworkHandle;
static StopFn stopDevice;
static CFMutableArrayRef devices;
static MMTFrameCallback clientCallback;
static void *clientContext;
static bool running;

static void frameCallback(MTDeviceRef device,
                          MMTTouch *touches,
                          size_t count,
                          double timestamp,
                          size_t frame,
                          void *context) {
    (void)device; (void)frame; (void)context;
    if (!clientCallback) return;

    MMTTouch *copy = NULL;
    if (count > 0 && touches) {
        copy = malloc(count * sizeof(MMTTouch));
        if (!copy) return;
        memcpy(copy, touches, count * sizeof(MMTTouch));
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (clientCallback) clientCallback(copy, count, timestamp, clientContext);
        free(copy);
    });
}

bool MMTStart(MMTFrameCallback callback, void *context) {
    if (running) return true;
    frameworkHandle = dlopen(
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        RTLD_NOW | RTLD_GLOBAL
    );
    if (!frameworkHandle) return false;

    CreateListFn createList = (CreateListFn)dlsym(frameworkHandle, "MTDeviceCreateList");
    RegisterFn registerFrame = (RegisterFn)dlsym(frameworkHandle, "MTRegisterContactFrameCallbackWithRefcon");
    StartFn startDevice = (StartFn)dlsym(frameworkHandle, "MTDeviceStart");
    stopDevice = (StopFn)dlsym(frameworkHandle, "MTDeviceStop");
    IsBuiltInFn isBuiltIn = (IsBuiltInFn)dlsym(frameworkHandle, "MTDeviceIsBuiltIn");
    if (!createList || !registerFrame || !startDevice) {
        dlclose(frameworkHandle); frameworkHandle = NULL;
        return false;
    }

    CFArrayRef list = createList();
    if (!list) return false;
    devices = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    clientCallback = callback;
    clientContext = context;

    CFIndex count = CFArrayGetCount(list);
    for (CFIndex i = 0; i < count; i++) {
        MTDeviceRef device = (MTDeviceRef)CFArrayGetValueAtIndex(list, i);
        if (isBuiltIn && isBuiltIn(device)) continue;
        registerFrame(device, frameCallback, NULL);
        startDevice(device, 0);
        CFArrayAppendValue(devices, device);
    }
    CFRelease(list);
    running = CFArrayGetCount(devices) > 0;
    return running;
}

void MMTStop(void) {
    if (devices && stopDevice) {
        CFIndex count = CFArrayGetCount(devices);
        for (CFIndex i = 0; i < count; i++)
            stopDevice((MTDeviceRef)CFArrayGetValueAtIndex(devices, i));
    }
    if (devices) { CFRelease(devices); devices = NULL; }
    clientCallback = NULL;
    clientContext = NULL;
    running = false;
    if (frameworkHandle) { dlclose(frameworkHandle); frameworkHandle = NULL; }
}

bool MMTIsRunning(void) { return running; }

