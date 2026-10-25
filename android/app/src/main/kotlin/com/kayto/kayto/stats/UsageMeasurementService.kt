package com.kayto.kayto.stats

import android.annotation.SuppressLint
import android.app.usage.NetworkStats
import android.app.usage.NetworkStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import com.kayto.kayto.model.SimInfo
import java.util.Calendar

class UsageMeasurementService(private val context: Context) {

    private val networkStatsManager: NetworkStatsManager? =
        context.getSystemService(Context.NETWORK_STATS_SERVICE) as? NetworkStatsManager

    private val telephonyManager: TelephonyManager? =
        context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

    private val subscriptionManager: SubscriptionManager? =
        context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager

    private val connectivityManager: ConnectivityManager? =
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    /**
     * Resolves active SIM cards on the device.
     */
    @SuppressLint("MissingPermission")
    fun getActiveSims(): List<SimInfo> {
        val list = mutableListOf<SimInfo>()
        if (subscriptionManager == null) return list

        try {
            val subInfos: List<SubscriptionInfo>? = subscriptionManager.activeSubscriptionInfoList
            val defaultDataSubId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                SubscriptionManager.getDefaultDataSubscriptionId()
            } else {
                -1
            }

            subInfos?.forEach { info ->
                val slot = info.simSlotIndex // 0 = SIM 1, 1 = SIM 2
                val subId = info.subscriptionId
                val displayName = info.displayName?.toString() ?: "SIM ${slot + 1}"
                val carrierName = info.carrierName?.toString() ?: displayName

                var subImsi: String? = null
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && telephonyManager != null) {
                    try {
                        val specificTel = telephonyManager.createForSubscriptionId(subId)
                        subImsi = specificTel.subscriberId
                    } catch (_: Exception) {
                    }
                }

                list.add(
                    SimInfo(
                        slotIndex = slot,
                        subscriptionId = subId,
                        displayName = displayName,
                        carrierName = carrierName,
                        isDefaultData = (subId == defaultDataSubId),
                        subscriberId = subImsi
                    )
                )
            }
        } catch (_: Exception) {
        }
        return list.sortedBy { it.slotIndex }
    }

    /**
     * Returns the current active transport ("WIFI", "SIM_1", "SIM_2", "NONE")
     */
    fun getCurrentActiveNetwork(): String {
        val cm = connectivityManager ?: return "NONE"
        val activeNet = cm.activeNetwork ?: return "NONE"
        val caps = cm.getNetworkCapabilities(activeNet) ?: return "NONE"

        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            return "WIFI"
        }

        if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
            val sims = getActiveSims()
            val defaultDataSim = sims.firstOrNull { it.isDefaultData }
            return when {
                defaultDataSim != null && defaultDataSim.slotIndex == 0 -> "SIM_1"
                defaultDataSim != null && defaultDataSim.slotIndex == 1 -> "SIM_2"
                sims.isNotEmpty() && sims[0].slotIndex == 0 -> "SIM_1"
                sims.size > 1 && sims[1].slotIndex == 1 -> "SIM_2"
                else -> "SIM_1"
            }
        }

        return "NONE"
    }

    /**
     * Measures data usage for a specific package today (rx + tx in bytes)
     * Broken down into: wifiBytes, sim1Bytes, sim2Bytes, and attribution note.
     */
    fun getTodayUsageForPackage(packageName: String): Map<String, Any?> {
        val pm = context.packageManager
        val uid = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageUid(packageName, PackageManager.PackageInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageUid(packageName, 0)
            }
        } catch (_: Exception) {
            return mapOf(
                "packageName" to packageName,
                "wifiBytes" to 0L,
                "sim1Bytes" to 0L,
                "sim2Bytes" to 0L,
                "isAttributed" to false
            )
        }

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        return getUsageForUid(packageName, uid, startTime, endTime)
    }

    /**
     * Fast snapshot of today's usage for a specified list of monitored packages.
     */
    fun getPerAppUsageSnapshot(packages: List<String>): List<Map<String, Any?>> {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()
        val pm = context.packageManager

        val results = mutableListOf<Map<String, Any?>>()
        for (pkg in packages) {
            val uid = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getPackageUid(pkg, PackageManager.PackageInfoFlags.of(0L))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getPackageUid(pkg, 0)
                }
            } catch (_: Exception) {
                continue
            }

            val usage = getUsageForUid(pkg, uid, startTime, endTime)
            results.add(usage)
        }
        return results
    }

    /**
     * Measures data usage for all installed apps for today.
     */
    fun getAllAppsTodayUsage(): List<Map<String, Any?>> {
        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startTime = calendar.timeInMillis
        val endTime = System.currentTimeMillis()

        val pm = context.packageManager
        val packages = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getInstalledApplications(0)
            }
        } catch (_: Exception) {
            emptyList()
        }

        val results = mutableListOf<Map<String, Any?>>()
        for (app in packages) {
            val usage = getUsageForUid(app.packageName, app.uid, startTime, endTime)
            // Filter out apps with zero total usage to save memory/payload size
            val wifi = usage["wifiBytes"] as Long
            val sim1 = usage["sim1Bytes"] as Long
            val sim2 = usage["sim2Bytes"] as Long
            if (wifi > 0 || sim1 > 0 || sim2 > 0) {
                results.add(usage)
            }
        }
        return results
    }

    private fun getUsageForUid(
        packageName: String,
        uid: Int,
        startTime: Long,
        endTime: Long
    ): Map<String, Any?> {
        val nsm = networkStatsManager ?: return mapOf(
            "packageName" to packageName,
            "wifiBytes" to 0L,
            "sim1Bytes" to 0L,
            "sim2Bytes" to 0L,
            "isAttributed" to false
        )

        var wifiBytes = 0L
        var sim1Bytes = 0L
        var sim2Bytes = 0L
        var isAttributed = false

        // 1. Wi-Fi usage
        try {
            val wifiStats = nsm.queryDetailsForUid(
                NetworkCapabilities.TRANSPORT_WIFI,
                null,
                startTime,
                endTime,
                uid
            )
            val bucket = NetworkStats.Bucket()
            while (wifiStats.hasNextBucket()) {
                wifiStats.getNextBucket(bucket)
                wifiBytes += bucket.rxBytes + bucket.txBytes
            }
            wifiStats.close()
        } catch (_: Exception) {
        }

        // 2. Cellular usage (Dual-Path)
        val activeSims = getActiveSims()
        val sim1 = activeSims.firstOrNull { it.slotIndex == 0 }
        val sim2 = activeSims.firstOrNull { it.slotIndex == 1 }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            // Android 9 and below: direct subscriberId query
            sim1?.subscriberId?.let { imsi ->
                sim1Bytes = queryCellularBytesForSubscriber(nsm, imsi, startTime, endTime, uid)
            }
            sim2?.subscriberId?.let { imsi ->
                sim2Bytes = queryCellularBytesForSubscriber(nsm, imsi, startTime, endTime, uid)
            }
        } else {
            // Android 10+:
            // Check if SIM-specific queries are supported or fall back to null aggregate
            var queriedSim1 = false
            var queriedSim2 = false

            if (sim1?.subscriberId != null) {
                try {
                    sim1Bytes = queryCellularBytesForSubscriber(nsm, sim1.subscriberId, startTime, endTime, uid)
                    queriedSim1 = true
                } catch (_: Exception) {
                }
            }
            if (sim2?.subscriberId != null) {
                try {
                    sim2Bytes = queryCellularBytesForSubscriber(nsm, sim2.subscriberId, startTime, endTime, uid)
                    queriedSim2 = true
                } catch (_: Exception) {
                }
            }

            if (!queriedSim1 && !queriedSim2) {
                // Query aggregated cellular with subscriberId = null
                var aggregateCellular = 0L
                try {
                    val mobileStats = nsm.queryDetailsForUid(
                        NetworkCapabilities.TRANSPORT_CELLULAR,
                        null,
                        startTime,
                        endTime,
                        uid
                    )
                    val bucket = NetworkStats.Bucket()
                    while (mobileStats.hasNextBucket()) {
                        mobileStats.getNextBucket(bucket)
                        aggregateCellular += bucket.rxBytes + bucket.txBytes
                    }
                    mobileStats.close()
                } catch (_: Exception) {
                }

                // Attribute cellular data according to default active data SIM
                val defaultDataSubId = SubscriptionManager.getDefaultDataSubscriptionId()
                if (sim2 != null && sim2.subscriptionId == defaultDataSubId) {
                    sim2Bytes = aggregateCellular
                } else {
                    sim1Bytes = aggregateCellular
                }
                isAttributed = true
            }
        }

        return mapOf(
            "packageName" to packageName,
            "wifiBytes" to wifiBytes,
            "sim1Bytes" to sim1Bytes,
            "sim2Bytes" to sim2Bytes,
            "isAttributed" to isAttributed
        )
    }

    private fun queryCellularBytesForSubscriber(
        nsm: NetworkStatsManager,
        subscriberId: String,
        startTime: Long,
        endTime: Long,
        uid: Int
    ): Long {
        var bytes = 0L
        try {
            val stats = nsm.queryDetailsForUid(
                NetworkCapabilities.TRANSPORT_CELLULAR,
                subscriberId,
                startTime,
                endTime,
                uid
            )
            val bucket = NetworkStats.Bucket()
            while (stats.hasNextBucket()) {
                stats.getNextBucket(bucket)
                bytes += bucket.rxBytes + bucket.txBytes
            }
            stats.close()
        } catch (_: Exception) {
        }
        return bytes
    }
}
