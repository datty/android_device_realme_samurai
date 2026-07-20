/*
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.chargespeed;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * Re-apply cool_down after boot and when a charger is plugged
 * (kernel/charger may clear cool_down on connect).
 */
public class BootCompletedReceiver extends BroadcastReceiver {
    private static final String TAG = "ChargingSpeed";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null || intent.getAction() == null) {
            return;
        }
        String action = intent.getAction();
        if (Intent.ACTION_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(action)
                || Intent.ACTION_POWER_CONNECTED.equals(action)) {
            Log.i(TAG, "restore cool_down on " + action);
            CoolDownUtils.restore(context);
        }
    }
}
