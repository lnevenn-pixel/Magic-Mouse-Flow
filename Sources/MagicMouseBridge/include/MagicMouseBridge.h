#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    float x;
    float y;
} MMTPoint;

typedef struct {
    MMTPoint position;
    MMTPoint velocity;
} MMTVector;

typedef struct {
    int32_t frame;
    double timestamp;
    int32_t pathIndex;
    int32_t stage;
    int32_t fingerID;
    int32_t handID;
    MMTVector normalizedVector;
    float zTotal;
    float zPressure;
    float angle;
    float majorAxis;
    float minorAxis;
    MMTVector absoluteVector;
    int32_t field14;
    int32_t field15;
    float zDensity;
} MMTTouch;

typedef void (*MMTFrameCallback)(const MMTTouch *touches,
                                 size_t count,
                                 double timestamp,
                                 void *context);

/// Starts every external Apple multitouch device. Built-in trackpads are skipped.
bool MMTStart(MMTFrameCallback callback, void *context);
void MMTStop(void);
bool MMTIsRunning(void);

