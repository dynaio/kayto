package com.kayto.kayto.service

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.util.Log
import com.kayto.kayto.model.AppRule
import com.kayto.kayto.model.NetworkSource
import com.kayto.kayto.notifications.KaytoNotificationManager
import com.kayto.kayto.stats.UsageMeasurementService
import com.kayto.kayto.storage.KaytoStorage
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.concurrent.atomic.AtomicBoolean

class KaytoVpnService : VpnService() {

    companion object {
        const val TAG = "KaytoVpnService"
        const val ACTION_START = "com.kayto.vpn.START"
        const val ACTION_STOP = "com.kayto.vpn.STOP"
        const val ACTION_UPDATE_RULES = "com.kayto.vpn.UPDATE_RULES"

        private val isRunning = AtomicBoolean(false)
        fun isServiceRunning(): Boolean = isRunning.get()
    }

    private lateinit var storage: KaytoStorage
    private lateinit var notificationManager: KaytoNotificationManager
    private lateinit var usageMeasurementService: UsageMeasurementService
    private var vpnInterface: ParcelFileDescriptor? = null
    private var packetThread: Thread? = null
    private val isTunnelRunning = AtomicBoolean(false)

    private val handler = Handler(Looper.getMainLooper())
    private var checkRunnable: Runnable? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private var currentActiveSource: NetworkSource = NetworkSource.WIFI
    private val currentlyBlockedPackages = mutableSetOf<String>()

    override fun onCreate() {
        super.onCreate()
        storage = KaytoStorage(this)
        notificationManager = KaytoNotificationManager(this)
        usageMeasurementService = UsageMeasurementService(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // If system restarts the service with null intent, check if VPN was expected to be active
        val action = intent?.action ?: if (storage.isVpnEnabled()) ACTION_START else ACTION_STOP

        when (action) {
            ACTION_START -> {
                storage.setVpnEnabled(true)
                storage.resetHeartbeatFailCount()
                isRunning.set(true)
                startForegroundServiceNotification()
                registerNetworkCallback()
                startPeriodicUsageEvaluation()
                rebuildVpnTunnel()
            }
            ACTION_UPDATE_RULES -> {
                evaluateAndApplyRules()
            }
            ACTION_STOP -> {
                stopVpn()
                stopSelf()
            }
        }

        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // If user has enabled Keep Kayto Running (pin service), schedule immediate AlarmManager resurrection
        if (storage.isPinServiceEnabled() && storage.isVpnEnabled()) {
            Log.i(TAG, "Task removed from Recents; scheduling AlarmManager resurrection")
            val restartIntent = Intent(applicationContext, KaytoVpnService::class.java).apply {
                action = ACTION_START
            }
            val pending = PendingIntent.getService(
                applicationContext,
                1,
                restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
            val am = getSystemService(ALARM_SERVICE) as? AlarmManager
            am?.set(
                AlarmManager.RTC,
                System.currentTimeMillis() + 1000,
                pending
            )
        }
    }

    private fun startForegroundServiceNotification() {
        val (packets, _) = storage.getBlockedStats()
        val rules = storage.getRules().filter { it.isMonitored }
        val monitoredCount = rules.map { it.packageName }.distinct().size

        val notification = notificationManager.buildVpnNotification(
            monitoredCount = monitoredCount,
            blockedSourcesCount = currentlyBlockedPackages.size,
            blockedPackets = packets
        )
        startForeground(KaytoNotificationManager.NOTIFICATION_ID_VPN, notification)
    }

    private fun updateNotification() {
        val (packets, _) = storage.getBlockedStats()
        val rules = storage.getRules().filter { it.isMonitored }
        val monitoredCount = rules.map { it.packageName }.distinct().size

        val notification = notificationManager.buildVpnNotification(
            monitoredCount = monitoredCount,
            blockedSourcesCount = currentlyBlockedPackages.size,
            blockedPackets = packets
        )
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(KaytoNotificationManager.NOTIFICATION_ID_VPN, notification)
    }

    private fun registerNetworkCallback() {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                updateCurrentSource(networkCapabilities)
                handler.post { evaluateAndApplyRules() }
            }

            override fun onLost(network: Network) {
                currentActiveSource = NetworkSource.WIFI
                handler.post { evaluateAndApplyRules() }
            }
        }

        try {
            cm.registerDefaultNetworkCallback(networkCallback!!)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network callback", e)
        }
    }

