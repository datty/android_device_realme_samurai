/*
 * SPDX-FileCopyrightText: 2026
 * SPDX-License-Identifier: Apache-2.0
 */

package org.lineageos.settings.chargespeed;

import android.os.Bundle;

import androidx.preference.ListPreference;
import androidx.preference.Preference;
import androidx.preference.PreferenceFragment;

public class ChargingSpeedFragment extends PreferenceFragment
        implements Preference.OnPreferenceChangeListener {

    private ListPreference mSpeedPref;

    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        setPreferencesFromResource(R.xml.charging_speed_preferences, rootKey);

        mSpeedPref = findPreference(CoolDownUtils.PREF_KEY);
        if (mSpeedPref == null) {
            return;
        }

        if (!CoolDownUtils.isSupported()) {
            mSpeedPref.setEnabled(false);
            mSpeedPref.setSummary(R.string.charging_speed_unavailable);
            return;
        }

        int saved = CoolDownUtils.loadSaved(getContext());
        mSpeedPref.setValue(String.valueOf(saved));
        mSpeedPref.setOnPreferenceChangeListener(this);
    }

    @Override
    public boolean onPreferenceChange(Preference preference, Object newValue) {
        if (preference == mSpeedPref) {
            int level;
            try {
                level = Integer.parseInt((String) newValue);
            } catch (NumberFormatException e) {
                return false;
            }
            CoolDownUtils.saveAndApply(getContext(), level);
            return true;
        }
        return false;
    }
}
