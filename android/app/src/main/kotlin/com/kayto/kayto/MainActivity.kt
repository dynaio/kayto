package com.kayto.kayto

import android.app.Activity
import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.net.TrafficStats
import android.os.Bundle
import android.os.PowerManager
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.lifecycleScope
import com.kayto.kayto.model.AppRule
import com.kayto.kayto.model.NetworkSource
import com.kayto.kayto.service.KaytoVpnService
import com.kayto.kayto.stats.UsageMeasurementService
import com.kayto.kayto.storage.KaytoStorage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.kayto/native"
    private val eventChannelName = "com.kayto/events"

    private val VPN_REQUEST_CODE = 4096
    private var pendingVpnResult: MethodChannel.Result? = null

    private lateinit var storage: KaytoStorage
    private lateinit var usageMeasurementService: UsageMeasurementService
    private var eventSink: EventChannel.EventSink? = null

    // 30-second in-memory cache of the app list
    private var cachedApps: List<Map<String, Any?>>? = null
    private var cacheTimestamp: Long = 0L
    private val CACHE_TTL_MS = 30_000L

    // Realtime device speed tracking (TrafficStats)
    private var lastRxBytes: Long = -1L
    private var lastTxBytes: Long = -1L
    private var lastSpeedTimestamp: Long = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        storage = KaytoStorage(this)
        usageMeasurementService = UsageMeasurementService(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listInstalledApps" -> {
                        lifecycleScope.launch(Dispatchers.IO) {
                            try {
                                val apps = getCachedOrFetchInstalledApps(includeIcons = true)
                                withContext(Dispatchers.Main) {
                                    result.success(apps)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("LIST_APPS_FAILED", e.message, null)
                                }
                            }
                        }
                    }
                    "listInstalledAppsLite" -> {
                        lifecycleScope.launch(Dispatchers.IO) {
                            try {
                                val apps = getCachedOrFetchInstalledApps(includeIcons = false)
                                withContext(Dispatchers.Main) {
                                    result.success(apps)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("LIST_APPS_FAILED", e.message, null)
                                }
                            }
                        }
                    }
                    "getAppIcon" -> {
                        val packageName = call.argument<String>("packageName")
                        if (packageName == null) {
                            result.error("INVALID_ARGS", "packageName required", null)
                            return@setMethodCallHandler
                        }
                        lifecycleScope.launch(Dispatchers.IO) {
                            val iconBytes = fetchSingleAppIcon(packageName)
                            withContext(Dispatchers.Main) {
                                result.success(iconBytes)
                            }
                        }
                    }
                    "hasUsageAccess" -> {
                        result.success(hasUsageAccessPermission())
                    }
                    "hasBatteryOptimizationExemption" -> {
                        result.success(isIgnoringBatteryOptimizations())
                    }
                    "openUsageAccessSettings" -> {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    "openBatteryOptimizationSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(null)
                        } catch (_: Exception) {
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallbackIntent)
                            result.success(null)
                        }
                    }
                    "getSimCards" -> {
                        try {
                            val sims = usageMeasurementService.getActiveSims().map { it.toMap() }
                            result.success(sims)
                        } catch (e: Exception) {
                            result.error("SIMS_FAILED", e.message, null)
                        }
                    }
                    "getNetworkUsage" -> {
                        val packageName = call.argument<String>("packageName")
                        try {
                            if (packageName != null) {
                                val usage = usageMeasurementService.getTodayUsageForPackage(packageName)
                                result.success(usage)
                            } else {
                                val allUsage = usageMeasurementService.getAllAppsTodayUsage()
                                result.success(allUsage)
                            }
                        } catch (e: Exception) {
                            result.error("USAGE_FAILED", e.message, null)
                        }
                    }
                    "getActiveNetwork" -> {
                        result.success(usageMeasurementService.getCurrentActiveNetwork())
                    }
                    "prepareVpn" -> {
                        val intent = VpnService.prepare(this)
                        result.success(intent == null)
                    }
                    "startVpn" -> {
                        val intent = VpnService.prepare(this)
                        if (intent != null) {
                            pendingVpnResult = result
                            startActivityForResult(intent, VPN_REQUEST_CODE)
                        } else {
                            startKaytoVpnService()
                            result.success(true)
                        }
                    }
                    "stopVpn" -> {
                        stopKaytoVpnService()
                        result.success(true)
                    }
                    "isVpnRunning" -> {
                        result.success(KaytoVpnService.isServiceRunning())
                    }
                    "syncRules" -> {
                        val rulesListRaw = call.argument<List<Map<String, Any?>>>("rules")
                        if (rulesListRaw != null) {
                            val rules = rulesListRaw.map { map ->
                                val pkg = map["packageName"] as String
                                val src = NetworkSource.fromString(map["source"] as String)
                                val limitNum = map["limitMb"] as? Number
                                val limitMb = limitNum?.toLong()
                                val schedule = (map["scheduleMode"] as? String) ?: "DAILY"
                                val bitmask = (map["customDaysBitmask"] as? Number)?.toInt() ?: 127
                                val isEnforced = (map["isEnforced"] as? Boolean) ?: true
                                val isMonitored = (map["isMonitored"] as? Boolean) ?: true
                                val notifyList = (map["notifyAt"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() }
                                    ?: listOf(50, 70, 90, 100)

                                AppRule(
                                    packageName = pkg,
                                    source = src,
                                    limitMb = limitMb,
                                    scheduleMode = schedule,
                                    customDaysBitmask = bitmask,
                                    notifyAt = notifyList,
                                    isEnforced = isEnforced,
                                    isMonitored = isMonitored
                                )
                            }
                            storage.saveRules(rules)
                            if (KaytoVpnService.isServiceRunning()) {
                                val updateIntent = Intent(this, KaytoVpnService::class.java).apply {
                                    action = KaytoVpnService.ACTION_UPDATE_RULES
                                }
                                startService(updateIntent)
                            }
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGS", "Rules argument missing", null)
                        }
                    }
                    "getEnforcementStats" -> {
                        val (packets, bytes) = storage.getBlockedStats()
                        val stats = mapOf(
                            "blockedPackets" to packets,
                            "blockedBytes" to bytes,
                            "isVpnRunning" to KaytoVpnService.isServiceRunning(),
                            "activeNetwork" to usageMeasurementService.getCurrentActiveNetwork()
                        )
                        result.success(stats)
                    }
                    "checkPermissions" -> {
                        val status = mapOf(
                            "usageAccess" to hasUsageAccessPermission(),
                            "batteryOptimization" to isIgnoringBatteryOptimizations(),
                            "notification" to NotificationManagerCompat.from(this).areNotificationsEnabled(),
                            "vpnConsent" to (VpnService.prepare(this) == null),
                            "phoneState" to (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED)
                        )
                        result.success(status)
                    }
                    "requestUsageAccess" -> {
                        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    }
                    "requestBatteryOptimizationExemption" -> {
                        try {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(fallbackIntent)
                            result.success(true)
                        }
                    }
                    "getRealtimeDeviceSpeed" -> {
                        val currentRx = TrafficStats.getTotalRxBytes()
                        val currentTx = TrafficStats.getTotalTxBytes()
                        val now = SystemClock.elapsedRealtime()

                        if (currentRx == TrafficStats.UNSUPPORTED.toLong() || currentTx == TrafficStats.UNSUPPORTED.toLong()) {
                            result.success(mapOf("unsupported" to true))
                            return@setMethodCallHandler
                        }

                        val deltaMs = now - lastSpeedTimestamp
                        if (lastRxBytes < 0 || lastTxBytes < 0 || deltaMs <= 0) {
                            lastRxBytes = currentRx
                            lastTxBytes = currentTx
                            lastSpeedTimestamp = now
                            result.success(
                                mapOf(
                                    "rxBps" to 0L,
                                    "txBps" to 0L,
                                    "unsupported" to false
                                )
                            )
                        } else {
                            val deltaRx = (currentRx - lastRxBytes).coerceAtLeast(0L)
                            val deltaTx = (currentTx - lastTxBytes).coerceAtLeast(0L)
                            val rxBps = (deltaRx * 1000L) / deltaMs
                            val txBps = (deltaTx * 1000L) / deltaMs

                            lastRxBytes = currentRx
                            lastTxBytes = currentTx
                            lastSpeedTimestamp = now

                            result.success(
                                mapOf(
                                    "rxBps" to rxBps,
                                    "txBps" to txBps,
                                    "unsupported" to false
                                )
                            )
                        }
                    }
                    "getPerAppUsageSnapshot" -> {
                        val packages = call.argument<List<String>>("packages")
                        lifecycleScope.launch(Dispatchers.IO) {
                            try {
                                val targetPackages = if (!packages.isNullOrEmpty()) {
                                    packages
                                } else {
                                    storage.getRules().map { it.packageName }.distinct()
                                }
                                val snapshot = usageMeasurementService.getPerAppUsageSnapshot(targetPackages)
                                withContext(Dispatchers.Main) {
                                    result.success(snapshot)
                                }
                            } catch (e: Exception) {
                                withContext(Dispatchers.Main) {
                                    result.error("SNAPSHOT_FAILED", e.message, null)
                                }
                            }
                        }
                    }
                    "setPinService" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        storage.setPinServiceEnabled(enabled)
                        KaytoApp.updateHeartbeatSchedule(this@MainActivity, enabled)
                        result.success(true)
                    }
                    "isPinServiceEnabled" -> {
                        result.success(storage.isPinServiceEnabled())
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun startKaytoVpnService() {
        val intent = Intent(this, KaytoVpnService::class.java).apply {
            action = KaytoVpnService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopKaytoVpnService() {
        val intent = Intent(this, KaytoVpnService::class.java).apply {
            action = KaytoVpnService.ACTION_STOP
        }
        startService(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                startKaytoVpnService()
                pendingVpnResult?.success(true)
            } else {
                pendingVpnResult?.success(false)
            }
            pendingVpnResult = null
        }
    }

    private fun hasUsageAccessPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }

    @Synchronized
    private fun getCachedOrFetchInstalledApps(includeIcons: Boolean): List<Map<String, Any?>> {
        val now = System.currentTimeMillis()
        if (cachedApps != null && (now - cacheTimestamp) < CACHE_TTL_MS) {
            Log.i("Kayto", "Cache hit for installed apps")
            val list = cachedApps!!
            return if (includeIcons) {
                list
            } else {
                list.map {
                    mapOf(
                        "packageName" to it["packageName"],
                        "label" to it["label"],
                        "isSystemApp" to it["isSystemApp"]
                    )
                }
            }
        }

        val pm = packageManager
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledApplications(0)
        }

        val result = packages
            .filter { it.packageName != packageName } // Exclude Kayto itself
            .map { info ->
                val isSystem = (info.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                val iconBytes: ByteArray? = if (includeIcons) {
                    renderAppIconBytes(pm, info)
                } else null

                mapOf(
                    "packageName" to info.packageName,
                    "label" to pm.getApplicationLabel(info).toString(),
                    "icon" to iconBytes,
                    "isSystemApp" to isSystem
                )
            }
            .sortedBy { (it["label"] as? String)?.lowercase() ?: "" }

        cachedApps = result
        cacheTimestamp = now
        return result
    }

    private fun fetchSingleAppIcon(targetPackage: String): ByteArray? {
        val pm = packageManager
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getApplicationInfo(targetPackage, PackageManager.ApplicationInfoFlags.of(0L))
            } else {
                @Suppress("DEPRECATION")
                pm.getApplicationInfo(targetPackage, 0)
            }
            renderAppIconBytes(pm, info)
        } catch (_: Exception) {
            null
        }
    }

    private fun renderAppIconBytes(pm: PackageManager, info: ApplicationInfo): ByteArray? {
        return try {
            val drawable = pm.getApplicationIcon(info)
            val bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val w = drawable.intrinsicWidth.coerceAtLeast(1)
                    val h = drawable.intrinsicHeight.coerceAtLeast(1)
                    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            }
            // 48x48 cuts payload 4x compared to 96x96
            val scaled = Bitmap.createScaledBitmap(bitmap, 48, 48, true)
            val stream = ByteArrayOutputStream()
            scaled.compress(Bitmap.CompressFormat.PNG, 100, stream)
            stream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }
}