    private fun updateCurrentSource(caps: NetworkCapabilities) {
        currentActiveSource = if (caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
            NetworkSource.WIFI
        } else if (caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)) {
            val netStr = usageMeasurementService.getCurrentActiveNetwork()
            when (netStr) {
                "SIM_2" -> NetworkSource.SIM_2
                else -> NetworkSource.SIM_1
            }
        } else {
            NetworkSource.WIFI
        }
    }

    private fun startPeriodicUsageEvaluation() {
        checkRunnable = object : Runnable {
            override fun run() {
                evaluateAndApplyRules()
                handler.postDelayed(this, 60_000) // Every 60 seconds
            }
        }
        handler.postDelayed(checkRunnable!!, 5_000)
    }

    /**
     * Inspects monitored apps' usage against rules on the active network source.
     * Fires threshold alerts (50%, 70%, 90%, 100%) and updates the list of blocked packages.
     */
    private fun evaluateAndApplyRules() {
        val rules = storage.getRules().filter { it.isMonitored && it.isScheduledToday() }
        val blockedNow = mutableSetOf<String>()
        val pm = packageManager

        for (rule in rules) {
            if (rule.limitMb == null) continue // Infinite quota

            val usageMap = usageMeasurementService.getTodayUsageForPackage(rule.packageName)
            val bytesUsed = when (rule.source) {
                NetworkSource.WIFI -> usageMap["wifiBytes"] as? Long ?: 0L
                NetworkSource.SIM_1 -> usageMap["sim1Bytes"] as? Long ?: 0L
                NetworkSource.SIM_2 -> usageMap["sim2Bytes"] as? Long ?: 0L
            }

            val limitBytes = rule.limitMb * 1024L * 1024L
            val percentage = if (limitBytes > 0) ((bytesUsed * 100) / limitBytes).toInt() else 0

            val appLabel = try {
                val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    pm.getApplicationInfo(rule.packageName, PackageManager.ApplicationInfoFlags.of(0L))
                } else {
                    @Suppress("DEPRECATION")
                    pm.getApplicationInfo(rule.packageName, 0)
                }
                pm.getApplicationLabel(info).toString()
            } catch (_: Exception) {
                rule.packageName
            }

            // Check notifications for enabled thresholds
            for (threshold in rule.notifyAt) {
                if (percentage >= threshold) {
                    val key = "${rule.packageName}_${rule.source.name}_${threshold}"
                    if (!storage.hasNotifiedThreshold(key)) {
                        storage.markThresholdNotified(key)
                        notificationManager.showThresholdNotification(
                            appLabel = appLabel,
                            source = rule.source,
                            threshold = threshold
                        )
                    }
                }
            }

            // If 100% reached and enforcement enabled, block if this rule corresponds to the CURRENT active source!
            if (percentage >= 100 && rule.isEnforced) {
                if (rule.source == currentActiveSource) {
                    blockedNow.add(rule.packageName)
                }
            }
        }

        val hasChanges = (blockedNow != currentlyBlockedPackages)
        currentlyBlockedPackages.clear()
        currentlyBlockedPackages.addAll(blockedNow)

        updateNotification()

        if (hasChanges) {
            rebuildVpnTunnel()
        }
    }

    /**
     * Establishes the VPN TUN interface.
     * Routes only the currently blocked applications into the blackhole interface.
     */
    @Synchronized
    private fun rebuildVpnTunnel() {
        stopPacketLoop()

        try {
            vpnInterface?.close()
        } catch (_: Exception) {
        }
        vpnInterface = null

        val builder = Builder()
            .setSession("Kayto Data Enforcer")
            .setMtu(1500)
            .addAddress("10.120.0.1", 32)
            .addRoute("0.0.0.0", 0)

        // Route only the applications that are currently blocked on the active network
        if (currentlyBlockedPackages.isNotEmpty()) {
            for (pkg in currentlyBlockedPackages) {
                try {
                    builder.addAllowedApplication(pkg)
                } catch (e: Exception) {
                    Log.w(TAG, "Cannot add allowed app: $pkg", e)
                }
            }
        } else {
            // Keep the tunnel active by routing our own package or dummy route
            try {
                builder.addAllowedApplication(packageName)
            } catch (_: Exception) {
            }
        }

        try {
            vpnInterface = builder.establish()
            if (vpnInterface != null) {
                startPacketLoop()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN tunnel", e)
        }
    }

    private fun startPacketLoop() {
        val pfd = vpnInterface ?: return
        isTunnelRunning.set(true)

        packetThread = Thread({
            val inputStream = FileInputStream(pfd.fileDescriptor)
            val buffer = ByteArray(32768)

            try {
                while (isTunnelRunning.get()) {
                    val length = inputStream.read(buffer)
                    if (length > 0) {
                        // Packet arrived from a blocked application
                        // Inspect IP packet header to record statistics
                        val version = (buffer[0].toInt() shr 4) and 0x0F
                        if (version == 4 || version == 6) {
                            storage.incrementBlockedStats(packets = 1, bytes = length.toLong())
                        }
                        // Drop packet (do not write to any outgoing socket)
                    } else if (length < 0) {
                        break
                    }
                }
            } catch (e: Exception) {
                if (isTunnelRunning.get()) {
                    Log.d(TAG, "Tunnel reader finished", e)
                }
            }
        }, "KaytoPacketReader")

        packetThread?.start()
    }

    private fun stopPacketLoop() {
        isTunnelRunning.set(false)
        try {
            packetThread?.interrupt()
            packetThread = null
        } catch (_: Exception) {
        }
    }

    private fun stopVpn() {
        storage.setVpnEnabled(false)
        isRunning.set(false)
        checkRunnable?.let { handler.removeCallbacks(it) }

        networkCallback?.let {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            try {
                cm.unregisterNetworkCallback(it)
            } catch (_: Exception) {
            }
        }

        stopPacketLoop()
        try {
            vpnInterface?.close()
            vpnInterface = null
        } catch (_: Exception) {
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onDestroy() {
        stopVpn()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = super.onBind(intent)
}
