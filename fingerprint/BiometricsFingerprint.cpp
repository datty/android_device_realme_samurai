/*
 * Copyright (C) 2022 The LineageOS Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#define LOG_TAG "android.hardware.biometrics.fingerprint@2.3-service.samurai"

#include "BiometricsFingerprint.h"

#include <android/binder_manager.h>
#include <android/binder_process.h>

#include <string>

namespace android {
namespace hardware {
namespace biometrics {
namespace fingerprint {
namespace V2_3 {
namespace implementation {

namespace {

constexpr RequestStatus kHwUnavailable = RequestStatus::SYS_EINVAL;

}  // namespace

BiometricsFingerprint::BiometricsFingerprint() : isEnrolling(false) {
    mOplusBiometricsFingerprint = IOplusBiometricsFingerprint::getService();
    if (mOplusBiometricsFingerprint == nullptr) {
        ALOGE("Failed to get IOplusBiometricsFingerprint service");
    } else {
        mOplusBiometricsFingerprint->setHalCallback(this);
    }

    // Prefer non-blocking check first; fall back to wait so late_start still works
    // when syshelper (class hal) is slightly delayed.
    std::string instanceName = std::string() + IUdfpsHelper::descriptor + "/default";
    ndk::SpAIBinder binder(AServiceManager_checkService(instanceName.c_str()));
    if (binder.get() == nullptr) {
        ALOGI("IUdfpsHelper not ready yet, waiting...");
        binder = ndk::SpAIBinder(AServiceManager_waitForService(instanceName.c_str()));
    }
    mOplusUdfpsHelper = IUdfpsHelper::fromBinder(binder);
    if (mOplusUdfpsHelper == nullptr) {
        ALOGE("Failed to get IUdfpsHelper service");
    }
}

bool BiometricsFingerprint::ensureOplusHal() const {
    if (mOplusBiometricsFingerprint != nullptr) {
        return true;
    }
    ALOGE("IOplusBiometricsFingerprint unavailable");
    return false;
}

Return<uint64_t> BiometricsFingerprint::setNotify(
        const sp<V2_1::IBiometricsFingerprintClientCallback>& clientCallback) {
    mClientCallback = clientCallback;
    if (!ensureOplusHal()) {
        return uint64_t{0};
    }
    return mOplusBiometricsFingerprint->setNotify(this);
}

Return<uint64_t> BiometricsFingerprint::preEnroll() {
    if (!ensureOplusHal()) {
        return uint64_t{0};
    }
    isEnrolling = true;
    setDimlayerHbm(1);
    return mOplusBiometricsFingerprint->preEnroll();
}

Return<RequestStatus> BiometricsFingerprint::enroll(const hidl_array<uint8_t, 69>& hat,
                                                    uint32_t gid, uint32_t timeoutSec) {
    if (!ensureOplusHal()) {
        return kHwUnavailable;
    }
    setDimlayerHbm(1);
    return mOplusBiometricsFingerprint->enroll(hat, gid, timeoutSec);
}

Return<RequestStatus> BiometricsFingerprint::postEnroll() {
    if (!ensureOplusHal()) {
        return kHwUnavailable;
    }
    isEnrolling = false;
    setDimlayerHbm(0);
    return mOplusBiometricsFingerprint->postEnroll();
}

Return<uint64_t> BiometricsFingerprint::getAuthenticatorId() {
    if (!ensureOplusHal()) {
        return uint64_t{0};
    }
    return mOplusBiometricsFingerprint->getAuthenticatorId();
}

Return<RequestStatus> BiometricsFingerprint::cancel() {
    if (!ensureOplusHal()) {
        return kHwUnavailable;
    }
    if (!isEnrolling) {
        setDimlayerHbm(0);
    }
    return mOplusBiometricsFingerprint->cancel();
}

Return<RequestStatus> BiometricsFingerprint::enumerate() {
    if (!ensureOplusHal()) {
        return kHwUnavailable;
    }
    return mOplusBiometricsFingerprint->enumerate();
}

Return<RequestStatus> BiometricsFingerprint::remove(uint32_t gid, uint32_t fid) {
    if (!ensureOplusHal()) {
        return kHwUnavailable;
    }
    return mOplusBiometricsFingerprint->remove(gid, fid);
}

Return<RequestStatus> BiometricsFingerprint::setActiveGroup(uint32_t gid,
                                                            const hidl_string& storePath) {
    if (!ensureOplusHal()) {
        return kHwUnavailable;
    }
    return mOplusBiometricsFingerprint->setActiveGroup(gid, storePath);
}

Return<RequestStatus> BiometricsFingerprint::authenticate(uint64_t operationId, uint32_t gid) {
    if (!ensureOplusHal()) {
        return kHwUnavailable;
    }
    // In case postEnroll never got called for whatever reason, set isEnrolling to false.
    isEnrolling = false;
    return mOplusBiometricsFingerprint->authenticate(operationId, gid);
}

Return<bool> BiometricsFingerprint::isUdfps(uint32_t sensorID) {
    if (!ensureOplusHal()) {
        return false;
    }
    return mOplusBiometricsFingerprint->isUdfps(sensorID);
}

Return<void> BiometricsFingerprint::onFingerDown(uint32_t x, uint32_t y, float minor, float major) {
    if (!isEnrolling) {
        setDimlayerHbm(1);
    }
    setFpPress(1);
    // UFF sensors handle finger events internally; forwarding causes double-processing.
    if (isUff() || !ensureOplusHal()) {
        return Void();
    }
    return mOplusBiometricsFingerprint->onFingerDown(x, y, minor, major);
}

Return<void> BiometricsFingerprint::onFingerUp() {
    setFpPress(0);
    if (!isEnrolling) {
        setDimlayerHbm(0);
    }
    if (isUff() || !ensureOplusHal()) {
        return Void();
    }
    return mOplusBiometricsFingerprint->onFingerUp();
}

Return<void> BiometricsFingerprint::onEnrollResult(uint64_t deviceId, uint32_t fingerId,
                                                   uint32_t groupId, uint32_t remaining) {
    if (mOplusUdfpsHelper != nullptr) {
        mOplusUdfpsHelper->touchUp();
    }
    if (mClientCallback == nullptr) {
        return Void();
    }
    return mClientCallback->onEnrollResult(deviceId, fingerId, groupId, remaining);
}

Return<void> BiometricsFingerprint::onAcquired(uint64_t deviceId,
                                               V2_1::FingerprintAcquiredInfo acquiredInfo,
                                               int32_t vendorCode) {
    if (mClientCallback == nullptr) {
        return Void();
    }
    return mClientCallback->onAcquired(deviceId, acquiredInfo, vendorCode);
}

Return<void> BiometricsFingerprint::onAuthenticated(uint64_t deviceId, uint32_t fingerId,
                                                    uint32_t groupId,
                                                    const hidl_vec<uint8_t>& token) {
    if (fingerId != 0) {
        setDimlayerHbm(0);
    }
    setFpPress(0);
    if (mOplusUdfpsHelper != nullptr) {
        mOplusUdfpsHelper->touchUp();
    }
    if (mClientCallback == nullptr) {
        return Void();
    }
    return mClientCallback->onAuthenticated(deviceId, fingerId, groupId, token);
}

Return<void> BiometricsFingerprint::onError(uint64_t deviceId, FingerprintError error,
                                            int32_t vendorCode) {
    setFpPress(0);
    if (!isEnrolling) {
        setDimlayerHbm(0);
    }
    if (mClientCallback == nullptr) {
        return Void();
    }
    return mClientCallback->onError(deviceId, error, vendorCode);
}

Return<void> BiometricsFingerprint::onRemoved(uint64_t deviceId, uint32_t fingerId,
                                              uint32_t groupId, uint32_t remaining) {
    if (mClientCallback == nullptr) {
        return Void();
    }
    return mClientCallback->onRemoved(deviceId, fingerId, groupId, remaining);
}

Return<void> BiometricsFingerprint::onEnumerate(uint64_t deviceId, uint32_t fingerId,
                                                uint32_t groupId, uint32_t remaining) {
    if (mClientCallback == nullptr) {
        return Void();
    }
    return mClientCallback->onEnumerate(deviceId, fingerId, groupId, remaining);
}

Return<void> BiometricsFingerprint::onAcquired_2_2(uint64_t deviceId,
                                                   FingerprintAcquiredInfo acquiredInfo,
                                                   int32_t vendorCode) {
    if (mClientCallback == nullptr) {
        return Void();
    }
    return reinterpret_cast<V2_2::IBiometricsFingerprintClientCallback*>(mClientCallback.get())
            ->onAcquired_2_2(deviceId, acquiredInfo, vendorCode);
}

Return<void> BiometricsFingerprint::onEngineeringInfoUpdated(
        uint32_t /*lenth*/, const hidl_vec<uint32_t>& /*keys*/,
        const hidl_vec<hidl_string>& /*values*/) {
    return Void();
}

Return<void> BiometricsFingerprint::onFingerprintCmd(int32_t cmdId,
                                                     const hidl_vec<uint32_t>& /*result*/,
                                                     uint32_t /*resultLen*/) {
    if (mOplusUdfpsHelper == nullptr) {
        return Void();
    }
    switch (cmdId) {
        case FINGERPRINT_CALLBACK_CMD_ID_ON_TOUCH_DOWN:
            ALOGD("onFingerprintCmd: FP Touch Down Detected!");
            mOplusUdfpsHelper->touchDown();
            break;
        case FINGERPRINT_CALLBACK_CMD_ID_ON_TOUCH_UP:
            ALOGD("onFingerprintCmd: FP Touch Up Detected!");
            mOplusUdfpsHelper->touchUp();
            break;
    }
    return Void();
}

}  // namespace implementation
}  // namespace V2_3
}  // namespace fingerprint
}  // namespace biometrics
}  // namespace hardware
}  // namespace android
