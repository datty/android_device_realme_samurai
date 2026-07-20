/*
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: Apache-2.0
 *
 * Writes oplus cool_down only. Never touches mmi_charging_enable
 * (Lineage Health owns charge limit).
 */

package org.lineageos.settings.chargespeed;

import android.content.Context;
import android.provider.Settings;
import android.util.Log;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;

public final class CoolDownUtils {
    private static final String TAG = "ChargingSpeed";

    public static final String PREF_KEY = "charging_speed";
    public static final String SECURE_KEY = "samurai_charging_speed_cool_down";

    private static final String[] COOL_DOWN_PATHS = {
            "/sys/class/power_supply/battery/cool_down",
            "/sys/devices/virtual/oplus_chg/battery/cool_down",
    };

    private CoolDownUtils() {}

    public static String getCoolDownPath() {
        for (String path : COOL_DOWN_PATHS) {
            File f = new File(path);
            if (f.exists() && f.canWrite()) {
                return path;
            }
        }
        for (String path : COOL_DOWN_PATHS) {
            if (new File(path).exists()) {
                return path;
            }
        }
        return null;
    }

    public static boolean isSupported() {
        String path = getCoolDownPath();
        return path != null && new File(path).exists();
    }

    public static int readCoolDown() {
        String path = getCoolDownPath();
        if (path == null) {
            return 0;
        }
        try (BufferedReader br = new BufferedReader(new FileReader(path), 64)) {
            String line = br.readLine();
            if (line != null) {
                return Integer.parseInt(line.trim().split("\\s+")[0]);
            }
        } catch (Exception e) {
            Log.w(TAG, "read cool_down failed", e);
        }
        return 0;
    }

    public static boolean writeCoolDown(int level) {
        if (level < 0) {
            level = 0;
        }
        String path = getCoolDownPath();
        if (path == null) {
            Log.e(TAG, "cool_down path missing");
            return false;
        }
        try (FileOutputStream fos = new FileOutputStream(path)) {
            fos.write(Integer.toString(level).getBytes());
            fos.flush();
            Log.i(TAG, "cool_down set to " + level + " via " + path);
            return true;
        } catch (IOException e) {
            Log.e(TAG, "write cool_down failed: " + path, e);
            return false;
        }
    }

    public static void saveAndApply(Context context, int level) {
        Settings.Secure.putInt(context.getContentResolver(), SECURE_KEY, level);
        writeCoolDown(level);
    }

    public static int loadSaved(Context context) {
        return Settings.Secure.getInt(context.getContentResolver(), SECURE_KEY, 0);
    }

    /** Restore user preference after boot (does not touch mmi_charging_enable). */
    public static void restore(Context context) {
        if (!isSupported()) {
            return;
        }
        int level = loadSaved(context);
        writeCoolDown(level);
    }
}
