package com.kayto.kayto.model

import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

data class AppRule(
    val packageName: String,
    val source: NetworkSource,
    val limitMb: Long?,                // null = Infinite
    val scheduleMode: String = "DAILY",// "DAILY" or "CUSTOM_DAYS"
    val customDaysBitmask: Int = 127,  // 7 bits: bit0=Mon, bit1=Tue, ..., bit6=Sun (127 = every day)
    val notifyAt: List<Int> = listOf(50, 70, 90, 100),
    val isEnforced: Boolean = true,
    val isMonitored: Boolean = true
) {
    /**
     * Checks if this rule is active on the current day of the week.
     */
    fun isScheduledToday(): Boolean {
        if (!isMonitored) return false
        if (scheduleMode == "DAILY") return true

        val calendar = Calendar.getInstance()
        // Calendar.DAY_OF_WEEK: Sunday=1, Monday=2, Tuesday=3, ... Saturday=7
        val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
        val bitIndex = when (dayOfWeek) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            Calendar.SATURDAY -> 5
            Calendar.SUNDAY -> 6
            else -> 0
        }
        return ((customDaysBitmask shr bitIndex) and 1) == 1
    }

    fun toJsonObject(): JSONObject {
        val json = JSONObject()
        json.put("packageName", packageName)
        json.put("source", source.name)
        if (limitMb != null) {
            json.put("limitMb", limitMb)
        } else {
            json.put("limitMb", JSONObject.NULL)
        }
        json.put("scheduleMode", scheduleMode)
        json.put("customDaysBitmask", customDaysBitmask)
        json.put("isEnforced", isEnforced)
        json.put("isMonitored", isMonitored)

        val arr = JSONArray()
        notifyAt.forEach { arr.put(it) }
        json.put("notifyAt", arr)
        return json
    }

    companion object {
        fun fromJsonObject(json: JSONObject): AppRule {
            val pkg = json.getString("packageName")
            val src = NetworkSource.fromString(json.getString("source"))
            val limit = if (json.isNull("limitMb")) null else json.getLong("limitMb")
            val schedule = json.optString("scheduleMode", "DAILY")
            val bitmask = json.optInt("customDaysBitmask", 127)
            val enforced = json.optBoolean("isEnforced", true)
            val monitored = json.optBoolean("isMonitored", true)

            val notifyList = mutableListOf<Int>()
            val arr = json.optJSONArray("notifyAt")
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    notifyList.add(arr.getInt(i))
                }
            } else {
                notifyList.addAll(listOf(50, 70, 90, 100))
            }

            return AppRule(
                packageName = pkg,
                source = src,
                limitMb = limit,
                scheduleMode = schedule,
                customDaysBitmask = bitmask,
                notifyAt = notifyList,
                isEnforced = enforced,
                isMonitored = monitored
            )
        }
    }
}
