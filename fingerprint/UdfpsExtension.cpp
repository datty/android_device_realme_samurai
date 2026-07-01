/*
 * Copyright (C) 2020-2025 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <compositionengine/UdfpsExtension.h>

// Use whichever sde_drm header is available; provides FOD_PRESSED_LAYER_ZORDER.
#if __has_include(<display/drm/sde_drm.h>)
#include <display/drm/sde_drm.h>
#elif __has_include(<drm/sde_drm.h>)
#include <drm/sde_drm.h>
#endif

// Dim layer z-order for UDFPS on SM8150 (oppo_display / SDE controller).
// Hardcoded to match the display controller expectation on samurai.
uint32_t getUdfpsDimZOrder(uint32_t z) {
    return 0x41000005;
}

// Finger-pressed layer z-order: uses FOD_PRESSED_LAYER_ZORDER from sde_drm.h
// when available, falling back to a known-good hardcoded value.
uint32_t getUdfpsZOrder(uint32_t z, bool touched) {
#ifdef FOD_PRESSED_LAYER_ZORDER
    return touched ? z | FOD_PRESSED_LAYER_ZORDER : z;
#else
    return touched ? 0x41000033 : z;
#endif
}

uint64_t getUdfpsUsageBits(uint64_t usageBits, bool /*touched*/) {
    return usageBits;
}
