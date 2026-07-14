# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This is the **LineageOS device tree** for the **Realme X2 Pro** (codename `samurai`, model RMX1931). It sits between the generic LineageOS platform and the device's hardware, providing:

- Hardware configuration for Qualcomm Snapdragon 855+ (msmnile/sm8150)
- Device-local HALs for fingerprint (UDFPS) and sensors subhal; shared oplus HALs for touch/vibrator/livedisplay
- Device-specific overlays, init scripts, and SELinux policies
- Build system integration for LineageOS

## Build Commands

This repo is part of a larger AOSP/LineageOS tree. All build commands are run from the root of that tree, not from this directory.

```bash
# Set up the build environment
source build/envsetup.sh

# Initialize device configuration
breakfast samurai
# or equivalently:
lunch lineage_samurai-user

# Full build
mka bacon

# Build a specific module (e.g. fingerprint HAL)
mka android.hardware.biometrics.fingerprint@2.3-service.samurai

# Build the kernel
mka dtboimage bootimage

# Extract proprietary blobs from a connected device (run from this directory)
./extract-files.sh

# Extract from a local ROM zip/directory
./extract-files.sh /path/to/rom/dump
```

There are no unit tests in this repository. Validation is done by flashing and booting.

## Repo Dependencies

This device tree depends on several other repos that must be present in the Android tree:

| Path | Purpose |
|---|---|
| `kernel/realme/sm8150` | Device kernel source (`TARGET_KERNEL_SOURCE`) |
| `vendor/realme/samurai` | Proprietary blobs extracted via `extract-files.sh` |
| `hardware/qcom-caf/common` | Common QCOM CAF hardware definitions |
| `device/qcom/sepolicy_vndr` | QCOM vendor SELinux policy base |
| `device/lineage/sepolicy` | LineageOS SELinux policy extensions |
| `packages/apps/RealmeParts` | Device-specific settings app |
| `vendor/lineage` | LineageOS common build config |

The LineageOS manifest (`.repo/local_manifests/`) must include entries for these repos; they are not automatically fetched.

## Key Directories

- **`fingerprint/`** — HIDL 2.3 fingerprint HAL with UDFPS support. Wraps the vendor goodix blob and drives `dimlayer_hbm` via `/sys/kernel/oppo_display` (syshelper AIDL + UDFPS extension for SurfaceFlinger).
- **`sensors/`** — OPLUS sensor subhal (`sensors.oplus.samurai`) loaded by AOSP multihal via `configs/sensors/hals.conf`.
- **`syshelper/`** — OPLUS system helper AIDL service; coordinates UDFPS-related display operations.
- **`als/`** — LineageOS `vendor.lineage.oplus_als` service; feeds corrected ALS data to framework auto-brightness.
- **`touch/include/`** — Gesture config for `vendor.lineage.touch-service.oplus` (soong_config INCLUDE_DIR).
- **`init/`** — `libinit_samurai` shared library loaded by init; detects device variant (Global `RMX1931L1` vs China `RMX1931CN`) and overrides build properties accordingly.
- **`sepolicy/`** — Device-specific SELinux rules on top of qcom + `hardware/oplus` policy (prefer oplus type labels; keep only samurai-unique paths such as `sysfs_oppo_display`).
- **`shims/`** — Tiny libbase/libcrypto shims for legacy ODM blobs (dspservice, ATFWD-daemon).
- **`overlay*/`** — RRO (Runtime Resource Overlay) packages that patch framework resources at runtime (SystemUI, Settings, Telephony, WiFi, etc.). `overlay-lineage/` is for LineageOS-specific overrides.
- **`rootdir/`** — Files copied verbatim to the root filesystem: `bin/` (init shell scripts), `etc/` (init RC files, `fstab.qcom`).
- **`audio/`** — ALSA mixer paths, audio platform info, sound trigger config, and ACDB calibration data for the WCD9340 codec.
- **`configs/`** — GPS, media codec/profile XML, power hint JSON, QMI config.

## Architecture Patterns

### HAL Service Pattern
All HAL implementations follow the same structure: a `service.cpp` that registers the HIDL/AIDL service, a main implementation class inheriting from the generated interface base (e.g., `IFingerprint`), and a `Android.bp` declaring a `cc_binary` with `init_rc` and `vintf_fragments` entries pointing to the service's RC and manifest fragment.

### UDFPS Integration
The fingerprint HAL (`fingerprint/`) calls into `syshelper/` via AIDL to raise/lower a dim layer on the display during fingerprint authentication. The relevant chain is:
1. `BiometricsFingerprint` receives an authenticate/cancel request
2. It calls `UdfpsHelper` (in `syshelper/`) to toggle `dimlayer_hbm` via the display driver sysfs node
3. `getUdfpsDimZOrder()` controls the z-order of the dim layer

### Device Variant Detection
`init/init_samurai.cpp` runs at early boot and reads the `ro.boot.id.operators` property to distinguish variants, then calls `property_override()` to set the correct `ro.product.*` and `ro.build.*` values. This pattern is also used for RAM-tier-specific dalvik heap configurations.

### Property Files
- `system.prop` — ART, audio, BT, camera, RIL/IMS properties for the system partition
- `vendor.prop` — Qualcomm-specific tuning (audio, display, DPM, GPS, perf) for the vendor partition
- `odm.prop` / `product.prop` / `system_ext.prop` — Partition-specific overrides

Properties are loaded by the partition they reside on; do not put vendor-domain properties in `system.prop`.

### Overlays vs Properties
Use **RRO overlays** (`overlay*/`) to override framework resource values (strings, integers, booleans in `res/values/`). Use **property files** for runtime tunables consumed by native daemons and the HAL layer. Do not duplicate the same setting in both.

## Conventions

- **License header**: All new source files use `SPDX-License-Identifier: Apache-2.0` with a one-line copyright.
- **Soong (`Android.bp`) is preferred** over legacy `Android.mk`. Use `Android.mk` only for cases Soong cannot handle (e.g., custom install targets via `LOCAL_MODULE_PATH`).
- **C++ standard**: C++17 is available. Use `android::base` utilities (`android::base::ReadFileToString`, `android::base::SetProperty`, etc.) rather than raw POSIX where possible.
- **SELinux**: Every new executable or service needs a corresponding type in `sepolicy/`, a file context in `file_contexts`, and a service context if it registers with hwservicemanager/servicemanager.
- **HIDL vs AIDL**: Existing HALs use HIDL (fingerprint 2.3, sensors 2.1). New services (syshelper) use AIDL with the NDK backend. Don't mix HIDL and AIDL in the same service.
- **Proprietary blobs**: Listed in `proprietary-files.txt` with SHA-1 checksums. After adding or updating a blob, run `./update-sha1sums.py` and commit the updated checksums alongside the change.
