package com.kayto.kayto.storage

import android.content.Context
import android.content.SharedPreferences
import com.kayto.kayto.model.AppRule
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class KaytoStorage(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        private const val PREFS_NAME = "kayto_native_prefs"
        private const val KEY_RULES_JSON = "key_rules_json"
        private const val KEY_VPN_ENABLED = "key_vpn_enabled"
        private const val KEY_PIN_SERVICE = "key_pin_service"
        private const val KEY_HEARTBEAT_FAIL_COUNT = "key_heartbeat_fail_count"
        private const val KEY_BLOCKED_PACKETS_COUNT = "key_blocked_packets_count"
        private const val KEY_BLOCKED_BYTES_COUNT = "key_blocked_bytes_count"
        private const val KEY_STATS_DATE = "key_stats_date"
        private const val KEY_NOTIFIED_THRESHOLDS = "key_notified_thresholds"
    }

    private fun getTodayDateString(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    private fun checkDateReset() {
        val today = getTodayDateString()
        val storedDate = prefs.getString(KEY_STATS_DATE, null)
        if (storedDate != today) {
            prefs.edit()
                .putString(KEY_STATS_DATE, today)
                .putLong(KEY_BLOCKED_PACKETS_COUNT, 0L)
                .putLong(KEY_BLOCKED_BYTES_COUNT, 0L)
                .putStringSet(KEY_NOTIFIED_THRESHOLDS, emptySet())
                .apply()
        }
    }

    fun saveRules(rules: List<AppRule>) {
        val array = JSONArray()
        rules.forEach { array.put(it.toJsonObject()) }
        prefs.edit().putString(KEY_RULES_JSON, array.toString()).apply()
    }

    fun getRules(): List<AppRule> {
        val jsonString = prefs.getString(KEY_RULES_JSON, null) ?: return emptyList()
        val list = mutableListOf<AppRule>()
        try {
            val array = JSONArray(jsonString)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                list.add(AppRule.fromJsonObject(obj))
            }
        } catch (_: Exception) {
        }
        return list
    }

    fun setVpnEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_VPN_ENABLED, enabled).apply()
    }

    fun isVpnEnabled(): Boolean {
        return prefs.getBoolean(KEY_VPN_ENABLED, false)
    }

    fun setPinServiceEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_PIN_SERVICE, enabled).apply()
    }

    fun isPinServiceEnabled(): Boolean {
        return prefs.getBoolean(KEY_PIN_SERVICE, true)
    }

    fun getHeartbeatFailCount(): Int {
        return prefs.getInt(KEY_HEARTBEAT_FAIL_COUNT, 0)
    }

    fun setHeartbeatFailCount(count: Int) {
        prefs.edit().putInt(KEY_HEARTBEAT_FAIL_COUNT, count).apply()
    }

    fun resetHeartbeatFailCount() {
        prefs.edit().putInt(KEY_HEARTBEAT_FAIL_COUNT, 0).apply()
    }

    fun incrementBlockedStats(packets: Long = 1, bytes: Long = 0) {
        checkDateReset()
        val currentPackets = prefs.getLong(KEY_BLOCKED_PACKETS_COUNT, 0L)
        val currentBytes = prefs.getLong(KEY_BLOCKED_BYTES_COUNT, 0L)
        prefs.edit()
            .putLong(KEY_BLOCKED_PACKETS_COUNT, currentPackets + packets)
            .putLong(KEY_BLOCKED_BYTES_COUNT, currentBytes + bytes)
            .apply()
    }

    fun getBlockedStats(): Pair<Long, Long> {
        checkDateReset()
        val packets = prefs.getLong(KEY_BLOCKED_PACKETS_COUNT, 0L)
        val bytes = prefs.getLong(KEY_BLOCKED_BYTES_COUNT, 0L)
        return Pair(packets, bytes)
    }

    fun hasNotifiedThreshold(key: String): Boolean {
        checkDateReset()
        val set = prefs.getStringSet(KEY_NOTIFIED_THRESHOLDS, emptySet()) ?: emptySet()
        return set.contains(key)
    }

    fun markThresholdNotified(key: String) {
        checkDateReset()
        val set = prefs.getStringSet(KEY_NOTIFIED_THRESHOLDS, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        set.add(key)
        prefs.edit().putStringSet(KEY_NOTIFIED_THRESHOLDS, set).apply()
    }
}
